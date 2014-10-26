package Module::Install::RTx;

use 5.008;
use strict;
use warnings;
no warnings 'once';

use Module::Install::Base;
use base 'Module::Install::Base';
our $VERSION = '0.23';

use FindBin;
use File::Glob     ();
use File::Basename ();

sub RTx {
    my ( $self, $name ) = @_;

    my $original_name = $name;
    my $RTx = 'RTx';
    $RTx = $1 if $name =~ s/^(\w+)-//;
    my $fname = $name;
    $fname =~ s!-!/!g;

    $self->name("$RTx-$name")
        unless $self->name;
    $self->all_from( -e "$name.pm" ? "$name.pm" : "lib/$RTx/$fname.pm" )
        unless $self->version;
    $self->abstract("RT $name Extension")
        unless $self->abstract;

    my @prefixes = (qw(/opt /usr/local /home /usr /sw ));
    my $prefix   = $ENV{PREFIX};
    @ARGV = grep { /PREFIX=(.*)/ ? ( ( $prefix = $1 ), 0 ) : 1 } @ARGV;

    if ($prefix) {
        $RT::LocalPath = $prefix;
        $INC{'RT.pm'} = "$RT::LocalPath/lib/RT.pm";
    } else {
        local @INC = (
            @INC,
            $ENV{RTHOME} ? ( $ENV{RTHOME}, "$ENV{RTHOME}/lib" ) : (),
            map { ( "$_/rt3/lib", "$_/lib/rt3", "$_/lib" ) } grep $_,
            @prefixes
        );
        until ( eval { require RT; $RT::LocalPath } ) {
            warn
                "Cannot find the location of RT.pm that defines \$RT::LocalPath in: @INC\n";
            $_ = $self->prompt("Path to your RT.pm:") or exit;
            push @INC, $_, "$_/rt3/lib", "$_/lib/rt3", "$_/lib";
        }
    }

    my $lib_path = File::Basename::dirname( $INC{'RT.pm'} );
    my $local_lib_path = "$RT::LocalPath/lib";
    print "Using RT configuration from $INC{'RT.pm'}:\n";
    unshift @INC, "$RT::LocalPath/lib" if $RT::LocalPath;

    $RT::LocalVarPath  ||= $RT::VarPath;
    $RT::LocalPoPath   ||= $RT::LocalLexiconPath;
    $RT::LocalHtmlPath ||= $RT::MasonComponentRoot;

    my %path;
    my $with_subdirs = $ENV{WITH_SUBDIRS};
    @ARGV = grep { /WITH_SUBDIRS=(.*)/ ? ( ( $with_subdirs = $1 ), 0 ) : 1 }
        @ARGV;

    my %subdirs;
    %subdirs = map { $_ => 1 } split( /\s*,\s*/, $with_subdirs )
        if defined $with_subdirs;

    foreach (qw(bin etc html po sbin var)) {
        next unless -d "$FindBin::Bin/$_";
        next if keys %subdirs and !$subdirs{$_};
        $self->no_index( directory => $_ );

        no strict 'refs';
        my $varname = "RT::Local" . ucfirst($_) . "Path";
        $path{$_} = ${$varname} || "$RT::LocalPath/$_";
    }

    $path{$_} .= "/$name" for grep $path{$_}, qw(etc po var);
    $path{lib} = "$RT::LocalPath/lib" unless keys %subdirs and !$subdirs{'lib'};

    # If we're running on RT 3.8 with plugin support, we really wany
    # to install libs, mason templates and po files into plugin specific
    # directories
    if ($RT::LocalPluginPath) {
        foreach my $path (qw(lib po html etc bin sbin)) {
            next unless -d "$FindBin::Bin/$path";
            next if %subdirs and !$subdirs{$path};
            $path{$path} = $RT::LocalPluginPath . "/$original_name/$path";
        }
    }

    my $args = join( ', ', map "q($_)", %path );
    print "./$_\t=> $path{$_}\n" for sort keys %path;

    if ( my @dirs = map { ( -D => $_ ) } grep $path{$_}, qw(bin html sbin) ) {
        my @po = map { ( -o => $_ ) } grep -f,
            File::Glob::bsd_glob("po/*.po");
        $self->postamble(<< ".") if @po;
lexicons ::
\t\$(NOECHO) \$(PERL) -MLocale::Maketext::Extract::Run=xgettext -e \"xgettext(qw(@dirs @po))\"
.
    }

    my $postamble = << ".";
install ::
\t\$(NOECHO) \$(PERL) -MExtUtils::Install -e \"install({$args})\"
.

    if ( $path{var} and -d $RT::MasonDataDir ) {
        my ( $uid, $gid ) = ( stat($RT::MasonDataDir) )[ 4, 5 ];
        $postamble .= << ".";
\t\$(NOECHO) chown -R $uid:$gid $path{var}
.
    }

    my %has_etc;
    if ( File::Glob::bsd_glob("$FindBin::Bin/etc/schema.*") ) {

        # got schema, load factory module
        $has_etc{schema}++;
        $self->load('RTxFactory');
        $self->postamble(<< ".");
factory ::
\t\$(NOECHO) \$(PERL) -Ilib -I"$local_lib_path" -I"$lib_path" -Minc::Module::Install -e"RTxFactory(qw($RTx $name))"

dropdb ::
\t\$(NOECHO) \$(PERL) -Ilib -I"$local_lib_path" -I"$lib_path" -Minc::Module::Install -e"RTxFactory(qw($RTx $name drop))"

.
    }
    if ( File::Glob::bsd_glob("$FindBin::Bin/etc/acl.*") ) {
        $has_etc{acl}++;
    }
    if ( -e 'etc/initialdata' ) { $has_etc{initialdata}++; }

    $self->postamble("$postamble\n");
    if ( %subdirs and !$subdirs{'lib'} ) {
        $self->makemaker_args( PM => { "" => "" }, );
    } else {
        $self->makemaker_args( INSTALLSITELIB => "$RT::LocalPath/lib" );
    }

        $self->makemaker_args( INSTALLSITEMAN1DIR => "$RT::LocalPath/man/man1" );
        $self->makemaker_args( INSTALLSITEMAN3DIR => "$RT::LocalPath/man/man3" );
        $self->makemaker_args( INSTALLSITEARCH => "$RT::LocalPath/man" );
        $self->makemaker_args( INSTALLARCHLIB => "$RT::LocalPath/lib" );
    if (%has_etc) {
        $self->load('RTxInitDB');
        print "For first-time installation, type 'make initdb'.\n";
        my $initdb = '';
        $initdb .= <<"." if $has_etc{schema};
\t\$(NOECHO) \$(PERL) -Ilib -I"$local_lib_path" -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(schema))"
.
        $initdb .= <<"." if $has_etc{acl};
\t\$(NOECHO) \$(PERL) -Ilib -I"$local_lib_path" -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(acl))"
.
        $initdb .= <<"." if $has_etc{initialdata};
