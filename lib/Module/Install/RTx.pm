# $File: //member/autrijus/Module-Install-RTx/lib/Module/Install/RTx.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 9316 $ $DateTime: 2003/12/15 05:03:39 $ vim: expandtab shiftwidth=4

package Module::Install::RTx;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$Module::Install::RTx::VERSION = '0.01';

use strict;
use FindBin;

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
            map {( "$_/rt3/lib", "$_/lib/rt3" )} grep $_, @prefixes
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
    foreach (qw(bin etc html po sbin var)) {
        #next unless -d "$FindBin::Bin/$_";

        no strict 'refs';
        my $varname = "RT::Local" . ucfirst($_) . "Path";
        $path{$_} = ${$varname} || "$RT::LocalPath/$_";
    }

    $path{$_} .= "/$name" for grep $path{$_}, qw(etc po var);
    print "./$_\t=> $path{$_}\n" for sort keys %path;
    my $args = join(', ', map "q($_)", %path);

    $self->postamble(<< ".");
install ::
\t\$(NOECHO) \$(PERL) -I. -MExtUtils::Install -e \"install({$args})\"
.
}

1;

__END__

=head1 NAME

Module::Install::RTx - RT extension installer

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

The files will be installed with C<make install>.

=head1 SEE ALSO

L<Module::Install>

<http://www.bestpractical.com/rt/>

=head1 AUTHORS

Autrijus Tang <autrijus@autrijus.org>

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
