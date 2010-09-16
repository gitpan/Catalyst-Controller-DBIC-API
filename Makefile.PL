
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
  'ABSTRACT' => 'Provides a DBIx::Class web service automagically',
  'AUTHOR' => 'Nicholas Perez <nperez@cpan.org>, Luke Saunders <luke.saunders@gmail.com>, Alexander Hartmaier <abraxxa@cpan.org>, Florian Ragwitz <rafl@debian.org>',
  'BUILD_REQUIRES' => {},
  'CONFIGURE_REQUIRES' => {
    'ExtUtils::MakeMaker' => '6.31'
  },
  'DISTNAME' => 'Catalyst-Controller-DBIC-API',
  'EXE_FILES' => [],
  'LICENSE' => 'perl',
  'NAME' => 'Catalyst::Controller::DBIC::API',
  'PREREQ_PM' => {
    'CGI::Expand' => '2.02',
    'Catalyst::Action::Serialize' => '0.83',
    'Catalyst::ActionRole::MatchRequestMethod' => '0',
    'Catalyst::Controller::ActionRole' => '0',
    'Catalyst::Model::DBIC::Schema' => '0.20',
    'Catalyst::Runtime' => '5.7010',
    'DBIx::Class' => '0.08103',
    'Data::DPath::Validator' => '0.093411',
    'JSON::Any' => '1.19',
    'MooseX::Types::Structured' => '0.20',
    'Test::Deep' => '0.104',
    'Test::More' => '0.88',
    'Test::WWW::Mechanize' => '0.20',
    'Test::WWW::Mechanize::Catalyst' => '0.37'
  },
  'VERSION' => '2.002003',
  'test' => {
    'TESTS' => 't/*.t t/rest/*.t t/rpc/*.t'
  }
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.56) } ) {
  my $br = delete $WriteMakefileArgs{BUILD_REQUIRES};
  my $pp = $WriteMakefileArgs{PREREQ_PM};
  for my $mod ( keys %$br ) {
    if ( exists $pp->{$mod} ) {
      $pp->{$mod} = $br->{$mod} if $br->{$mod} > $pp->{$mod};
    }
    else {
      $pp->{$mod} = $br->{$mod};
    }
  }
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



