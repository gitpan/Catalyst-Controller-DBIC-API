package RestTest::Controller::API;
our $VERSION = '2.001001';

use strict;
use warnings;
use base qw/Catalyst::Controller/;

sub api_base : Chained('/') PathPart('api') CaptureArgs(0) {
    my ( $self, $c ) = @_;

}

1;
