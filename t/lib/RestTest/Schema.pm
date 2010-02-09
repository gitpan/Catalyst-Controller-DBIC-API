package # hide from PAUSE
    RestTest::Schema;
our $VERSION = '2.001002';

use base qw/DBIx::Class::Schema/;

no warnings qw/qw/;

__PACKAGE__->load_namespaces;

1;
