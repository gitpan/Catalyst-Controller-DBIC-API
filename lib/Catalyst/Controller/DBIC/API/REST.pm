package Catalyst::Controller::DBIC::API::REST;
our $VERSION = '2.001003';

#ABSTRACT: Provides a REST interface to DBIx::Class
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API'; }

__PACKAGE__->config(
    'default'   => 'application/json',
    'stash_key' => 'response',
    'map'       => {
        'application/x-www-form-urlencoded' => 'JSON',
        'application/json'                  => 'JSON',
    });


sub base : Chained('setup') PathPart('') ActionClass('REST') Args {
	my ( $self, $c ) = @_;

}

sub base_PUT {
	my ( $self, $c ) = @_;
    
    $c->forward('object');
    return if $self->get_errors($c);
    $c->forward('update_or_create');
}

sub base_POST {
	my ( $self, $c ) = @_;

    $c->forward('object');
    return if $self->get_errors($c);
    $c->forward('update_or_create');
}

sub base_DELETE {
	my ( $self, $c ) = @_;
    $DB::single =1;
    $c->forward('object');
    return if $self->get_errors($c);
    $c->forward('delete');
}

sub base_GET {
	my ( $self, $c ) = @_;

	$c->forward('list');
}

1;

__END__
=pod

=head1 NAME

Catalyst::Controller::DBIC::API::REST - Provides a REST interface to DBIx::Class

=head1 VERSION

version 2.001003

=head1 DESCRIPTION

Provides a REST style API interface to the functionality described in L<Catalyst::Controller::DBIC::API>. 

By default provides the following endpoints:

  $base (accepts PUT and GET)
  $base/[identifier] (accepts POST and DELETE)

Where $base is the URI described by L</setup>, the chain root of the controller, and the request type will determine the L<Catalyst::Controller::DBIC::API> method to forward.

=head1 PROTECTED_METHODS

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

DELETE: forwards to L<Catalyst::Controller::DBIC::API/object> then L<Catalyst::Controller::DBIC::API/delete>
POST/PUT: forwards to L<Catalyst::Controller::DBIC::API/object> then L<Catalyst::Controller::DBIC::API/update_or_create>
GET: forwards to L<Catalyst::Controller::DBIC::API/list>

=head1 AUTHORS

  Nicholas Perez <nperez@cpan.org>
  Luke Saunders <luke.saunders@gmail.com>
  Alexander Hartmaier <abraxxa@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Luke Saunders, Nicholas Perez, et al..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

