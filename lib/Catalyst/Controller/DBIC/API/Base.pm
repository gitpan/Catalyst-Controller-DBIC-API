package        # hide from PAUSE
    Catalyst::Controller::DBIC::API::Base;
our $VERSION = '1.004002';

use Moose;


BEGIN { extends 'Catalyst::Controller'; }
use CGI::Expand ();
use DBIx::Class::ResultClass::HashRefInflator;
use JSON::Any;
use Test::Deep::NoTest('eq_deeply');
use MooseX::Types::Moose(':all');
use MooseX::Aliases;
use Moose::Util;
use Try::Tiny;
use Catalyst::Controller::DBIC::API::Request;
use namespace::autoclean;

with 'Catalyst::Controller::DBIC::API::StoredResultSource';
with 'Catalyst::Controller::DBIC::API::StaticArguments';
with 'Catalyst::Controller::DBIC::API::RequestArguments' => { static => 1 };

has 'rs_stash_key' => ( is => 'ro', isa => Str, default => 'class_rs' );
has 'object_stash_key' => ( is => 'ro', isa => Str, default => 'object' );
has 'setup_list_method' => ( is => 'ro', isa => Str, predicate => 'has_setup_list_method');
has 'setup_dbic_args_method' => ( is => 'ro', isa => Str, predicate => 'has_setup_dbic_args_method');

__PACKAGE__->config();

sub begin :Private {
    my ($self, $c) = @_;
    
    Catalyst::Controller::DBIC::API::Request->meta->apply($c->req)
        unless Moose::Util::does_role($c->req, 'Catalyst::Controller::DBIC::API::Request');
    $c->forward('deserialize');
}

sub setup :Chained('specify.in.subclass.config') :CaptureArgs(0) :PathPart('specify.in.subclass.config') {
    my ($self, $c) = @_;

    $c->stash->{$self->rs_stash_key} = $self->stored_model;
}

sub object :Chained('setup') :CaptureArgs(1) :PathPart('') {
	my ($self, $c, $id) = @_;

	my $object = $c->stash->{$self->rs_stash_key}->find( $id );
	unless ($object) {
		$self->push_error($c, { message => "Invalid id" });
		$c->detach; # no point continuing
	}
	$c->stash->{$self->object_stash_key} = $object;
}

# from Catalyst::Action::Serialize
sub deserialize :ActionClass('Deserialize') {
    my ($self, $c) = @_;

    my $req_params;
    if ($c->req->data && scalar(keys %{$c->req->data})) {
        $req_params = $c->req->data;
    } else {
        $req_params = CGI::Expand->expand_hash($c->req->params);
        foreach my $param (@{[$self->search_arg, $self->count_arg, $self->page_arg, $self->ordered_by_arg, $self->grouped_by_arg, $self->prefetch_arg]}) {
            # these params can also be composed of JSON
            # but skip if the parameter is not provided
            next if not exists $req_params->{$param};
            # find out if CGI::Expand was involved
            if (ref $req_params->{$param} eq 'HASH') {
                for my $key ( keys %{$req_params->{$param}} ) {
                    try {
                        my $deserialized = JSON::Any->from_json($req_params->{$param}->{$key});
                        $req_params->{$param}->{$key} = $deserialized;
                    }
                    catch { 
                        $c->log->debug("Param '$param.$key' did not deserialize appropriately: $_")
                        if $c->debug;
                    }
                }
            }
            else {
                try {
                    my $deserialized = JSON::Any->from_json($req_params->{$param});
                    $req_params->{$param} = $deserialized;
                }
                catch { 
                    $c->log->debug("Param '$param' did not deserialize appropriately: $_")
                    if $c->debug;
                }
            }
        }
    }
    
    if(exists($req_params->{$self->data_root}))
    {
        my $val = delete $req_params->{$self->data_root};
        $req_params->{data} = $val;
    }
    else
    {
        $req_params->{data} = \%$req_params;
    }

    try
    {
        # set static arguments
        $c->req->_set_application($self); 
        $c->req->_set_prefetch_allows($self->prefetch_allows);
        $c->req->_set_search_exposes($self->search_exposes);
        $c->req->_set_select_exposes($self->select_exposes);
        $c->req->_set_request_data($req_params->{data});

        # set request arguments
        $c->req->_set_prefetch($req_params->{$self->prefetch_arg}) if exists $req_params->{$self->prefetch_arg};
        $c->req->_set_select($req_params->{$self->select_arg}) if exists $req_params->{$self->select_arg};
        $c->req->_set_as($req_params->{$self->as_arg}) if exists $req_params->{$self->as_arg};
        $c->req->_set_grouped_by($req_params->{$self->grouped_by_arg}) if exists $req_params->{$self->grouped_by_arg};
        $c->req->_set_ordered_by($req_params->{$self->ordered_by_arg}) if exists $req_params->{$self->ordered_by_arg};
        $c->req->_set_search($req_params->{$self->search_arg}) if exists $req_params->{$self->search_arg};
        $c->req->_set_count($req_params->{$self->count_arg}) if exists $req_params->{$self->count_arg};
        $c->req->_set_page($req_params->{$self->page_arg}) if exists $req_params->{$self->page_arg};
    }
    catch
    {
        $self->push_error($c, { message => $_ });
    }
}