\t\$(NOECHO) \$(PERL) -Ilib -I"$local_lib_path" -I"$lib_path" -Minc::Module::Install -e"RTxInitDB(qw(insert))"
.
        $self->postamble("initdb ::\n$initdb\n");
        $self->postamble("initialize-database ::\n$initdb\n");
    }
}

sub RTxInit {
    unshift @INC, substr( delete( $INC{'RT.pm'} ), 0, -5 ) if $INC{'RT.pm'};
    require RT;
    RT::LoadConfig();
    RT::ConnectToDatabase();

    die "Cannot load RT" unless $RT::Handle and $RT::DatabaseType;
}

1;

__END__

=head1 NAME

Module::Install::RTx - RT extension installer

=head1 VERSION

This document describes version 0.21 of Module::Install::RTx, released
December 7, 2007.

=head1 SYNOPSIS

In the F<Makefile.PL> of the C<RTx-Foo> module:

    use inc::Module::Install;
    RTx 'Foo';
    WriteAll;

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

=head1 ENVIRONMENT

=over 4

=item RTHOME

Path to the RT installation that contains a valid F<lib/RT.pm>.

=back

=head1 SEE ALSO

L<Module::Install>

L<http://www.bestpractical.com/rt/>

=head1 AUTHORS

Audrey Tang <cpan@audreyt.org>

=head1 COPYRIGHT

Copyright 2003, 2004, 2007 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This software is released under the MIT license cited below.

=head2 The "MIT" License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

=cut
