# $File: //member/autrijus/Module-Install-RTx/lib/Module/Install/RTx.pm $ $Author: autrijus $
# $Revision: #10 $ $Change: 9652 $ $DateTime: 2004/01/10 13:48:42 $ vim: expandtab shiftwidth=4

package Module::Install::RTx;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$Module::Install::RTx::VERSION = '0.04';

use strict;
use FindBin;
use File::Basename;

sub RTx {
    my ($self, $name) = @_;

    $self->name("RTx-$name")
        unless $self->name;
    $self->abstract("RT $name Extension")
        unless $self->abstract;
    $self->version_from (-e "$name.pm" ? "$name.pm" : "lib/RTx/$name.pm")
        unless $self->version;

    my @prefixes = ($ENV{PREFIX}, qw(/opt /usr/local /home /usr /sw ));

    {
        local @INC = (
            @INC,
            $ENV{RTHOME},
            map {( "$_/rt3/lib", "$_/lib/rt3", "$_/lib" )} grep $_, @prefixes
        );
        until ( eval { require RT; $RT::LocalPath } ) {
            warn "Cannot find the location of RT.pm that defines \$RT::LocalPath.\n";
            $_ = prompt("Path to your RT.pm:") or exit;
            push @INC, $_, "$_/rt3/lib", "$_/lib/rt3";
        }
    }

    print "Using RT configurations from $INC{'RT.pm'}:\n";

    $RT::LocalVarPath	||= $RT::VarPath;
    $RT::LocalPoPath	||= $RT::LocalLexiconPath;
    $RT::LocalHtmlPath	||= $RT::MasonComponentRoot;

    my %path;
    my $with_subdirs = $ENV{WITH_SUBDIRS};
    @ARGV = grep { /WITH_SUBDIRS=(.*)/ ? (($with_subdirs = $1), 0) : 1 } @ARGV;
    my %subdirs = map { $_ => 1 } split(/\s*,\s*/, $with_subdirs);

    foreach (qw(bin etc html po sbin var)) {
        next unless -d "$FindBin::Bin/$_";
        next if %subdirs and !$subdirs{$_};
        $self->no_index( directory => $_ );

        no strict 'refs';
        my $varname = "RT::Local" . ucfirst($_) . "Path";
        $path{$_} = ${$varname} || "$RT::LocalPath/$_";
    }

    $path{$_} .= "/$name" for grep $path{$_}, qw(etc po var);
    print "./$_\t=> $path{$_}\n" for sort keys %path;
    my $args = join(', ', map "q($_)", %path);

    my $postamble = << ".";
install ::
\t\$(NOECHO) \$(PERL) -MExtUtils::Install -e \"install({$args})\"
.

    if ($path{var} and -d $RT::MasonDataDir) {
        my ($uid, $gid) = (stat($RT::MasonDataDir))[4, 5];
        $postamble .= << ".";
\t\$(NOECHO) chown -R $uid:$gid $path{var}
.
    }

    $self->postamble("$postamble\n");

    if (-e 'etc/initialdata') {
        print "For first-time installation, type 'make initialize-database'.\n";
        my $lib_path = dirname($INC{'RT.pm'});
        $self->postamble(<< ".");
initialize-database ::
\t\$(NOECHO) \$(PERL) -Ilib -I"$lib_path" "$RT::BasePath/sbin/rt-setup-database" --action=insert --datafile=etc/initialdata
.
    }
}

1;

__END__

=head1 NAME

Module::Install::RTx - RT extension installer

=head1 VERSION

This document describes version 0.04 of PAR, released January 10, 2004.

=head1 SYNOPSIS

In the F<Makefile.PL> of the C<RTx-Foo> module:

    use inc::Module::Install;

    RTx('Foo');
    author('Your Name <your@email.com>');
    license('perl');

    &WriteAll;

=head1 DESCRIPTION

This B<Module::Install> extension implements one function, C<RTx>,
that takes the extension name as the only argument.

It arranges for certain subdirectories to install into the installed
RT location, but does not affect the usual C<lib> and C<t> directories.

The directory mapping table is as below:

    ./bin   => $RT::LocalPath/bin
    ./etc   => $RT::LocalPath/etc/$NAME
    ./html  => $RT::MasonComponentRoot
    ./po    => $RT::LocalLexiconPath/$NAME
    ./sbin  => $RT::LocalPath/sbin
    ./var   => $RT::VarPath/$NAME

Under the default RT3 layout in F</opt> and with the extension name
C<Foo>, it becomes:

    ./bin   => /opt/rt3/local/bin
    ./etc   => /opt/rt3/local/etc/Foo
    ./html  => /opt/rt3/share/html
    ./po    => /opt/rt3/local/po/Foo
    ./sbin  => /opt/rt3/local/sbin
    ./var   => /opt/rt3/var/Foo

By default, all these subdirectories will be installed with C<make install>.
you can override this by setting the C<WITH_SUBDIRS> environment variable to
a comma-delimited subdirectory list, such as C<html,sbin>.

Alternatively, you can also specify the list as a command-line option to
C<Makefile.PL>, like this:

    perl Makefile.PL WITH_SUBDIRS=sbin

=head1 SEE ALSO

L<Module::Install>

L<http://www.bestpractical.com/rt/>

=head1 AUTHORS

Autrijus Tang <autrijus@autrijus.org>

=head1 COPYRIGHT

Copyright 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
