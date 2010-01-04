package Catalyst::Controller::DBIC::API::Request;
our $VERSION = '1.004001';
use Moose::Role;
use MooseX::Aliases;
use MooseX::Types::Moose('Object');
use namespace::autoclean;

### XXX Stupid hack to make role attribute handles work
sub check_has_relation { }
sub check_column_relation { }

has 'application' =>
(
    is => 'ro',
    writer => '_set_application',
    isa => Object,
    handles => 'Catalyst::Controller::DBIC::API::StoredResultSource',
);

with 'Catalyst::Controller::DBIC::API::RequestArguments';

1;
