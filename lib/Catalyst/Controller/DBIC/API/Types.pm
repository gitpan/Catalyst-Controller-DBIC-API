package Catalyst::Controller::DBIC::API::Types;
our $VERSION = '1.004002';

use warnings;
use strict;

use MooseX::Types -declare => [qw/OrderedBy GroupedBy Prefetch SelectColumns AsAliases/];
use MooseX::Types::Moose(':all');

subtype Prefetch, as Maybe[ArrayRef[Str|HashRef]];
coerce Prefetch, from Str, via { [$_] }, from HashRef, via { [$_] };

subtype GroupedBy, as Maybe[ArrayRef[Str]];
coerce GroupedBy, from Str, via { [$_] };

subtype OrderedBy, as Maybe[ArrayRef[Str|HashRef|ScalarRef]];
coerce OrderedBy, from Str, via { [$_] };

subtype SelectColumns, as Maybe[ArrayRef[Str|HashRef]];
coerce SelectColumns, from Str, via { [$_] };

subtype AsAliases, as Maybe[ArrayRef[Str]];

1;