sub list :Private {
    my ($self, $c) = @_;

    return if $self->get_errors($c);
    my $ret = $c->forward('generate_dbic_search_args');
    return unless ($ret && ref $ret);
    my ($params, $args) = @{$ret};
    return if $self->get_errors($c);
    
    $c->stash->{$self->rs_stash_key} = $c->stash->{$self->rs_stash_key}->search($params, $args);
    # add the total count of all rows in case of a paged resultset
    try 
    {
        $c->stash->{_dbic_api}->{totalcount} = $c->stash->{$self->rs_stash_key}->pager->total_entries
            if $args->{page};
        $c->forward('format_list');
    }
    catch
    {
        $c->log->error($_);
        # send a generic error to the client to not give out infos about
        # the database schema
        $self->push_error($c, { message => 'a database error has occured.' });
    }
}

sub generate_dbic_search_args :Private {
    my ($self, $c) = @_;
  
    my $args = {};
    my $req = $c->req;
    my $pre_format_params;

    if ( my $action_name = $self->setup_list_method ) {
        my $setup_action = $self->action_for($action_name);
        if ( defined $setup_action ) {
            $c->forward("/$setup_action", [ $req->request_data, $req ]);
            if(exists($req->request_data->{$self->search_arg}))
            {
                if(!$req->has_search)
                {
                    $req->_set_search($req->request_data->{$self->search_arg});
                }
                elsif(!eq_deeply($req->has_search, $req->request_data->{$self->search_arg}))
                {
                    $req->_set_search($req->request_data->{$self->search_arg});
                }
            }
        } else {
            $c->log->error("setup_list_method was configured, but action $action_name not found");
        }
    }
    my $source = $self->stored_result_source;

    my ($params, $join);

    ($params, $join) = $self->_format_search($c, { params => $req->search, source => $source }) if $req->has_search;
    
    $args->{prefetch} = $req->prefetch || $self->prefetch || undef;
    $args->{group_by} = $req->grouped_by || ((scalar(@{$self->grouped_by})) ? $self->grouped_by : undef);
    $args->{order_by} = $req->ordered_by || ((scalar(@{$self->ordered_by})) ? $self->ordered_by : undef);
    $args->{rows} = $req->count || $self->count;
    $args->{page} = $req->page;

    if ($args->{page} && !$args->{rows}) {
        $self->push_error($c, { message => "list_page can only be used with list_count" });
    }
    
    $args->{select} = $req->select || ((scalar(@{$self->select})) ? $self->select : undef);
    if ($args->{select}) {
        # make sure all columns have an alias to avoid ambiguous issues
        # but allow non strings (eg. hashrefs for db procs like 'count')
        # to pass through unmolested
        $args->{select} = [map { (Str->check($_) && $_ !~ m/\./) ? "me.$_" : $_ } (ref $args->{select}) ? @{$args->{select}} : $args->{select}];
    }

    $args->{as} = $req->as || ((scalar(@{$self->as})) ? $self->as : undef);
    $args->{join} = $join;
    if ( my $action_name = $self->setup_dbic_args_method ) {
        my $format_action = $self->action_for($action_name);
        if ( defined $format_action ) {
            ($params, $args) = @{$c->forward("/$format_action", [ $params, $args ])};
        } else {
            $c->log->error("setup_dbic_args_method was configured, but action $action_name not found");
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
    
    my $search_exposes = $self->search_exposes;
    # munge list_search_exposes into format that's easy to do with
    my %valid = map { (ref $_) ? %{$_} : ($_ => 1) } @{$p->{_list_search_exposes} || $search_exposes};
    if ($valid{'*'}) {
        # if the wildcard is passed they can access any column or relationship
        $valid{$_} = 1 for $source->columns;
        $valid{$_} = ['*'] for $source->relationships;
    }
    # figure out the valid cols, defaulting to all cols if not specified
    my @valid_cols = @$search_exposes ? (grep { $valid{$_} eq 1 } keys %valid) : $source->columns;

    # figure out the valid rels, defaulting to all rels if not specified
    my @valid_rels = @$search_exposes ? (grep { ref $valid{$_} } keys %valid) : $source->relationships;

    my %_col_map = map { $_ => 1 } @valid_cols;
    my %_rel_map = map { $_ => 1 } @valid_rels;
    my %_source_col_map = map { $_ => 1 } $source->columns;

    # build up condition on root source
    foreach my $column (@valid_cols) {
        next unless (exists $params->{$column});
        next if ($_rel_map{$column} && (ref $params->{$column} && !($params->{$column} == JSON::Any::true() || $params->{$column} == JSON::Any::false())));

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
    try
    {
        $c->stash->{response}->{$self->data_root} = [ $rs->all ];
        # only add the totalcount to the response if also data is returned
        if (my $totalcount = $c->stash->{_dbic_api}->{totalcount}) {
            # numify which is important for JSON
            $totalcount += 0;
            $c->stash->{response}->{totalcount} = $totalcount;
        }
    }
    catch
    {
        $c->log->error($_);
        # send a generic error to the client to not give out infos about
        # the database schema
        $self->push_error($c, { message => 'a database error has occured.' });
    }
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
    %{$c->stash->{response}->{$self->data_root}} = $c->stash->{created_object}->get_inflated_columns
        if defined($c->stash->{created_object}) && $self->return_object;
}

sub update :Private {
    my ($self, $c) = @_;

    die "no object to update (looking at " . $self->object_stash_key . ")"
        unless ( defined $c->stash->{$self->object_stash_key} );

    unless (ref($c->stash->{update_allows} || $self->update_allows) eq 'ARRAY') {
        die "update_allows must be an arrayref in config or stash";
    }
    unless ($c->stash->{$self->rs_stash_key}) {
        die "class resultset not set";
    }

    my $object = $c->stash->{$self->object_stash_key};
    $object = $self->validate_and_save_object($c, $object);
    %{$c->stash->{response}->{$self->data_root}} = $object->get_inflated_columns
        if defined($object) && $self->return_object;

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
    my $params = $c->req->request_data();

    my %values;
    my %requires_map = map { $_ => 1 } @{($object->in_storage) ? [] : $c->stash->{create_requires} || $self->create_requires};
    my %allows_map = map { (ref $_) ? %{$_} : ($_ => 1) } (keys %requires_map, @{($object->in_storage) ? ($c->stash->{update_allows} || $self->update_allows) : ($c->stash->{create_allows} || $self->create_allows)});

    foreach my $key (keys %allows_map) {
        # check value defined if key required
        my $allowed_fields = $allows_map{$key};
        if (ref $allowed_fields) {
            my $related_source = $object->result_source->related_source($key);
            my $related_params = $params->{$key};
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
            if (ref($value) && !($value == JSON::Any::true || $value == JSON::Any::false)) {
                require Data::Dumper;
                $self->push_error($c, { message => "Multiple values for '${key}': ${\Data::Dumper::Dumper($value)}" });
            }

            # check exists so we don't just end up with hash of undefs
            # check defined to account for default values being used
            $values{$key} = $value if exists $params->{$key} || defined $value;
        }
    }

    #    use Data::Dumper; $c->log->debug(Dumper(\%values));
    unless (keys %values || !$object->in_storage) {
        $self->push_error($c, { message => "No valid keys passed" });
    }

    return ($self->get_errors($c)) ? 0 : \%values;  
}

sub save_object {
    my ($self, $c, $object, $params) = @_;

    try
    {
        if ($object->in_storage) {
            foreach my $key (keys %{$params}) {
                my $value = $params->{$key};
                if (ref($value) && !($value == JSON::Any::true || $value == JSON::Any::false)) {
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
    }
    catch
    {
        $c->log->error($@);
        # send a generic error to the client to not give out infos about
        # the database schema
        $self->push_error($c, { message => 'a database error has occured.' });
    };
    
    return $object;
}

sub end :Private {
    my ($self, $c) = @_;

    # check for errors
    my $default_status;

    # Check for errors caught elsewhere
    if ( $c->res->status and $c->res->status != 200 ) {
        $default_status = $c->res->status;
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::false : 'false';
    } elsif ($self->get_errors($c)) {
        $c->stash->{response}->{messages} = $self->get_errors($c);
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::false : 'false';
        $default_status = 400;
    } else {
        $c->stash->{response}->{success} = $self->use_json_boolean ? JSON::Any::true : 'true';
        $default_status = 200;
    }
    
    delete $c->stash->{response}->{$self->data_root} unless ($default_status == 200);
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

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
