package Catalyst::Controller::DBIC::API;

use strict;
use warnings;

=head1 VERSION

Version 1.004

=cut

our $VERSION = '1.004002';

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
      update_allows => ['name', 'age', 'nickname'], # columns that update allows
      update_allows => ['name', 'age', 'nickname'], # columns that update allows
      select => [qw/name age/], # columns that data returns
      prefetch => ['cds'], # relationships that are prefetched when no prefetch param is passed
      prefetch_allows => [ # every possible prefetch param allowed
          'cds',
          qw/ cds /,
          { cds => 'tracks' },
          { cds => [qw/ tracks /] }
      ],
      ordered_by => [qw/age/], # order of generated list
      search_exposes => [qw/age nickname/, { cds => [qw/title year/] }], # columns that can be searched on via list
      data_root => 'data' # defaults to "list" for backwards compatibility
      use_json_boolean => 1, # use JSON::Any::true|false in the response instead of strings
      return_object => 1, # makes create and update actions return the object
      );

  # Provides the following functional endpoints:
  # /api/rpc/artist/create
  # /api/rpc/artist/list
  # /api/rpc/artist/id/[id]/delete
  # /api/rpc/artist/id/[id]/update

=head1 DESCRIPTION

Easily provide common API endpoints based on your L<DBIx::Class> schema classes. Module provides both RPC and REST interfaces to base functionality. Uses L<Catalyst::Action::Serialize> and L<Catalyst::Action::Deserialize> to serialise response and/or deserialise request.

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

    $self->next::method($c);
  }

Generally it's better to have one controller for each DBIC source with the config hardcoded, but in some cases this isn't possible.

Note that the Chained, CaptureArgs and PathPart are just standard Catalyst configuration parameters and that then endpoint specified in Chained - in this case '/api/rpc/rpc_base' - must actually exist elsewhere in your application. See L<Catalyst::DispatchType::Chained> for more details.

=head2 class

Whatever you would pass to $c->model to get a resultset for this class. MyAppDB::Track for example.

head2 data_root

By default, the response data is serialized into $c->stash->{response}->{$self->data_root} and data_root defaults to 'list' to preserve backwards compatibility. This is now configuable to meet the needs of the consuming client.

head2 use_json_boolean

By default, the response success status is set to a string value of "true" or "false". If this attribute is true, JSON::Any's true() and false() will be used instead. Note, this does not effect other internal processing of boolean values.

head2 count_arg, page_arg, select_arg, search_arg, grouped_by_arg, ordered_by_arg, prefetch_arg, as_arg

These attributes allow customization of the component to understand requests made by clients where these argument names are not flexible and cannot conform to this components defaults.

=head2 create_requires

Arrayref listing columns required to be passed to create in order for the request to be valid.

=head2 create_allows

Arrayref listing columns additional to those specified in create_requires that are not required to create but which create does allow. Columns passed to create that are not listed in create_allows or create_requires will be ignored.

=head2 update_allows

Arrayref listing columns that update will allow. Columns passed to update that are not listed here will be ignored.

=head2 select

Arguments to pass to L<DBIx::Class::ResultSet/select> when performing search for L</list>.

=head2 as

Complements arguments passed to L<DBIx::Class::ResultSet/select> when performing a search. This allows you to specify column names in the result for RDBMS functions, etc.

=head2 select_exposes

Columns and related columns that are okay to return in the resultset since clients can request more or less information specified than the above select argument.

=head2 prefetch

Arguments to pass to L<DBIx::Class::ResultSet/prefetch> when performing search for L</list>.

=head2 prefetch_allows

Arrayref listing relationships that are allowed to be prefetched.
This is necessary to avoid denial of service attacks in form of
queries which would return a large number of data
and unwanted disclosure of data.
Every element of the arrayref is one allowed parameter to prefetch.
So for three searches, all requiring different prefetch parameters,
three elements have to be passed to prefetch_allows in the controller.

=head2 grouped_by

Arguments to pass to L<DBIx::Class::ResultSet/group_by> when performing search for L</list>.

=head2 ordered_by

Arguments to pass to L<DBIx::Class::ResultSet/order_by> when performing search for L</list>.

=head2 search_exposes

Columns and related columns that are okay to search on. For example if only the position column and all cd columns were to be allowed

 search_exposes => [qw/position/, { cd => ['*'] }]

