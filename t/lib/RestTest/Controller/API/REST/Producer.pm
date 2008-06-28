package RestTest::Controller::API::REST::Producer;

use strict;
use warnings;
use base qw/Catalyst::Controller::DBIC::API::REST/;
use JSON::Syck;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'producer', Chained => '/api/rest/rest_base' } },
      class => 'RestTestDB::Producer',
      create_requires => ['name'],
      update_allows => ['name'],
      list_returns => ['name']
      );

1;
