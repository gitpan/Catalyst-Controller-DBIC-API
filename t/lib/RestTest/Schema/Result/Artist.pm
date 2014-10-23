package # hide from PAUSE 
    RestTest::Schema::Result::Artist;
our $VERSION = '2.001001';

use base 'DBIx::Class';

__PACKAGE__->load_components('Core');
__PACKAGE__->table('artist');
__PACKAGE__->add_columns(
  'artistid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'name' => {
    data_type => 'varchar',
    size      => 100,
    is_nullable => 1,
  },
);
__PACKAGE__->set_primary_key('artistid');

__PACKAGE__->has_many(
    cds => 'RestTest::Schema::Result::CD', undef,
    { order_by => 'year' },
);

1;