You can also use this to allow custom columns should you wish to allow them through in order to be caught by a custom resultset. For example:

  package RestTest::Controller::API::RPC::TrackExposed;
  
  ...
  
  __PACKAGE__->config
    ( ...,
      search_exposes => [qw/position title custom_column/],
    );

and then in your custom resultset:

  package RestTest::Schema::ResultSet::Track;
  
  use base 'RestTest::Schema::ResultSet';
  
  sub search {
    my $self = shift;
    my ($clause, $params) = @_;

    # test custom attrs
    if (my $pretend = delete $clause->{custom_column}) {
      $clause->{'cd.year'} = $pretend;
    }
    my $rs = $self->SUPER::search(@_);
  }

=head2 count

Arguments to pass to L<DBIx::Class::ResultSet/rows> when performing search for L</list>.

=head2 page

Arguments to pass to L<DBIx::Class::ResultSet/rows> when performing search for L</list>.

=head2 object_stash_key

Object level methods such as delete and update stash the object in the stash. Specify the stash key you would like to use here. Defaults to 'object'.

=head2 rs_stash_key

List level methods such as list and create stash the class resultset in the stash. Specify the stash key you would like to use here. Defaults to 'class_rs'.

=head2 setup_dbic_args_method

This hook will allow you to alter the parameters before they are passed to $rs->search. 
Here you can add additional attributes or alter the generated query. 

Note that the method is passed ($self, $c, $params, $attrs) and must return [$params, $attrs]. Below is an example of basic usage:

  __PACKAGE__->config(
      ...,
      setup_dbic_args_method => 'setup_dbic_args'
  );

  sub setup_dbic_args : Private {
	  my ($self, $c, $params, $args) = @_;

    # we only ever want to show items with position greater than 1
	  $params->{position} = { '!=' => '1' };
	  return [$params, $args];
  }

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

=head2 begin

A begin method is provided to apply the L<Catalyst::Controller::DBIC::API::Request> role to $c->request, and perform deserialization and validation of request parameters

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

    $self->next::method($c);
  }

This action will populate $c->stash->{$self->rs_stash_key} with $c->model($self->class) for other actions in the chain to use.

=head2 object

This action is the chain root for all object level actions (such as delete and update). Takes one argument which is passed to L<DBIx::Class::ResultSet/find>, if an object is returned then it is set in $c->stash->{$self->object_stash_key}.
The move of sub object in version 1.004002 from RPC/REST to Base will break your code if you subclass from REST and had relied on the 'object' action being an ActionClass('REST').

=head2 create

List level action chained from L</setup>. Checks $c->req->params for each column specified in the L</create_requires> and L</create_allows> parameters of the controller config. If all of the required columns are present then the object is created.

Does not populate the response with any additional information unless the return_object option is set to true, then the created object will be serialized within $c->stash->{response}->{$self->data_root}.

=head2 list

