package Catalyst::Controller::DBIC::API::RPC;
our $VERSION = '1.004002';
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::Base'; }

__PACKAGE__->config(
    'action'    => { object => { PathPart => 'id' } }, 
    'default'   => 'application/json',
    'stash_key' => 'response',
    'map'       => {
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    },
);

=head1 NAME

Catalyst::Controller::DBIC::API::RPC

=head1 DESCRIPTION

Provides an RPC API interface to the functionality described in L<Catalyst::Controller::DBIC::API>. 

By default provides the following endpoints:

  $base/create
  $base/list
  $base/id/[identifier]/delete
  $base/id/[identifier]/update

Where $base is the URI described by L</setup>, the chain root of the controller.

=head1 METHODS

=head2 setup

Chained: override
PathPart: override
CaptureArgs: 0

As described in L<Catalyst::Controller::DBIC::API/setup>, this action is the chain root of the controller but has no pathpart or chain parent defined by default, so these must be defined in order for the controller to function. The neatest way is normally to define these using the controller's config.

  __PACKAGE__->config
    ( action => { setup => { PathPart => 'track', Chained => '/api/rpc/rpc_base' } }, 
	...
  );

=head2 object

Chained: L</setup>
PathPart: object
CaptureArgs: 1

Provides an chain point to the functionality described in L<Catalyst::Controller::DBIC::API/object>. All object level endpoints should use this as their chain root.

=head2 create

Chained: L</setup>
PathPart: create
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/create>.

=head2 list

Chained: L</setup>
PathPart: list
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/list>.

=head2 delete

Chained: L</object>
PathPart: delete
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/delete>.

=head2 update

Chained: L</object>
PathPart: update
CaptureArgs: 0

Provides an endpoint to the functionality described in L<Catalyst::Controller::DBIC::API/update>.

=cut 

sub index : Chained('setup') PathPart('') Args(0) {
	my ( $self, $c ) = @_;

	$self->push_error($c, { message => 'Not implemented' });
	$c->res->status( '404' );
}

sub create :Chained('setup') :PathPart('create') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

sub list :Chained('setup') :PathPart('list') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

sub update :Chained('object') :PathPart('update') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

sub delete :Chained('object') :PathPart('delete') :Args(0) {
	my ($self, $c) = @_;

        $self->next::method($c);
}

=head1 AUTHOR

  Luke Saunders <luke.saunders@gmail.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
