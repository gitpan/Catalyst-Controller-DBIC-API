package RestTest::Controller::API::RPC::Producer;

use strict;
use warnings;
use base qw/Catalyst::Controller::DBIC::API::RPC/;
use JSON::Syck;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'producer', Chained => '/api/rpc/rpc_base' } },
      class => 'RestTestDB::Producer',
      create_requires => ['name'],
      update_allows => ['name'],
      list_returns => ['name']
      );

1;
