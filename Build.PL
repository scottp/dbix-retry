use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'DBIx::Retry',
    license             => 'perl',
    dist_author         => 'Scott Penrose <scott@cpan.org>',
    dist_version_from   => 'lib/DBIx/Retry.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'DBIx-Retry-*' ],
);

$builder->create_build_script();
