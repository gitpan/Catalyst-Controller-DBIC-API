package Catalyst::Controller::DBIC::API;

use strict;
use warnings;

=head1 VERSION

Version 1.000001

=cut

our $VERSION = '1.001000';

=head1 NAME

Catalyst::Controller::DBIC::API

=head1 SYNOPSIS

  package MyApp::Controller::API::RPC::Artist;
  use base qw/Catalyst::Controller::DBIC::API::RPC/;

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'artist', Chained => '/api/rpc/rpc_base' } }, # define parent chain action and partpath
      class => 'MyAppDB::Artist', # DBIC schema class
      create_requires => ['name', 'age'], # columns required to create
      create_allows => ['nickname'], # additional non-required columns that create allows
      update_allows => ['name', 'age', 'nickname'] # columns that update allows
      );

  # Provides the following functional endpoints:
  # /api/rpc/artist/create
  # /api/rpc/artist/list
  # /api/rpc/artist/id/[id]/delete
  # /api/rpc/artist/id/[id]/update

=head1 DESCRIPTION

Easily provide common API endpoints based on your L<DBIx::Class> schema classes. Module provides both RPC and REST interfaces to base functionality. Uses L<Catalyst::Action::Serialise> and L<Catalyst::Action::Deserialise> to serialise response and/or deserialise request.

=head1 GETTING STARTED

This document describes base functionlity such as list, create, delete, update and the setting of config attributes. L<Catalyst::Controller::DBIC::API::RPC> and L<Catalyst::Controller::DBIC::API::REST> describe details of provided endpoints to those base methods.

You will need to create a controller for each schema class you require API endpoints for. For example if your schema has Artist and Track, and you want to provide a RESTful interface to these, you should create MyApp::Controller::API::REST::Artist and MyApp::Controller::API::REST::Track which both subclass L<Catalyst::Controller::DBIC::API::REST>. Similarly if you wanted to provide an RPC style interface then subclass L<Catalyst::Controller::DBIC::API::RPC>. You then configure these individually as specified in L</CONFIGURATION>.

Also note that the test suite of this module has an example application used to run tests against. It maybe helpful to look at that until a better tutorial is written.

=head2 CONFIGURATION

Each of your controller classes needs to be configured to point at the relevant schema class, specify what can be updated and so on, as shown in the L</SYNOPSIS>.

The class, create_requires, create_allows and update_requires parameters can also be set in the stash like so:

  sub setup :Chained('/api/rpc/rpc_base') :CaptureArgs(1) :PathPart('any') {
    my ($self, $c, $object_type) = @_;

    if ($object_type eq 'artist') {
      $c->stash->{class} = 'MyAppDB::Artist';
      $c->stash->{create_requires} = [qw/name/];
      $c->stash->{update_allows} = [qw/name/];
    } else {
      $self->push_error($c, { message => "invalid object_type" });
      return;
    }

    $self->NEXT::setup($c);
  }

Generally it's better to have one controller for each DBIC source with the config hardcoded, but in some cases this isn't possible.

=head2 class

Whatever you would pass to $c->model to get a resultset for this class. MyAppDB::Track for example.

=head2 create_requires

Arrayref listing columns required to be passed to create in order for the request to be valid.

=head2 create_allows

Arrayref listing columns additional to those specified in create_requires that are not required to create but which create does allow. Columns passed to create that are not listed in create_allows or create_requires will be ignored.

=head2 update_allows

Arrayref listing columns that update will allow. Columns passed to update that are not listed here will be ignored.

=head2 list_returns

Arguments to pass to L<DBIx::Class::ResultSet/select> when performing search for L</list>.

=head2 list_grouped_by

Arguments to pass to L<DBIx::Class::ResultSet/group_by> when performing search for L</list>.

=head2 list_ordered_by

Arguments to pass to L<DBIx::Class::ResultSet/order_by> when performing search for L</list>.

=head2 list_count

Arguments to pass to L<DBIx::Class::ResultSet/rows> when performing search for L</list>.

=head2 object_stash_key

Object level methods such as delete and update stash the object in the stash. Specify the stash key you would like to use here. Defaults to 'object'.

=head2 rs_stash_key

List level methods such as list and create stash the class resultset in the stash. Specify the stash key you would like to use here. Defaults to 'class_rs'.

=head2 setup_list_method

If you need to process the incoming parameters (for validation, access control,
etc) you can configure an action to forward to.  This is called before the
search is handed off to DBIC, so you can process the incoming request
parameters, or add your own filters.  Below is an example of basic usage:

  __PACKAGE__->config(
      ...,
      setup_list_method => 'filter_search_params'
  );

  sub filter_search_params : Private {
      my ( $self, $c, $query ) = @_;
      $query->{search}->{'user_id'} = $c->user->id;
  }

