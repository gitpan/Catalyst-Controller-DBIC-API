use inc::Module::Install 0.87;

name     'Catalyst-Controller-DBIC-API';
perl_version '5.006001';
all_from 'lib/Catalyst/Controller/DBIC/API.pm';

requires 'DBIx::Class' => 0.08103;
requires 'Catalyst::Runtime' => 5.7010;
requires 'Catalyst::Action::REST' => 0.60;
requires 'CGI::Expand' => 2.02;
requires 'JSON::Any' => 1.19;
requires 'Test::Deep' => 0.104;
requires 'Data::DPath::Validator' => 0.093411;
requires 'MooseX::Aliases' => 0.07;

build_requires 'Test::More'       => 0.88;
build_requires 'Catalyst::Model::DBIC::Schema' => 0.20;
build_requires 'Test::WWW::Mechanize'       => 0.20;
build_requires 'Test::WWW::Mechanize::Catalyst'       => 0.37;

tests_recursive();

auto_provides;

auto_install;

resources repository => 'http://dev.catalyst.perl.org/repos/Catalyst/Catalyst-Controller-DBIC-API/';

WriteAll;
