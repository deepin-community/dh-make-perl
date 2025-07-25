#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

BEGIN {
    use_ok 'Debian::AptContents';
};

use FindBin qw($Bin);
use File::Touch qw(touch);

unlink("$Bin/Contents.cache");

sub instance
{
    Debian::AptContents->new({
        homedir => $Bin,
        verbose => 0,
        @_,
    });
}

$ENV{PATH} = "$Bin/bin:$ENV{PATH}";

eval { Debian::AptContents->new() };
ok( $@, 'AptContents->new with no cache_dir dies' );
like( $@, qr/No cache_dir given/, 'should say why it died' );

{
    my @c_files = glob('t/contents/*');
    my @slots = Debian::AptContents->_distribute_files( \@c_files,
        scalar(@c_files) + 2 );

    ok( scalar(@slots) == scalar(@c_files),
        "Distributing files on more CPUs results in no empty slots" )
        or diag @slots;
}

my $apt_contents = instance();

isnt( $apt_contents, undef, 'should create' );

$apt_contents = instance();

is_deeply(
    $apt_contents->contents_files,
    [ sort grep { !/Contents.cache/} glob "t/contents/*Contents*" ],
    'contents in a dir'
);

ok( -f "$Bin/Contents.cache", 'Contents.cache created' );

is( $apt_contents->source, 'cache', 'cache was used' );

sleep(1);   # allow the clock to tick so the timestamp actually differs
touch( glob "$Bin/contents/*Contents*" );

$apt_contents = instance();

is( $apt_contents->source, 'parsed files', 'cache updated' );

is_deeply(
    [ $apt_contents->find_file_packages('Moose.pm')],
    [ 'libmoose-perl' ],
    'Moose found by find_file_packages'
);

is( $apt_contents->find_perl_module_package('Moose') . '',
    'libmoose-perl', 'Moose found by module name' );

is_deeply(
    $apt_contents->get_contents_files,
    [   "t/contents/test_debian_dists_sid_main_Contents",
        "t/contents/test_debian_dists_testing_main_Contents"
    ],
    'get_contents_files'
);

is_deeply(
    [ $apt_contents->find_file_packages('GD.pm') ],
    [ 'libgd-gd2-noxpm-perl', 'libgd-gd2-perl' ],
    "GD.pm is in libdg-gd2[-noxpm]-perl"
);

is( $apt_contents->find_perl_module_package('GD') . '',
    'libgd-gd2-noxpm-perl | libgd-gd2-perl',
    'Alternative dependency for module found in multiple packages'
);

is_deeply(
    [ $apt_contents->find_file_packages('Image/Magick.pm') ],
    [ 'perlmagick', 'graphicsmagick-libmagick-dev-compat' ],
    "Image/Magick.pm in perlmagick and graphicsmagick-libmagick-dev-compat, but different paths"
);

is( $apt_contents->find_perl_module_package('Image::Magick') . '',
    'graphicsmagick-libmagick-dev-compat | perlmagick',
    'Alternative dependency for Image::Magick module found in multiple packages'
);

is( $apt_contents->find_perl_module_package('Test::More') . '',
    'libtest-simple-perl',
    'Test::More is in perl core and libtest-simple-perl but we only get the latter'
);

# should be in t/perl-deps.t but then we'd need the apt cache two times
use_ok('Debian::Control::FromCPAN');
my $ctl = 'Debian::Control::FromCPAN';
is( ( $ctl->find_debs_for_modules( { 'Test::More' => '0' }, $apt_contents ) )[0] . '',
    'libtest-simple-perl',
    'Test::More is in libtest-simple-perl'
);

ok( unlink "$Bin/Contents.cache", 'Contents.cache unlinked' );

done_testing;
