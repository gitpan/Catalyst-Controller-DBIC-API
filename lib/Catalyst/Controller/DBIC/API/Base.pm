package													# hide from PAUSE
	Catalyst::Controller::DBIC::API::Base;

use strict;
use warnings;
use base qw/Catalyst::Controller CGI::Expand/;

use DBIx::Class::ResultClass::HashRefInflator;
use JSON::Any;
use Test::Deep::NoTest;

__PACKAGE__->mk_accessors(qw/
    class create_requires
    update_requires update_allows
    create_allows
    list_count list_returns list_prefetch list_prefetch_allows
    list_grouped_by list_search_exposes list_ordered_by
    rs_stash_key object_stash_key
    setup_list_method setup_dbic_args_method
/);

__PACKAGE__->config(
	class => undef,
	create_requires => [],
	create_allows => [],
	update_requires => [],
	update_allows => [],
	list_returns => [],
	list_prefetch => undef,
	list_prefetch_allows => [],
	list_grouped_by => [],
	list_search_exposes => [],
	list_ordered_by => [],
	list_count => undef,
	object_stash_key => 'object',
	rs_stash_key => 'class_rs'
);

sub setup :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config') {
	my ($self, $c) = @_;

	$c->stash->{$self->rs_stash_key} = $c->model($self->class);
}

# from Catalyst::Action::Serialize
sub deserialize :ActionClass('Deserialize') {
	my ($self, $c) = @_;

	my $req_params;
	if ($c->req->data) {
		$req_params = $c->req->data;
	} else {
		$req_params = $self->expand_hash($c->req->params);
		foreach my $param (qw/search list_count list_ordered_by list_grouped_by list_prefetch/) {
			# these params can also be composed of JSON
			eval {
				my $deserialized = JSON::Any->from_json($req_params->{$param});
				$req_params->{$param} = $deserialized;
			};
		}
	}
	$c->stash->{_dbic_api}->{req_params} = $req_params;
}

sub list :Private {
	my ($self, $c) = @_;

	return if $self->get_errors($c);
	my $ret = $c->forward('generate_dbic_search_args');
	return unless ($ret && ref $ret);
	my ($params, $args) = @{$ret};
	return if $self->get_errors($c);

	$c->stash->{$self->rs_stash_key} = $c->stash->{$self->rs_stash_key}->search($params, $args);
	$c->forward('format_list');
}

sub generate_dbic_search_args :Private {
	my ($self, $c) = @_;
  
	my $args = {};
	my $req_params = $c->stash->{_dbic_api}->{req_params};
	my $prefetch = $req_params->{list_prefetch} || $self->list_prefetch || undef;
	if ($prefetch) {
		$prefetch = [$prefetch] unless ref $prefetch;
		# validate the prefetch param against list_prefetch_allows
		foreach my $prefetch_allows (@{$self->list_prefetch_allows}) {
			if (eq_deeply($prefetch, $prefetch_allows)) {
				$args->{prefetch} = $prefetch;
				# stop looking for a valid prefetch param
				last;
			}
		}
		unless (exists $args->{prefetch}) {
			$self->push_error($c, { message => "prefetch validation failed" });
		}
	}

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

	if ($req_params->{search} && !ref $req_params->{search}) {
		$self->push_error($c, { message => "can not parse search arg" });
		return;
	}

	($params, $join) = $self->_format_search($c, { params => $req_params->{search}, source => $source }) if ($req_params->{search});

	$args->{group_by} = $req_params->{list_grouped_by} || ((scalar(@{$self->list_grouped_by})) ? $self->list_grouped_by : undef);
	$args->{order_by} = $req_params->{list_ordered_by} || ((scalar(@{$self->list_ordered_by})) ? $self->list_ordered_by : undef);
	$args->{rows} = $req_params->{list_count} || $self->list_count;
	$args->{page} = $req_params->{list_page};
	if ($args->{page}) {
		unless ($args->{page} =~ /^\d+$/xms) {
			$self->push_error($c, { message => "list_page must be numeric" });
		}
	}
	if ($args->{rows}) {
		unless ($args->{rows} =~ /^\d+$/xms) {
			$self->push_error($c, { message => "list_count must be numeric" });
		}
	}
	if ($args->{page} && !$args->{rows}) {
		$self->push_error($c, { message => "list_page can only be used with list_count" });
	}
	$args->{select} = $req_params->{list_returns} || ((scalar(@{$self->list_returns})) ? $self->list_returns : undef);
	if ($args->{select}) {
		# make sure all columns have an alias to avoid ambiguous issues
		$args->{select} = [map { ($_ =~ m/\./) ? $_ : "me.$_" } (ref $args->{select}) ? @{$args->{select}} : $args->{select}];
	}
	$args->{join} = $join;
	if ( my $action = $self->setup_dbic_args_method ) {
		my $format_action = $self->action_for($action);
		if ( defined $format_action ) {
			($params, $args) = @{$c->forward("/$format_action", [ $params, $args ])};
		} else {
			$c->log->error("setup_dbic_args_method was configured, but action $a not found");
		}
	}
	
	return [$params, $args];
}

