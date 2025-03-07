use strict;
use warnings;

package Debian::Upstream::Metadata::Perl;

our $VERSION = '0.128';

sub convert {
    my ($class, $meta, $filename) = @_;
    my %output;

    $output{"Archive"}           = 'CPAN';
    # $output{"Name"}            = $meta->{name};
    # $output{"Contact"}         = join( ', ', @{ $meta->{author} } );
    # $output{"Homepage"}        = $meta->{resources}->{homepage};
    $output{"Bug-Database"}      = $meta->{resources}->{bugtracker}->{web};
    $output{"Bug-Submit"}        = $meta->{resources}->{bugtracker}->{mailto};
    $output{"Repository"}        = $meta->{resources}->{repository}->{url};
    $output{"Repository-Browse"} = $meta->{resources}->{repository}->{web};

    # we don't care to write debian/upstream/metadata
    # if we don't have a Repository
    return unless defined $output{"Repository"};

    my $fix_browse = ! defined $output{"Repository-Browse"};

    my $url_parser = qr|(?:([^:/?\#]+):)? # protocol
                        (?://([^/?\#]*))? # domain name
                        ([^?\#]*)         # path
                        (?:\?([^\#]*))?   # query
                        (?:\#(.*))?       # fragment
                       |x;

    my ($protocol, $domain, $path, $query, $fragment)
        = $output{"Repository"} =~ $url_parser;

    # fixups:
    # strip user@, e.g. 'ssh://git@github.com/user/project.git'
    $domain =~ s|^[^@]+@||;
    # handle : after host, e.g.'git://git@github.com:user/project.git'
    if ( $domain =~ m/:/ ) {
        my ( $domainpart, $userpart ) = split /:/, $domain;
        $domain = $domainpart;
        $path   = '/' . $userpart . $path;
    }

    my $host = {
        'github.com'    => 'github',
        'gitlab.com'    => 'gitlab',
        'bitbucket.org' => 'bitbucket',
    }->{$domain};

    if (defined $host) {
        if ($protocol ne "https") {
            $output{"Repository"} = "https://$domain$path";
        }
        if ($fix_browse) {
            $path =~ s/\.git$//;
            $output{"Repository-Browse"} = "https://$domain$path";
        }
        # fix remaining non-HTTPS URLs
        foreach ( qw(
            Bug-Database
            Bug-Submit
            Repository
            Repository-Browse
        )) {
            $output{$_} =~ s|^http://|https://| if $output{$_};
        }
    }

    # GitHub fixups
    if (   defined $output{"Bug-Database"}
        && $output{"Bug-Database"} =~ /github\.com.+issues\/?$/
        && !$output{"Bug-Submit"} )
    {
        $output{"Bug-Database"} =~ s/\/$//;
        $output{"Bug-Submit"} = $output{"Bug-Database"} . '/new';
    }
    if (   defined $output{"Repository"}
        && $output{"Repository"} =~ /github\.com/
        && $output{"Repository"} !~ /\.git$/ )
    {
        $output{"Repository"} =~ s/\/$//;
        $output{"Repository"} .= '.git';
    }

    foreach (keys %output) {
        delete $output{$_} unless defined $output{$_};
    }

    require File::Spec;
    my ($vol, $dir, $file) = File::Spec->splitpath($filename);
    require File::Path;
    File::Path::make_path($dir);
    require YAML::XS;
    YAML::XS::DumpFile($filename, \%output);
}

1;

__END__
=head1 NAME

Debian::Upstream::Metadata::Perl -- debian/upstream/metadata for Perl modules

=head1 SYNOPSIS

 use Debian::Upstream::Metadata::Perl;

 Debian::Upstream::Metadata::Perl->convert(
    CPAN::Meta->new('META.yaml'),
    'debian/upstream/metadata');

=head1 DESCRIPTION

C<Debian::Upstream::Metadata::Perl> is a helper module which can be used to
convert the data in a L<CPAN::Meta> object to a F<debian/upstream/metadata> files,
according to the UpstreamMetadata specification.

Please, note that upstream links will be switched to https URLs.

=head1 METHODS

=over

=item convert (L<CPAN::Meta> object, filename)

Not exported function, cf. L<SYNOPSIS>.

=back

=head1 SEE ALSO

=over

=item *

L<CPAN::Meta::Spec>

=item *

L<UpstreamMetadata|https://wiki.debian.org/UpstreamMetadata>

=back

=head1 COPYRIGHT AND LICENSE

=over

=item Copyright 2013-2021, gregor herrmann L<gregoa@debian.org>

=item Copyright 2016, Alex Muntada L<alexm@alexm.org>

=item Copyright 2022, Damyan Ivanov L<dmn@debian.org>

=back

This program is free software and can be distributed under the same terms as
Perl.
