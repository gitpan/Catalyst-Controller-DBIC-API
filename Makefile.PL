use inc::Module::Install 0.67;

name     'Catalyst-Controller-DBIC-API';
perl_version '5.006001';
all_from 'lib/Catalyst/Controller/DBIC/API.pm';

requires 'DBIx::Class' => 0.08;
requires 'Catalyst::Runtime' => 5.7010;
requires 'Catalyst::Action::REST' => 0.60;
requires 'CGI::Expand' => 2.02;

build_requires 'Test::More'       => 0.7;
build_requires 'Catalyst::Model::DBIC::Schema' => 0.20;
build_requires 'Test::WWW::Mechanize'       => 0.20;
build_requires 'Test::WWW::Mechanize::Catalyst'       => 0.37;

tests_recursive();

auto_provides;

auto_install;

WriteAll;
