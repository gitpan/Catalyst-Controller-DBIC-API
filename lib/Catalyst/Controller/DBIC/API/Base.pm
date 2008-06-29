package # hide from PAUSE
    Catalyst::Controller::DBIC::API::Base;

use strict;
use warnings;
use base qw/Catalyst::Controller CGI::Expand/;

__PACKAGE__->mk_accessors(qw(
  class create_requires update_requires update_allows $self->rs_stash_key create_allows list_returns rs_stash_key object_stash_key
));

__PACKAGE__->config(
  class => undef,
  create_requires => [],
  create_allows => [],
  update_requires => [],
  update_allows => [],
  list_returns => [],
  object_stash_key => 'object',
  rs_stash_key => 'class_rs'
);

sub setup :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config') {
	my ($self, $c) = @_;

	$c->stash->{$self->rs_stash_key} = $c->model($self->class);
}

sub list :Private {
  my ($self, $c) = @_;

  my $req_params = (grep { ref $_ } values %{$c->req->params}) ? $c->req->params : $self->expand_hash($c->req->params);
  my $source = $c->stash->{$self->rs_stash_key}->result_source;
  my @columns = (scalar(@{$self->list_returns})) ? @{$self->list_returns} : $source->columns;

  my %search_params;
  
  my ($params, $join) = $self->_format_search({ params => $req_params->{search}, source => $source }) if ($req_params->{search});

#  use Data::Dumper; warn Dumper($params, $join);
  $c->stash->{$self->rs_stash_key} = $c->stash->{$self->rs_stash_key}->search($params, { join => $join, select => \@columns });

  $c->forward('format_list');
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

	unless (ref($self->create_requires) eq 'ARRAY') {
		die "create_requires must be an arrayref in config";
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

	unless (ref($self->update_allows) eq 'ARRAY') {
		die "update_allows must be an arrayref in config";
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
		return;
	}

	return $self->save_object($c, $object, $params);
}

sub validate {
	my ($self, $c, $object) = @_;
	my $params = $c->req->params;

	my %values;
	my %requires_map = map { $_ => 1 } @{($object->in_storage) ? [] : $self->create_requires};
	my %allows_map = map { (ref $_) ? %{$_} : ($_ => 1) } (keys %requires_map, @{($object->in_storage) ? $self->update_allows : $self->create_allows});
	
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
	if ($self->get_errors($c)) {
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
