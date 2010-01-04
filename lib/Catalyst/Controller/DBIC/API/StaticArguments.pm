package Catalyst::Controller::DBIC::API::StaticArguments;
our $VERSION = '1.004001';
use Moose::Role;
use MooseX::Types::Moose(':all');
use namespace::autoclean;

requires 'check_column_relation';

foreach my $var (qw/create_requires create_allows update_requires update_allows/)
{
    has $var =>
    (
        is => 'ro',
        isa => ArrayRef[Str|HashRef],
        traits => ['Array'],
        default => sub { [] },
        trigger => sub
        {   
            my ($self, $new) = @_;
            $self->check_column_relation($_, 1) for @$new;
        },
        handles =>
        {
            "get_${var}_column" => 'get',
            "set_${var}_column" => 'set',
            "delete_${var}_column" => 'delete',
            "insert_${var}_column" => 'insert',
            "count_${var}_column" => 'count',
            "all_${var}_columns" => 'elements',
        }
    );

    before "set_${var}_column" => sub { $_[0]->check_column_relation($_[2], 1) }; #"
    before "insert_${var}_column" => sub { $_[0]->check_column_relation($_[2], 1) }; #"
}

has 'count_arg' => ( is => 'ro', isa => Str, default => 'list_count' );
has 'page_arg' => ( is => 'ro', isa => Str, default => 'list_page' );
has 'select_arg' => ( is => 'ro', isa => Str, default => 'list_returns' );
has 'search_arg' => ( is => 'ro', isa => Str, default => 'search' );
has 'grouped_by_arg' => ( is => 'ro', isa => Str, default => 'list_grouped_by' );
has 'ordered_by_arg' => ( is => 'ro', isa => Str, default => 'list_ordered_by' );
has 'prefetch_arg' => ( is => 'ro', isa => Str, default => 'list_prefetch' );
has 'data_root' => ( is => 'ro', isa => Str, default => 'list');
has 'use_json_boolean' => ( is => 'ro', isa => Bool, default => 0 );
has 'return_object' => ( is => 'ro', isa => Bool, default => 0 );

1;
