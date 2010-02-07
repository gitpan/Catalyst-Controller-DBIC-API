package RestTest::Controller::API::RPC::CD;
our $VERSION = '2.001001';
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::RPC' }

use namespace::autoclean;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'cd', Chained => '/api/rpc/rpc_base' } },
      class => 'RestTestDB::CD',
      create_requires => ['artist', 'title', 'year' ],
      update_allows => ['title', 'year'],
      prefetch_allows => [[qw/ tracks /]],
      );

1;
