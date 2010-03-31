
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t t/rest/*.t t/rpc/*.t'
                                 },
                       'NAME' => 'Catalyst::Controller::DBIC::API',
                       'DISTNAME' => 'Catalyst-Controller-DBIC-API',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.31'
                                               },
                       'AUTHOR' => 'Nicholas Perez <nperez@cpan.org>, Luke Saunders <luke.saunders@gmail.com>, Alexander Hartmaier <abraxxa@cpan.org>, Florian Ragwitz <rafl@debian.org>',
                       'BUILD_REQUIRES' => {},
                       'ABSTRACT' => 'Provides a DBIx::Class web service automagically',
                       'EXE_FILES' => [],
                       'VERSION' => '2.002001',
                       'PREREQ_PM' => {
                                        'MooseX::Types::Structured' => '0.20',
                                        'Catalyst::ActionRole::MatchRequestMethod' => '0',
                                        'CGI::Expand' => '2.02',
                                        'Catalyst::Model::DBIC::Schema' => '0.20',
                                        'Test::More' => '0.88',
                                        'Catalyst::Action::Serialize' => '0.83',
                                        'Catalyst::Controller::ActionRole' => '0',
                                        'Test::WWW::Mechanize::Catalyst' => '0.37',
                                        'Catalyst::Runtime' => '5.7010',
                                        'Test::Deep' => '0.104',
                                        'DBIx::Class' => '0.08103',
                                        'Data::DPath::Validator' => '0.093411',
                                        'Test::WWW::Mechanize' => '0.20',
                                        'JSON::Any' => '1.19'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{BUILD_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.56) };

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



