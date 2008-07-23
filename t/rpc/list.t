use 5.6.0;

use strict;
use warnings;

use lib 't/lib';

my $base = 'http://localhost';

use RestTest;
use DBICTest;
use URI;
use Test::More tests => 19;
use Test::WWW::Mechanize::Catalyst 'RestTest';
use HTTP::Request::Common;
use JSON::Syck;

my $mech = Test::WWW::Mechanize::Catalyst->new;
ok(my $schema = DBICTest->init_schema(), 'got schema');

my $artist_list_url = "$base/api/rpc/artist/list";
my $producer_list_url = "$base/api/rpc/producer/list";
my $track_list_url = "$base/api/rpc/track/list";

# test open request
{
  my $req = GET( $artist_list_url, {

  }, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'open attempt okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Artist')->all;
  my $response = JSON::Syck::Load( $mech->content);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct message returned' );
}

{
  my $uri = URI->new( $artist_list_url );
  $uri->query_form({ 'search.artistid' => 1 });
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'attempt with basic search okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Artist')->search({ artistid => 1 })->all;
  my $response = JSON::Syck::Load( $mech->content);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned' );
}

{
  my $uri = URI->new( $artist_list_url );
  $uri->query_form({ 'search.artistid' => 1 });
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'attempt with basic search okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Artist')->search({ artistid => 1 })->all;
  my $response = JSON::Syck::Load( $mech->content);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned' );
}

{
  my $uri = URI->new( $artist_list_url );
  $uri->query_form({ 'search.name.LIKE' => '%waul%' });
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'attempt with basic search okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Artist')->search({ name => { LIKE => '%waul%' }})->all;
  my $response = JSON::Syck::Load( $mech->content);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned for complex query' );
}

{
  my $uri = URI->new( $producer_list_url );
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'open producer request okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Producer')->search({}, { select => ['name'] })->all;
  my $response = JSON::Syck::Load( $mech->content);
#  use Data::Dumper; warn Dumper($response, \@expected_response);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned for class with list_returns specified' );
}


{
  my $uri = URI->new( $artist_list_url );
  $uri->query_form({ 'search.cds.title' => 'Forkful of bees' });	
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'search related request okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Artist')->search({ 'cds.title' => 'Forkful of bees' }, { join => 'cds' })->all;
  my $response = JSON::Syck::Load( $mech->content);
#  use Data::Dumper; warn Dumper($response, \@expected_response);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned for class with list_returns specified' );
}

{
  my $uri = URI->new( $track_list_url );
  $uri->query_form({ 'order_by' => 'position' });	
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'search related request okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Track')->search({}, { group_by => 'position', order_by => 'position ASC', select => 'position' })->all;
  my $response = JSON::Syck::Load( $mech->content);
#  use Data::Dumper; warn Dumper($response, \@expected_response);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned for class with everything specified in class' );
}

{
  my $uri = URI->new( $track_list_url );
  $uri->query_form({ 'list_ordered_by' => 'cd', 'list_returns' => 'cd', 'list_grouped_by' => 'cd' });
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'search related request okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Track')->search({}, { group_by => 'cd', order_by => 'cd ASC', select => 'cd' })->all;
  my $response = JSON::Syck::Load( $mech->content);
#  use Data::Dumper; warn Dumper($response, \@expected_response);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned when everything overridden in query' );
}

{
  my $uri = URI->new( $track_list_url );
  $uri->query_form({ 'list_ordered_by' => 'cd', 'list_count' => 1 });
  my $req = GET( $uri, 'Accept' => 'text/x-json' );
  $mech->request($req);
  cmp_ok( $mech->status, '==', 200, 'search related request okay' );

  my @expected_response = map { { $_->get_columns } } $schema->resultset('Track')->search({}, { group_by => 'position', order_by => 'position ASC', select => 'position', rows => 1 })->all;
  my $response = JSON::Syck::Load( $mech->content);
#  use Data::Dumper; warn Dumper($response, \@expected_response);
  is_deeply( { list => \@expected_response, success => 'true' }, $response, 'correct data returned when everything overridden in query' );
}
