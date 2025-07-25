#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Test::Differences;

BEGIN {
    use_ok('Debian::Control');
    use_ok('Debian::Control::Stanza::Source');
};

my $s;
lives_ok { $s = Debian::Control::Stanza::Source->new } 'Source constructs';
lives_ok { $s->Source('foo') } 'Source: set';

my $b;
lives_ok { $b = Debian::Control::Stanza::Binary->new } 'Binary constructs';
lives_ok { $b->Package('foo') } 'Package set';
lives_ok { $b->Depends('foo, bar (>= 5)') } 'Depends set';
isa_ok( $b->Depends, 'Debian::Dependencies', 'Depends is an object' );
ok( ( $b->Depends . '' ) eq 'foo, bar (>= 5)', 'Depends stringifies to the same' );
lives_ok { $b = Debian::Control::Stanza::Source->new( {
            'Build-Depends' => 'perl',
        } ) } 'Build-Depens is supported as a field in new()';
ok( $b->Build_Depends eq 'perl', 'and the value is in Build_Depends' );
lives_ok { $b = Debian::Control::Stanza::Source->new( {
            'build-depends' => 'perl8',
        } ) } 'bUiLd-DePeNdS is supported as a field in new()';
ok( $b->Build_Depends eq 'perl8', 'and the value is in Build_Depends' );

my $control = <<'EOF';
Source: libtest-compile-perl
Section: perl
Priority: optional
Maintainer: Debian Perl Group <pkg-perl-maintainers@lists.alioth.debian.org>
Uploaders: Damyan Ivanov <dmn@debian.org>,
 Gregor Herrmann <gregoa@debian.org>,
 Gunnar Wolf <gwolf@debian.org>
Build-Depends: debhelper (>= 7),
 libmodule-build-perl,
 libtest-simple-perl
Build-Depends-Indep: libtest-pod-coverage-perl,
 libtest-pod-perl,
 libuniversal-require-perl,
 perl
Standards-Version: 3.8.3
Vcs-Browser: http://svn.debian.org/viewsvn/pkg-perl/trunk/libtest-compile-perl/
Vcs-Svn: svn://svn.debian.org/pkg-perl/trunk/libtest-compile-perl/
Homepage: https://metacpan.org/release/Test-Compile

Package: libtest-compile-perl
Architecture: all
Depends: ${misc:Depends}, ${perl:Depends},
 libuniversal-require-perl
Multi-Arch: foreign
Description: check whether Perl module files compile correctly
 Test::Compile can be used in module test suites to verify that everything
 compiles correctly. This description is artifitially prolonged, in order to be
 able to use some commas and test whether they wrap.
 .
 This module provides a few useful functions for manipulating module names. Its
 main aim is to centralise some of the functions commonly used by modules that
 manipulate other modules in some way, like converting module names to relative
 paths.
 .
 This description was automagically extracted from the module by dh-make-perl.
EOF
my $c;

lives_ok { $c = Debian::Control->new } 'Debian::Control constructs';
lives_ok { $c->read(\$control) } 'parses a real control file';
isa_ok( $c->source->Build_Depends_Indep, 'Debian::Dependencies', 'parsed source B-D-I is a Debian::Dependencies object' );
ok( $c->source->Build_Depends_Indep eq 'libtest-pod-coverage-perl, libtest-pod-perl, libuniversal-require-perl, perl', 'parsed B-D-I as expected' );

my $written = "";
lives_ok { $c->write(\$written) } 'Control writes can write to a scalar ref';
eq_or_diff( $written, $control, 'Control writes what it have read' );

use_ok('Debian::Control::FromCPAN');
bless $c, 'Debian::Control::FromCPAN';
$c->binary->{'libtest-compile-perl'}->Depends->add('perl-modules');
$c->prune_perl_deps;
is( $c->binary->{'libtest-compile-perl'}->Depends . '',
    '${misc:Depends}, ${perl:Depends}, libuniversal-require-perl'
);

# test pruning dependency on perl version found in oldstable
$c->binary->{'libtest-compile-perl'}->Depends->add('perl (>= 5.8.8)');
$c->prune_perl_deps;
is( $c->binary->{'libtest-compile-perl'}->Depends . '',
    '${misc:Depends}, ${perl:Depends}, libuniversal-require-perl'
);

# same thing, with B-D
$c->source->Build_Depends_Indep->add('perl (>= 5.8.8)');
$c->prune_perl_deps;
is( $c->source->Build_Depends_Indep . '',
    'libtest-pod-coverage-perl, libtest-pod-perl, libuniversal-require-perl, perl'
);

# Test wrapping
$b = Debian::Control::Stanza::Binary->new(
    {
        Package => "foo",
        Depends => "libfoo-perl (>= 0.44839848), libbar-perl, libbaz-perl (>= 4.59454345345485), libtreshchotka-moo (>= 5.6), libmoo-more-java (>= 9.6544)",
    },
);
is( "$b", <<EOF );
Package: foo
Depends: libfoo-perl (>= 0.44839848),
 libbar-perl,
 libbaz-perl (>= 4.59454345345485),
 libtreshchotka-moo (>= 5.6),
 libmoo-more-java (>= 9.6544)
EOF

# canonical / case-insensitive field names/accessors
lives_ok { $s = Debian::Control::Stanza::Source->new({'Vcs_Git' => 'git://example.org'}) } 'Source constructor with Vcs_Git';
can_ok($s, qw(Vcs_Git));
ok($s->Vcs_Git eq 'git://example.org', 'Vcs_Git returns correct value');
throws_ok { $s->vCs_GiT } qr/Invalid field 'vCs_GiT' requested/, 'No vCs_GiT field';

lives_ok { $s = Debian::Control::Stanza::Source->new({'vCs-GiT' => 'git://example.net'}) } 'Source constructor with vCs-GiT';
can_ok($s, qw(Vcs_Git));
ok($s->Vcs_Git eq 'git://example.net', 'Vcs_Git returns correct value');
throws_ok { $s->vCs_GiT } qr/Invalid field 'vCs_GiT' requested/, 'No method vCs_GiT';

ok( $s->looks_like_an_x_field('XS_Moon_Phase'),
    "XS_Moon_Phase looks like an X_ field"
);

ok( $s->looks_like_an_x_field('X_Hemisphere'),
    "X_Hemisphere looks like an X_ field"
);

ok( $s->looks_like_an_x_field('XB_Temperature'),
    "XB_Temperature looks like an X_ field"
);

ok( $s->looks_like_an_x_field('XS_CoolValue'),
    "XS_CoolValue looks like an X_ field"
);

ok( $s->looks_like_an_x_field('XSB_SourceBinary'),
    "XSB_SourceBinary looks like an X_ field"
);

ok( $s->looks_like_an_x_field('XSBC_Original_Maintainer'), # Ubuntu; LP: #1886461
    "XSBC_Original_Maintainer looks like an X_ field"
);

ok( !$s->looks_like_an_x_field('XFail'),
    "XFail doesn't look like an X_ field"
);

lives_ok { $s->XS_Moon_Phase("full") } "Can set XS_Moon_Phase";
is( $s->XS_Moon_Phase, 'full', 'Moon is full' );

done_testing;
