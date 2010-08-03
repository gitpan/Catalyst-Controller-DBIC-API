package Catalyst::Controller::DBIC::API::StaticArguments;
BEGIN {
  $Catalyst::Controller::DBIC::API::StaticArguments::VERSION = '2.002002';
}

#ABSTRACT: Provides controller level configuration arguments
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


has 'offset_arg' => ( is => 'ro', isa => Str, default => 'list_offset' );


has 'select_arg' => ( is => 'ro', isa => Str, default => 'list_returns' );


has 'as_arg' => ( is => 'ro', isa => Str, default => 'as' );


has 'search_arg' => ( is => 'ro', isa => Str, default => 'search' );


has 'grouped_by_arg' => ( is => 'ro', isa => Str, default => 'list_grouped_by' );


has 'ordered_by_arg' => ( is => 'ro', isa => Str, default => 'list_ordered_by' );


has 'prefetch_arg' => ( is => 'ro', isa => Str, default => 'list_prefetch' );


has 'data_root' => ( is => 'ro', isa => Str, default => 'list');


has 'item_root' => ( is => 'ro', isa => Str, default => 'data');


has 'total_entries_arg' => ( is => 'ro', isa => Str, default => 'totalcount' );


has 'use_json_boolean' => ( is => 'ro', isa => Bool, default => 0 );


has 'return_object' => ( is => 'ro', isa => Bool, default => 0 );


1;

__END__
=pod

=head1 NAME

Catalyst::Controller::DBIC::API::StaticArguments - Provides controller level configuration arguments

=head1 VERSION

version 2.002002

=head1 DESCRIPTION

StaticArguments is a Role that is composed by the controller to provide configuration parameters such as how where in the request data to find specific elements, and if to use JSON boolean types.

=head1 PUBLIC_ATTRIBUTES

=head2 create_requires create_allows update_requires update_allows

These attributes control requirements and limits to columns when creating or updating objects.

Each provides a number of handles:

    "get_${var}_column" => 'get'
    "set_${var}_column" => 'set'
    "delete_${var}_column" => 'delete'
    "insert_${var}_column" => 'insert'
    "count_${var}_column" => 'count'
    "all_${var}_columns" => 'elements'

=head2 count_arg is: ro, isa: Str, default: 'list_count'

count_arg controls how to reference 'count' in the the request_data

=head2 page_arg is: ro, isa: Str, default: 'list_page'

page_arg controls how to reference 'page' in the the request_data

=head2 offset_arg is: ro, isa: Str, default: 'offset'

offset_arg controls how to reference 'offset' in the the request_data

=head2 select_arg is: ro, isa: Str, default: 'list_returns'

select_arg controls how to reference 'select' in the the request_data

=head2 as_arg is: ro, isa: Str, default: 'as'

as_arg controls how to reference 'as' in the the request_data

=head2 search_arg is: ro, isa: Str, default: 'search'

search_arg controls how to reference 'search' in the the request_data

=head2 grouped_by_arg is: ro, isa: Str, default: 'list_grouped_by'

grouped_by_arg controls how to reference 'grouped_by' in the the request_data

=head2 ordered_by_arg is: ro, isa: Str, default: 'list_ordered_by'

ordered_by_arg controls how to reference 'ordered_by' in the the request_data

=head2 prefetch_arg is: ro, isa: Str, default: 'list_prefetch'

prefetch_arg controls how to reference 'prefetch' in the the request_data

=head2 data_root is: ro, isa: Str, default: 'list'

data_root controls how to reference where the data is in the the request_data

=head2 item_root is: ro, isa: Str, default: 'data'

item_root controls how to reference where the data for single object
requests is in the the request_data

=head2 total_entries_arg is: ro, isa: Str, default: 'totalcount'

total_entries_arg controls how to reference 'total_entries' in the the request_data

=head2 use_json_boolean is: ro, isa: Bool, default: 0

use_json_boolean controls whether JSON::Any boolean types are used in the success parameter of the response or if raw strings are used

=head2 return_object is: ro, isa: Bool, default: 0

return_object controls whether the results of create/update are serialized and returned in the response

=head1 AUTHORS

=over 4

=item *

Nicholas Perez <nperez@cpan.org>

=item *

Luke Saunders <luke.saunders@gmail.com>

=item *

Alexander Hartmaier <abraxxa@cpan.org>

=item *

Florian Ragwitz <rafl@debian.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2010 by Luke Saunders, Nicholas Perez, Alexander Hartmaier, et al..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