List level action chained from L</setup>. By default populates $c->stash->{response}->{$self->data_root} with a list of hashrefs representing each object in the class resultset. If the L</select> config param is defined then the hashes will contain only those columns, otherwise all columns in the object will be returned. L</select> of course supports the function/procedure calling semantics that L<DBIx::Class::ResultSet/select>. In order to have proper column names in the result, provide arguments in L</as> (which also follows L<DBIx::Class::ResultSet/as> semantics. Similarly L</count>, L</page>, L</grouped_by> and L</ordered_by> affect the maximum number of rows returned as well as the ordering and grouping. Note that if select, count, ordered_by or grouped_by request parameters are present then these will override the values set on the class with select becoming bound by the select_exposes attribute.

If not all objects in the resultset are required then it's possible to pass conditions to the method as request parameters. You can use a JSON string as the 'search' parameter for maximum flexibility or use L</CGI::Expand> syntax. In the second case the request parameters are expanded into a structure and then $c->req->params->{search} is used as the search condition.

For example, these request parameters:

 ?search.name=fred&search.cd.artist=luke
 OR
 ?search={"name":"fred","cd": {"artist":"luke"}}

Would result in this search (where 'name' is a column of the schema class, 'cd' is a relation of the schema class and 'artist' is a column of the related class):

 $rs->search({ name => 'fred', 'cd.artist' => 'luke' }, { join => ['cd'] })

Since version 1.004002 it is also possible to use a JSON string for expandeded parameters:

 ?search.datetime={"-between":["2010-01-06 19:28:00","2010-01-07 19:28:00"]}

Note that if pagination is needed, this can be achieved using a combination of the L</list_count> and L</list_page> parameters. For example:

  ?page=2&count=20

Would result in this search:
 
 $rs->search({}, { page => 2, rows => 20 })

The L</format_list> method is used to format the results, so override that as required.

=head2 format_list

Used by L</list> to populate response based on class resultset. By default populates $c->stash->{response}->{$self->data_root} with a list of hashrefs representing each object in the resultset. Can be overidden to format the list as required.

=head2 update

Object level action chained from L</object>. Checks $c->req->params for each column specified in the L</update_allows> parameter of the controller config. If any of these columns are found in $c->req->params then the object set by L</object> is updated with those columns.

Does not populate the response with any additional information uness the return_object option is set to true, then the updated object will be serialized within $c->stash->{response}->{$self->data_root}.

=head2 delete

Object level action chained from L</object>. Will simply delete the object set by L</object>.

Does not populate the response with any additional information.

=head2 end

$c->stash->{response}->{success} is set to 'true' or 'false' (or their respective JSON::Any values for true and false) regarding the success of the request. If the request failed, $c->stash->{response}->{messages} is set to an arrayref containing all error messages.

Then the contents of $c->stash->{response} are serialized using L<Catalyst::Action::Serialize>.

=head1 EXTENDING

By default the create, delete and update actions will not return anything apart from the success parameter set in L</end>, often this is not ideal but the required behaviour varies from application to application. So normally it's sensible to write an intermediate class which your main controller classes subclass from.

For example if you wanted create to return the JSON for the newly created object you might have something like:

  package MyApp::ControllerBase::DBIC::API::RPC;
  ...
  use Moose;
  BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC' };
  ...
  sub create :Chained('setup') :Args(0) :PathPart('create') {
    my ($self, $c) = @_;

    # will set $c->stash->{created_object} if successful
    $self->next::method($c);

    if ($c->stash->{created_object}) {    
      # $c->stash->{response} will be serialized in the end action
      %{$c->stash->{response}->{new_object}} = $c->stash->{created_object}->get_columns;
    }
  }


  package MyApp::Controller::API::RPC::Track;
  ...
  use Moose;
  BEGIN { extends 'MyApp::ControllerBase::DBIC::API::RPC' };
  ...

It should be noted that the L</return_object> attribute will produce the above result for you, free of charge.

For REST the only difference besides the class names would be that create should be :Private rather than an endpoint.

Similarly you might want create, update and delete to all forward to the list action once they are done so you can refresh your view. This should also be simple enough.

If more extensive customization is required, it is recommened to peer into the roles that comprise the system and make use 

=head1 NOTES

It should be noted that version 1.004 and above makes a rapid depature from the status quo. The internals were revamped to use more modern tools such as Moose and its role system to refactor functionality out into self-contained roles.

To this end, internally, this module now understands JSON boolean values (as represented by JSON::Any) and will Do The Right Thing in handling those values. This means you can have ColumnInflators installed that can covert between JSON::Any booleans and whatever your database wants for boolean values.

Validation for various *_allows or *_exposes is now accomplished via Data::DPath::Validator with a lightly simplified, via subclass, Data::DPath::Validator::Visitor. The rough jist of the process goes as follows: Arguments provided to those attributes are fed into the Validator and Data::DPaths are generated. Then, incoming requests are validated against these paths generated. The validator is set in "loose" mode meaning only one path is required to match. for more information, please see L<Data::DPath::Validator> and more specifically L<Catalyst::Controller::DBIC::API::Validator>.

All in all, significant efforts have been made to preserve backwards compatibility with previous versions. This means arguments to config and even internal structures (ie, the stash) should Just Work. This is accomplished by using L<MooseX::Aliases> to provide a mapping from old names to new names. Even the validator behavior /should/ be the same if not a bit more consistent. Internal validation of ->config arguments also happens much, much sooner. And, request parameters are validated as upfront as possible before ->search.

=head1 AUTHOR

  Luke Saunders <luke.saunders@gmail.com>

=head1 CONTRIBUTORS

  Nicholas Perez <nperez@cpan.org>

  J. Shirley <jshirley@gmail.com>

  Zbigniew Lukasiak <zzbbyy@gmail.com>

  Alexander Hartmaier <abraxxa@cpan.org>

=head1 SPECIAL THANKS

This module was inspired by code written by Matt S Trout (mst) when we worked on a project together. In subsequent projects
I found myself reproducing this design until eventually I decided to CPAN it. None of the original code remains, but the 
idea is basically the same.

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
