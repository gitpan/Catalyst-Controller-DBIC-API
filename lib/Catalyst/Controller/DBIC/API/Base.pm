package # hide from PAUSE
    Catalyst::Controller::DBIC::API::Base;

use strict;
use warnings;
use base qw/Catalyst::Controller CGI::Expand/;

__PACKAGE__->mk_accessors(qw(
  class create_requires update_requires update_allows $self->rs_stash_key create_allows list_count list_returns list_grouped_by list_ordered_by rs_stash_key object_stash_key setup_list_method
));

__PACKAGE__->config(
  class => undef,
  create_requires => [],
  create_allows => [],
  update_requires => [],
  update_allows => [],
  list_returns => [],
  list_grouped_by => [],
  list_ordered_by => [],
  list_count => undef,
  object_stash_key => 'object',
  rs_stash_key => 'class_rs'
);

sub setup :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config') {
	my ($self, $c) = @_;

	$c->stash->{$self->rs_stash_key} = $c->model($self->class);
}

sub list :Private {
  my ($self, $c) = @_;

  my ($params, $args) = @{$c->forward('generate_dbic_search_args')};

#  use Data::Dumper; warn Dumper($params, $args);
  $c->stash->{$self->rs_stash_key} = $c->stash->{$self->rs_stash_key}->search($params, $args);

  $c->forward('format_list');
}

sub generate_dbic_search_args :Private {
  my ($self, $c) = @_;

  my $req_params = (grep { ref $_ } values %{$c->req->params}) ? $c->req->params : $self->expand_hash($c->req->params);

  if ( my $a = $self->setup_list_method ) {
    my $setup_action = $self->action_for($a);
    if ( defined $setup_action ) {
      $c->forward("/$setup_action", [ $req_params ]);
    } else {
      $c->log->error("setup_list_method was configured, but action $a not found");
    }
  }

  my $source = $c->stash->{$self->rs_stash_key}->result_source;

  my ($params, $join);
  ($params, $join) = $self->_format_search({ params => $req_params->{search}, source => $source }) if ($req_params->{search});
  my $args = {};
  $args->{group_by} = $req_params->{list_grouped_by} || ((scalar(@{$self->list_grouped_by})) ? $self->list_grouped_by : undef);
  $args->{order_by} = $req_params->{list_ordered_by} || ((scalar(@{$self->list_ordered_by})) ? $self->list_ordered_by : undef);
  $args->{rows} = $req_params->{list_count} || $self->list_count;
  $args->{select} = $req_params->{list_returns} || ((scalar(@{$self->list_returns})) ? $self->list_returns : undef);
  $args->{join} = $join;

  return [$params, $args];
}

sub _format_search {
	my ($self, $p) = @_;
	my $params = $p->{params};
	my $source = $p->{source};
	my $base = $p->{base};

	my $join = {};
	my %search_params = map { ($base) ? join('.', $base, $_) : $_ => $params->{$_} } grep { exists $params->{$_} } $source->columns;
	foreach my $rel ($source->relationships) {
		if (exists $params->{$rel}) {
			my $rel_params;
			($rel_params, $join->{$rel}) = $self->_format_search({ params => $params->{$rel}, source => $source->related_source($rel), base => $rel });
			%search_params = ( %search_params, %{$rel_params} );
		}
	}

	return (\%search_params, $join);
}

sub format_list :Private {
  my ($self, $c) = @_;

  my @ret = map { { $_->get_columns } } $c->stash->{$self->rs_stash_key}->all;
  $c->stash->{response}->{list} = \@ret;
}

sub create :Private {
	my ($self, $c) = @_;

	unless (ref($c->stash->{create_requires} || $self->create_requires) eq 'ARRAY') {
		die "create_requires must be an arrayref in config or stash";
	}
	unless ($c->stash->{$self->rs_stash_key}) {
		die "class resultset not set";
	}

	my $empty_object = $c->stash->{$self->rs_stash_key}->new_result({});
	$c->stash->{created_object} = $self->validate_and_save_object($c, $empty_object);
}

sub update :Private {
	my ($self, $c) = @_;

	# expand params unless they have already been expanded
	my $req_params = (grep { ref $_ } values %{$c->req->params}) ? $c->req->params : $self->expand_hash($c->req->params);

	$c->req->params($req_params);
	return unless ($c->stash->{$self->object_stash_key});

	unless (ref($c->stash->{update_allows} || $self->update_allows) eq 'ARRAY') {
		die "update_allows must be an arrayref in config or stash";
	}
	unless ($c->stash->{$self->rs_stash_key}) {
		die "class resultset not set";
	}

#	use Data::Dumper; $c->log->debug(Dumper(\%create_args));
	my $object = $c->stash->{$self->object_stash_key};
	$self->validate_and_save_object($c, $object);
}

