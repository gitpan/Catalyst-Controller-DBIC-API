package Catalyst::Controller::DBIC::API::Request;
$Catalyst::Controller::DBIC::API::Request::VERSION = '2.002001';
$Catalyst::Controller::DBIC::API::Request::VERSION = '2.002001';

#ABSTRACT: Provides a role to be applied to the Request object
use Moose::Role;
use MooseX::Types::Moose(':all');
use namespace::autoclean;

#XXX HACK
sub _application {}
sub _controller {}


has '_application' =>
(
    is => 'ro',
    writer => '_set_application',
    isa => Object|ClassName,
);

has '_controller' =>
(
    is => 'ro',
    writer => '_set_controller',
    isa => Object,
    trigger => sub
    {
        my ($self, $new) = @_;

        $self->_set_class($new->class) if defined($new->class);
        $self->_set_application($new->_application);
        $self->_set_prefetch_allows($new->prefetch_allows);
        $self->_set_search_exposes($new->search_exposes);
        $self->_set_select_exposes($new->select_exposes);
    }
);

with 'Catalyst::Controller::DBIC::API::StoredResultSource';
with 'Catalyst::Controller::DBIC::API::RequestArguments';
with 'Catalyst::Controller::DBIC::API::Request::Context';


1;

__END__
=pod

=head1 NAME

Catalyst::Controller::DBIC::API::Request - Provides a role to be applied to the Request object

=head1 VERSION

version 2.002001

=head1 DESCRIPTION

Please see L<Catalyst::Controller::DBIC::API::RequestArguments> and L<Catalyst::Controller::DBIC::API::Request::Context> for the details of this class, as both of those roles are consumed in this role.

=head1 PRIVATE_ATTRIBUTES

=head2 _application is: ro, isa: Object, handles: Catalyst::Controller::DBIC::API::StoredResultSource

This attribute helps bridge between the request guts and the application guts; allows request argument validation against the schema. This is set during L<Catalyst::Controller::DBIC::API/inflate_request>

=head1 AUTHORS

  Nicholas Perez <nperez@cpan.org>
  Luke Saunders <luke.saunders@gmail.com>
  Alexander Hartmaier <abraxxa@cpan.org>
  Florian Ragwitz <rafl@debian.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Luke Saunders, Nicholas Perez, et al..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

