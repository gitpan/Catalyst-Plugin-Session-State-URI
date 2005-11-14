use strict;
use Module::Build;

my $build = Module::Build->new(
    create_makefile_pl => 'traditional',
    license            => 'perl',
    module_name        => 'Catalyst::Plugin::Session::State::URI',
    requires           => {
        'Catalyst::Plugin::Session' => '0.01',
        'URI::Escape'               => 0,

        # up till 0.13 then schemeless URIs could be found by plain URI::Find
        'URI::Find'        => '0.13',
        'Test::MockObject' => '1.01',
    },
    create_readme => 1,
    sign          => 1,
);
$build->create_build_script;

