package Catalyst::Controller::DBIC::API::REST;
our $VERSION = '1.004002';
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::Base'; }

__PACKAGE__->config(
    'default'   => 'application/json',
    'stash_key' => 'response',
    'map'       => {
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    });

=head1 NAME

Catalyst::Controller::DBIC::API::REST

=head1 DESCRIPTION

Provides a REST style API interface to the functionality described in L<Catalyst::Controller::DBIC::API>. 

By default provides the following endpoints:

  $base (accepts PUT and GET)
  $base/[identifier] (accepts POST and DELETE)

Where $base is the URI described by L</setup>, the chain root of the controller, and the request type will determine the L<Catalyst::Controller::DBIC::API> method to forward.

=head1 METHODS

=head2 setup

Chained: override
PathPart: override
CaptureArgs: 0

As described in L<Catalyst::Controller::DBIC::API/setup>, this action is the chain root of the controller but has no pathpart or chain parent defined by default, so these must be defined in order for the controller to function. The neatest way is normally to define these using the controller's config.

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rest/rest_base' } }, 
	...
  );

=head2 base

Chained: L</setup>
PathPart: none
CaptureArgs: 0

Forwards to list level methods described in L<Catalyst::Controller::DBIC::API> as follows:

POST: forwards to L<Catalyst::Controller::DBIC::API/create>
GET: forwards to L<Catalyst::Controller::DBIC::API/list>

=head2 object

Chained: L</setup>
PathPart: none
CaptureArgs: 1

Forwards to object level methods described in L<Catalyst::Controller::DBIC::API> as follows:

DELETE: forwards to L<Catalyst::Controller::DBIC::API/delete>
PUT: forwards to L<Catalyst::Controller::DBIC::API/update>

Note: It is often sensible although controversial to give this method a PathPart to clearly distinguish between object and list level methods. You can easily do this by using the controller config as with L</setup>. For example:

  __PACKAGE__->config
    ( action => { object => { PathPart => 'id', Chained => 'setup' } }, 
	...
  );

Would move your object level endpoints to $base/id/[identifier].

=cut 

sub rest :Chained('object') :Args(0) :PathPart('') :ActionClass('REST') {}

sub rest_POST {
	my ($self, $c) = @_;

	$c->forward('update');
}

sub rest_PUT {
	my ($self, $c) = @_;

	$c->forward('update');
}

sub rest_DELETE {
	my ($self, $c) = @_;

	$c->forward('delete');
}


sub base : Chained('setup') PathPart('') ActionClass('REST') Args(0) {
	my ( $self, $c ) = @_;

}

sub base_PUT {
	my ( $self, $c ) = @_;

	$c->forward('create');
}

sub base_POST {
	my ( $self, $c ) = @_;

	$c->forward('create');
}

sub base_GET {
	my ( $self, $c ) = @_;

	$c->forward('list');
}

=head1 AUTHOR

  Luke Saunders <luke.saunders@gmail.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
