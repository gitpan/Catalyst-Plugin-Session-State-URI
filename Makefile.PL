use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'         => 'Catalyst::Plugin::Session::State::URI',
    'VERSION_FROM' => 'lib/Catalyst/Plugin/Session/State/URI.pm',
    'PREREQ_PM'    => {
        'Catalyst::Plugin::Session' => '0.06',
        'URI'                       => 0,
        'URI::QueryParam'           => 0,
        'URI::Find'                 => 0,
        'HTML::TokeParser::Simple'  => 0,
        'MIME::Types'               => 0,
        'Test::MockObject'          => '1.01',
    },
    'INSTALLDIRS' => 'site',
    'EXE_FILES'   => [],
    'PL_FILES'    => {},
    'SIGN'        => 1,
);
