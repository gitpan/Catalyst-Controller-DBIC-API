package RestTest::Controller::API::REST::Producer;
our $VERSION = '2.001003';
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::REST' }

use namespace::autoclean;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'producer', Chained => '/api/rest/rest_base' } },
      class => 'RestTestDB::Producer',
      create_requires => ['name'],
      update_allows => ['name'],
      select => ['name'],
      return_object => 1,
      );

1;