=head1 METHODS

Note: see the individual interface classes - L<Catalyst::Controller::DBIC::API::RPC> and L<Catalyst::Controller::DBIC::API::REST> - for details of the endpoints to these abstract methods.

=head2 setup

This action is the chain root of the controller. It must either be overridden or configured to provide a base pathpart to the action and also a parent action. For example, for class MyAppDB::Track you might have

  package MyApp::Controller::API::RPC::Track;
  use base qw/Catalyst::Controller::DBIC::API::RPC/;

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rpc/rpc_base' } }, 
	...
  );

  # or

  sub setup :Chained('/api/rpc_base') :CaptureArgs(0) :PathPart('track') {
    my ($self, $c) = @_;

    $self->NEXT::setup($c);
  }

This action will populate $c->stash->{$self->rs_stash_key} with $c->model($self->class) for other actions in the chain to use.

=head2 object

This action is the chain root for all object level actions (such as delete and update). Takes one argument which is passed to L<DBIx::Class::ResultSet/find>, if an object is returned then it is set in $c->stash->{$self->object_stash_key}.

=head2 create

List level action chained from L</setup>. Checks $c->req->params for each column specified in the L</create_requires> and L</create_allows> parameters of the controller config. If all of the required columns are present then the object is created.

Does not populate the response with any additional information.

=head2 list

List level action chained from L</setup>. By default populates $c->stash->{response}->{list} with a list of hashrefs representing each object in the class resultset. If the L</list_returns> config param is defined then the hashes will contain only those columns, otherwise all columns in the object will be returned. Similarly L</list_count>, L</list_grouped_by> and L</list_ordered_by> affect the maximum number of rows returned as well as the ordering and grouping. Note that if list_returns, list_count, list_ordered_by or list_grouped_by request parameters are present then these will override the values set on the class.

If not all objects in the resultset are required then it's possible to pass conditions to the method as request parameters. L</CGI::Expand> is used to expand the request parameters into a structure and then $c->req->params->{search} is used as the search condition.

For example, these request parameters:

 ?search.name=fred&search.cd.artist=luke

Would result in this search (where 'name' is a column of the schema class, 'cd' is a relation of the schema class and 'artist' is a column of the related class):

 $rs->search({ name => 'fred', 'cd.artist' => 'luke' }, { join => ['cd'] })

The L</format_list> method is used to format the results, so override that as required.

=head2 format_list

Used by L</list> to populate response based on class resultset. By default populates $c->stash->{response}->{list} with a list of hashrefs representing each object in the resultset. Can be overidden to format the list as required.

=head2 update

Object level action chained from L</object>. Checks $c->req->params for each column specified in the L</update_allows> parameter of the controller config. If any of these columns are found in $c->req->params then the object set by L</object> is updated with those columns.

Does not populate the response with any additional information.

=head2 delete

Object level action chained from L</object>. Will simply delete the object set by L</object>.

Does not populate the response with any additional information.

=head2 end

If the request was successful then $c->stash->{response}->{success} is set to 1, if not then it is set to 0 and $c->stash->{response}->{messages} set to an arrayref containing all error messages.

Then the contents of $c->stash->{response} are serialized using L<Catalyst::Action::Serialize>.

=head1 EXTENDING

By default the create, delete and update actions will not return anything apart from the success parameter set in L</end>, often this is not ideal but the required behaviour varies from application to application. So normally it's sensible to write an intermediate class which your main controller classes subclass from. For example if you wanted create to return the JSON for the newly created object you might have something like:

  package MyApp::ControllerBase::DBIC::API::RPC;
  ...
  use base qw/Catalyst::Controller::DBIC::API::RPC/;
  ...
  sub create :Chained('setup') :Args(0) :PathPart('create') {
    my ($self, $c) = @_;

    # will set $c->stash->{created_object} if successful
    $self->NEXT::create($c);

    if ($c->stash->{created_object}) {    
      # $c->stash->{response} will be serialized in the end action
      %{$c->stash->{response}->{new_object}} = $c->stash->{created_object}->get_columns;
    }
  }


  package MyApp::Controller::API::RPC::Track;
  ...
  use base qw/MyApp::ControllerBase::DBIC::API::RPC/;
  ...

If you were using the RPC style. For REST the only difference besides the class names would be that create should be :Private rather than an endpoint.

Similarly you might want create, update and delete to all forward to the list action once they are done so you can refresh your view. This should also be simple enough.

=head1 AUTHOR

  Luke Saunders <luke.saunders@gmail.com>

=head1 CONTRIBUTORS

  J. Shirley <jshirley@gmail.com>

  Zbigniew Lukasiak <zzbbyy@gmail.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
