package Catalyst::Controller::DBIC::API::StoredResultSource;
our $VERSION = '2.001002';
#ABSTRACT: Provides acessors for static resources

use Moose::Role;
use MooseX::Types::Moose(':all');
use Catalyst::Controller::DBIC::API::Types(':all');
use Try::Tiny;
use namespace::autoclean;

requires '_application';


has 'class' => ( is => 'ro', isa => Str, writer => '_set_class' );


has 'stored_result_source' =>
(
    is => 'ro',
    isa => ResultSource,
    lazy_build => 1,
);


has 'stored_model' =>
(
    is => 'ro',
    isa => Model,
    lazy_build => 1,
);

sub _build_stored_model
{   
    return $_[0]->_application->model($_[0]->class);
}

sub _build_stored_result_source
{
    return shift->stored_model->result_source();
}


sub check_has_column
{
    my ($self, $col) = @_;
    die "Column '$col' does not exist in ResultSet '${\$self->class}'"
        unless $self->stored_result_source->has_column($col);
}


sub check_has_relation
{
    my ($self, $rel, $other, $nest, $static) = @_;
    
    $nest ||= $self->stored_result_source;

    if(HashRef->check($other))
    {
        my $rel_src = $nest->related_source($rel);
        die "Relation '$rel_src' does not exist" if not defined($rel_src);

        while(my($k,$v) = each %$other)
        {
            $self->check_has_relation($k, $v, $rel_src, $static);
        }
    }
    else
    {
        return 1 if $static && ArrayRef->check($other) && $other->[0] eq '*';
        die "Relation '$rel' does not exist in ${\$nest->from}"
            unless $nest->has_relationship($rel) || $nest->has_column($rel);
        return 1;
    }
}


sub check_column_relation
{
    my ($self, $col_rel, $static) = @_;
    
    if(HashRef->check($col_rel))
    {
        try
        {
            while(my($k,$v) = each %$col_rel)
            {
                $self->check_has_relation($k, $v, undef, $static);
            }
        }
        catch
        {
            # not a relation but a column with a predicate
            while(my($k, undef) = each %$col_rel)
            {
                $self->check_has_column($k);
            }
        }
    }
    else
    {
        $self->check_has_column($col_rel);
    }
}

1;

__END__
=pod

=head1 NAME

Catalyst::Controller::DBIC::API::StoredResultSource - Provides acessors for static resources

=head1 VERSION

version 2.001002

=head1 PUBLIC_ATTRIBUTES

=head2 class is: ro, isa: Str

class is the name of the class that is the model for this controller

=head2 stored_result_source is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/ResultSource>

This is the result source for the controller

=head2 stored_model is: ro, isa: L<Catalyst::Controller::DBIC::API::Types/Model>

This is the model for the controller

=head1 PUBLIC_METHODS

=head2 check_has_column

Convenience method for checking if the column exists in the result source

=head2 check_has_relation

check_has_relation meticulously delves into the result sources relationships to determine if the provided relation is valid. Accepts a relation name, and optional HashRef indicating a nested relationship. Iterates, and recurses through provided arguments until exhausted. Dies if at any time the relationship or column does not exist.

=head2 check_column_relation

Convenience method to first check if the provided argument is a valid relation (if it is a HashRef) or column. 

=head1 AUTHORS

  Nicholas Perez <nperez@cpan.org>
  Luke Saunders <luke.saunders@gmail.com>
  Alexander Hartmaier <abraxxa@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Luke Saunders, Nicholas Perez, et al..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

