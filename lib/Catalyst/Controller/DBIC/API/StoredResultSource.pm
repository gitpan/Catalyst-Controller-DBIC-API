package Catalyst::Controller::DBIC::API::StoredResultSource;
our $VERSION = '1.004000';
use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::Types::Moose(':all');
use Try::Tiny;
use namespace::autoclean;

requires '_application';

has 'class' => ( is => 'ro', isa => Str );

has 'stored_result_source' =>
(
    is => 'ro',
    isa => class_type('DBIx::Class::ResultSource'),
    lazy_build => 1,
);

has 'stored_model' =>
(
    is => 'ro',
    isa => class_type('DBIx::Class'),
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
    confess "Column '$col' does not exist in ResultSet '${\$self->class}'"
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
        return $self->check_has_relation(%$other, $rel_src, $static);
    }
    else
    {
        return 1 if $static && ArrayRef->check($other) && $other->[0] eq '*';
        die "Relation '$rel' does not exist in ${\ref($nest)}"
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
            $self->check_has_relation(%$col_rel, undef, $static);
        }
        catch
        {
            # not a relation but a column with a predicate
            $self->check_has_column(keys %$col_rel);
        }
    }
    else
    {
        $self->check_has_column($col_rel);
    }
}

1;
