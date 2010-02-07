
use strict;
use warnings;



use ExtUtils::MakeMaker 6.11;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t t/rest/*.t t/rpc/*.t'
                                 },
                       'NAME' => 'Catalyst::Controller::DBIC::API',
                       'DISTNAME' => 'Catalyst-Controller-DBIC-API',
                       'AUTHOR' => 'Nicholas Perez <nperez@cpan.org>, Luke Saunders <luke.saunders@gmail.com>, Alexander Hartmaier <abraxxa@cpan.org>',
                       'ABSTRACT' => 'Provides a DBIx::Class web service automagically',
                       'EXE_FILES' => [],
                       'VERSION' => '2.001001',
                       'LICENSE' => 'perl',
                       'PREREQ_PM' => {
                                        'ExtUtils::MakeMaker' => '6.11',
                                        'CGI::Expand' => '2.02',
                                        'Test::More' => '0.88',
                                        'Catalyst::Model::DBIC::Schema' => '0.20',
                                        'Catalyst::Action::REST' => '0.60',
                                        'Test::WWW::Mechanize::Catalyst' => '0.37',
                                        'Catalyst::Runtime' => '5.7010',
                                        'Test::Deep' => '0.104',
                                        'DBIx::Class' => '0.08103',
                                        'Test::WWW::Mechanize' => '0.20',
                                        'JSON::Any' => '1.19',
                                        'Data::DPath::Validator' => '0.093411'
                                      }
                     );


delete $WriteMakefileArgs{LICENSE}
  unless eval { ExtUtils::MakeMaker->VERSION(6.31) };

WriteMakefile(%WriteMakefileArgs);