sub delete :Private {
	my ($self, $c) = @_;

	return unless ($c->stash->{$self->object_stash_key});
	return $c->stash->{$self->object_stash_key}->delete;
}

sub validate_and_save_object {
	my ($self, $c, $object) = @_;

	my $params;
	unless ($params = $self->validate($c, $object)) {
        $c->log->debug("No value from validate, cowardly bailing out")
            if $c->debug;
		return;
	}

    if ( $c->debug ) {
        $c->log->debug("Saving object: $object");
        $c->log->_dump( $params );
    }
	return $self->save_object($c, $object, $params);
}

sub validate {
	my ($self, $c, $object) = @_;
	my $params = $c->req->params;

	my %values;
	my %requires_map = map { $_ => 1 } @{($object->in_storage) ? [] : $c->stash->{create_requires} || $self->create_requires};
	my %allows_map = map { (ref $_) ? %{$_} : ($_ => 1) } (keys %requires_map, @{($object->in_storage) ? ($c->stash->{update_allows} || $self->update_allows) : ($c->stash->{create_allows} || $self->create_allows)});
	
#	use Data::Dumper; warn Dumper($params, \%requires_map, \%allows_map);
	foreach my $key (keys %allows_map) {
		# check value defined if key required
		my $allowed_fields = $allows_map{$key};
		if (ref $allowed_fields) {
			my $related_source = $object->result_source->related_source($key);
			unless ($related_source) {
				$self->push_error($c, { message => "${key} is not a valid relation" });
				next;
			}
		   
			my $related_params = $params->{$key};

			# it's an error for $c->req->params->{$key} to be defined but not be an array
			unless (ref $related_params) {
				unless (!defined $related_params) {
					$self->push_error($c, { message => "Value of ${key} must be a hash" });
				}
				next;
			}
			
			my %allowed_related_map = map { $_ => 1 } @{$allowed_fields};
			my $allowed_related_cols = ($allowed_related_map{'*'}) ? [$related_source->columns] : $allowed_fields;
			foreach my $related_col (@{$allowed_related_cols}) {
				if (my $related_col_value = $related_params->{$related_col}) {
					$values{$key}{$related_col} = $related_col_value;
				}
			}
		} else {
			my $value = $params->{$key};
			if ($requires_map{$key}) {
				unless (defined($value)) {
					# if not defined look for default
					$value = $object->result_source
						->column_info($key)
					->{default_value};
					unless (defined $value) {
						$self->push_error($c, { message => "No value supplied for ${key} and no default" });
					}
				}		   			
			}
			
			# TODO: do automatic col type checking here
			
			# check for multiple values
			if (ref($value)) {
				$self->push_error($c, { message => "Multiple values for '${key}'" });
			}

			# check exists so we don't just end up with hash of undefs
			# check defined to account for default values being used
			$values{$key} = $value if exists $params->{$key} || defined $value;
		}
	}

#	use Data::Dumper; $c->log->debug(Dumper(\%values));
	unless (keys %values || !$object->in_storage) {
		$self->push_error($c, { message => "No valid keys passed" });
	}

	return ($self->get_errors($c)) ? 0 : \%values;  
}

sub save_object {
	my ($self, $c, $object, $params) = @_;
	
	if ($object->in_storage) {
		foreach my $key (keys %{$params}) {
			if (ref $params->{$key}) {
				my $related_params = delete $params->{$key};
				my $row = $object->find_related($key, {} , {});
				$row->update($related_params);
			}
		}
		$object->update($params);
	} else {
		$object->set_columns($params);
		$object->insert;
	}
  return $object;
}

sub end :Private {
	my ($self, $c) = @_;

	# check for errors
	my $default_status;

    # Check for errors caught elsewhere
    if ( $c->res->status and $c->res->status != 200 ) {
		$default_status = $c->res->status;
		$c->stash->{response}->{success} = 'false';
    }
	elsif ($self->get_errors($c)) {
		$c->stash->{response}->{messages} = $self->get_errors($c);
		$c->stash->{response}->{success} = 'false';
		$default_status = 400;
	} else {
		$c->stash->{response}->{success} = 'true';
		$default_status = 200;
	}
	
	$c->res->status( $default_status || 200 );
	$c->forward('serialize');
}

# from Catalyst::Action::Serialize
sub serialize :ActionClass('Serialize') {
	my ($self, $c) = @_;

}

sub push_error {
	my ( $self, $c, $params ) = @_;

	push( @{$c->stash->{_dbic_crud_errors}}, $params->{message} || 'unknown error' );
}

sub get_errors {
  my ( $self, $c, $params ) = @_;

  return $c->stash->{_dbic_crud_errors};
}


=head1 AUTHOR

  Luke Saunders <luke.saunders@gmail.com>

=cut

1;
