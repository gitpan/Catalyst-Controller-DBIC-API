package RestTest::Controller::API::REST::CD;
our $VERSION = '2.001001';
use Moose;
BEGIN { extends 'Catalyst::Controller::DBIC::API::REST' }

use namespace::autoclean;

__PACKAGE__->config
    ( action => { setup => { PathPart => 'cd', Chained => '/api/rest/rest_base' } },
      class => 'RestTestDB::CD',
      create_requires => ['artist', 'title', 'year' ],
      update_allows => ['title', 'year'],
      prefetch_allows => [['artist', ['tracks'], { cd_to_producer => ['producer'], tags => 'cd' }]],
      );

1;