sub _format_search {
	my ($self, $c, $p) = @_;
	my $params = $p->{params};
	my $source = $p->{source};
	my $base = $p->{base} || 'me';

	my $join = {};
	my %search_params;

	# munge list_search_exposes into format that's easy to do with
	my %valid = map { (ref $_) ? %{$_} : ($_ => 1) } @{$p->{_list_search_exposes} || $self->list_search_exposes};
	if ($valid{'*'}) {
		# if the wildcard is passed they can access any column or relationship
		$valid{$_} = 1 for $source->columns;
		$valid{$_} = ['*'] for $source->relationships;
	}
	# figure out the valid cols, defaulting to all cols if not specified
	my @valid_cols = @{$self->list_search_exposes} ? (grep { $valid{$_} eq 1 } keys %valid) : $source->columns;

	# figure out the valid rels, defaulting to all rels if not specified
	my @valid_rels = @{$self->list_search_exposes} ? (grep { ref $valid{$_} } keys %valid) : $source->relationships;

	my %_col_map = map { $_ => 1 } @valid_cols;
	my %_rel_map = map { $_ => 1 } @valid_rels;
	my %_source_col_map = map { $_ => 1 } $source->columns;

	# validate search params
	foreach my $key (keys %{$params}) {
		# if req args is a ref, assume it refers to a rel
		# XXX this is broken when attempting complex search 
		# XXX clauses on a col like { col => { LIKE => '%dfdsfs%' } }
		# XXX when rel and col have the same name
		next if $valid{'*'};
		if (ref $params->{$key} && $_rel_map{$key}) {
			$self->push_error($c, { message => "${key} is not a valid relation" }) unless (exists $_rel_map{$key});
		} else {			
			$self->push_error($c, { message => "${key} is not a valid column" }) unless exists $_col_map{$key};
		}
	}

	# build up condition on root source
	foreach my $column (@valid_cols) {
		next unless (exists $params->{$column});
		next if ($_rel_map{$column} && ref $params->{$column});

		if ($_source_col_map{$column}) {
			$search_params{join('.', $base, $column)} = $params->{$column};
		} else {
			$search_params{$column} = $params->{$column};
		}
	}

	# build up related conditions
	foreach my $rel (@valid_rels) {    
		next if ($search_params{join('.', $base, $rel)}); # if it's a condition on the base source, then it's can't also be a rel		
		next unless (exists $params->{$rel});
		next unless (ref $params->{$rel});
		my $rel_params;
		($rel_params, $join->{$rel}) = $self->_format_search($c, { params => $params->{$rel}, source => $source->related_source($rel), base => $rel, _list_search_exposes => $valid{$rel} });
		%search_params = ( %search_params, %{$rel_params} );
	}
	return (\%search_params, $join);
}

sub format_list :Private {
	my ($self, $c) = @_;

	# Create another result set here, so if someone looks at $self->rs_stash_key
	# it still is what they expect (and not inflating to a hash ref)
	my $rs = $c->stash->{$self->rs_stash_key}->search;
	$rs->result_class('DBIx::Class::ResultClass::HashRefInflator');
	$c->stash->{response}->{list} = [ $rs->all ];
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
	my $req_params = $c->stash->{_dbic_api}->{req_params};

	die "no object to update (looking at " . $self->object_stash_key . ")"
		unless ( defined $c->stash->{$self->object_stash_key} );

	unless (ref($c->stash->{update_allows} || $self->update_allows) eq 'ARRAY') {
		die "update_allows must be an arrayref in config or stash";
	}
	unless ($c->stash->{$self->rs_stash_key}) {
		die "class resultset not set";
	}

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
#	use Data::Dumper; warn Dumper($params);
	if ( $c->debug ) {
		$c->log->debug("Saving object: $object");
		$c->log->_dump( $params );
	}
	return $self->save_object($c, $object, $params);
}

sub validate {
	my ($self, $c, $object) = @_;
	my $params = $c->stash->{_dbic_api}->{req_params};

	my %values;
	my %requires_map = map { $_ => 1 } @{($object->in_storage) ? [] : $c->stash->{create_requires} || $self->create_requires};
	my %allows_map = map { (ref $_) ? %{$_} : ($_ => 1) } (keys %requires_map, @{($object->in_storage) ? ($c->stash->{update_allows} || $self->update_allows) : ($c->stash->{create_allows} || $self->create_allows)});
	
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
	} elsif ($self->get_errors($c)) {
		$c->stash->{response}->{messages} = $self->get_errors($c);
		$c->stash->{response}->{success} = 'false';
		$default_status = 400;
	} else {
		$c->stash->{response}->{success} = 'true';
		$default_status = 200;
	}
	
	delete $c->stash->{response}->{list} unless ($default_status == 200);
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
