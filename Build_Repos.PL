use 5.008;

use strict;
use warnings;

use CPAN::Meta;
use Cwd qw{ cwd };
use ExtUtils::MakeMaker;
use ExtUtils::Manifest qw{ maniread };
use File::Copy ();
use File::Find;
use File::Glob qw{ bsd_glob };
use File::Spec;
use Getopt::Long 2.33;
use IO::Compress::Gzip qw{ gzip $GzipError };
use IO::File;
use Pod::Usage;
use Time::Local;

our $VERSION = '0.000_194';

my $base_time = timegm( 0, 0, 0, 1, 0, 100 );

my %opt;

GetOptions( \%opt,
    qw{ force! verbose! },
    help => sub { pod2usage( { -verbose => 2 } ) },
) or pod2usage( { -verbose => 0 } );

if ( -d 'mock/repos' && ! $opt{force} ) {
    exit;
}

require CPAN::Checksums;

my $mail_re = qr{ [\w.-]+ \@ [\w.-]+ }smx;

my $top_dir = cwd();

my %author_index;
my %module_index;
my %mtime;

# Pack up the individual distributions, accumulating indexing
# information along the way.

foreach my $user ( bsd_glob( 'mock/src/repos/*' ) ) {

    my $cpan_id = ( File::Spec->splitpath( $user ) )[2];

    $opt{verbose}
	and print "User $cpan_id\n";

    my $dest_dir = _mkdir ( qw{ mock repos authors id },
	substr( $cpan_id, 0, 1 ), substr( $cpan_id, 0, 2 ),
	$cpan_id,
    );

    foreach my $dist ( bsd_glob( File::Spec->catfile( $user, '*' ) ) ) {

	my $dist_name = ( File::Spec->splitpath( $dist ) )[2];
	$opt{verbose}
	    and print "    $dist_name\n";

	foreach my $maker (
	    [ 'Makefile.PL' => 'make' ],
	    [ 'Build.PL' => './Build' ],
	) {
	    my ( $premake, $make ) = @{ $maker };
	    my $path = File::Spec->catfile( $dist, $premake );
	    -f $path
		or next;

	    chdir $dist
		or die "Can not change directory to $dist: $!";

	    my $manifest = maniread() || {};
	    foreach my $file ( keys %{ $manifest } ) {
		my @stat = stat $file
		    or next;
		$mtime{"$cpan_id/$dist_name/$file"} = $stat[9] -
		    $base_time;
	    }

	    my $kit_file;

	    eval {

		system perl => $premake;
		system $make, 'dist';

		my $meta;
		foreach my $meta_file ( qw{ MYMETA.json MYMETA.yml } ) {
		    -f $meta_file or next;
		    $meta = CPAN::Meta->load_file( $meta_file )
			and last;
		}

		my $kit_prefix = join '-', map { $meta->$_ } qw{ name version };
		$opt{verbose}
		    and print "    Glob $kit_prefix*\n";
		my @kit = bsd_glob( "$kit_prefix*" )
		    or die "No kit built for $dist";
		@kit > 1
		    and die "Multiple kits @kit for $dist";

		my $distribution = join '/',
		    substr( $cpan_id, 0, 1 ),
		    substr( $cpan_id, 0, 2 ),
		    $cpan_id,
		    $kit[0];

		$opt{verbose}
		    and print "    $kit[0]\n";

		my $provides = $meta->provides();
		%{ $provides } or $provides = _provides();
		while ( my ( $module, $data ) = each %{ $provides } ) {
		    $module_index{$module} ||= {
			distribution => $distribution,
			version	=> $data->{version},
		    };
		}

		my ( $author ) = $meta->author();
		if ( $author =~ s{ \s* [(] ( $mail_re ) [)] }{}smx
		    || $author =~ s{ \s* < ( $mail_re ) > }{}smx ) {
		    my $mail = $1;
		    if ( $mail =~ m{ \A ( [^\@]+ ) }smx ) {
			my $cpan_id = uc $1;
			$author_index{$cpan_id} ||= {
			    name	=> $author,
			    address	=> $mail,
			};
		    }
		}

		system $make, 'realclean';

		$kit_file = File::Spec->catfile( $dist, $kit[0] );

		1;
	    } or die "Build failed: $@";

	    chdir $top_dir
		or die "Can not change directory to $top_dir: $!";

	    File::Copy::move( $kit_file, $dest_dir )
		or die "Failed to move $kit_file to $dest_dir: $!";

	    last;
	}
    }

    CPAN::Checksums::updatedir( $dest_dir );

}

# Generate the mtimes file

{
    open my $fh, '>', 'mock/repos/mtimes.dat'
	or die "Unable to open mock/repos/mtimes.dat: $!\n";
    foreach my $file ( sort keys %mtime ) {
	print { $fh } "$file\t$mtime{$file}\n";
    }
    close $fh;
}

# Generate modules/02packages.details.txt and
# modules/02packages.details.txt.gz

{
    my $base = '02packages.details.txt';
    my $dest_dir = _mkdir( qw{ mock repos modules } );
    my $fn = File::Spec->catfile( $dest_dir, $base );
    my $fh = IO::File->new( $fn, '>' )
	or die "Failed to create $fn: $!";

    printf $fh "%-16s %s\n", 'File:' => $base;
    printf $fh "%-16s %s\n", 'Description:' =>
	'Package names found in directory $CPAN/authors/id/';
    printf $fh "%-16s %s\n", 'Columns:' =>
        'package name, version, path';

    print $fh "\n";

    foreach my $module ( sort keys %module_index ) {
	my $version = $module_index{$module}{version};
	defined $version
	    or $version = 'undef';
	printf $fh "%-32s %-8s %s\n", $module, $version,
	    $module_index{$module}{distribution};
    }
    $fh->close();

    gzip( $fn, "$fn.gz" )
	or die "Failed to compress $fn: $GzipError";
}

# generate authors/01mailrc.txt.gz

{
    my $base = '01mailrc.txt';
    my $dest_dir = _mkdir( qw{ mock repos authors } );

    my $fn = File::Spec->catfile( $dest_dir, $base );
    my $fh = IO::File->new( $fn, '>' )
	or die "Failed to create $fn: $!";

    foreach my $cpan_id ( sort keys %author_index ) {
	printf $fh qq{alias %-10s "%s <%s>"\n},
	    $cpan_id,
	    $author_index{$cpan_id}{name},
	    $author_index{$cpan_id}{address};
    }
    $fh->close();

    gzip( $fn, "$fn.gz" )
	or die "Failed to compress $fn: $GzipError";

    unlink $fn;
}

# Generate 03modlist.data.gz

{
    my $base = '03modlist.data';
    my $dest_dir = _mkdir( qw{ mock repos modules } );
    my $sf = File::Spec->catfile( qw{ mock src }, $base );
    my $df = File::Spec->catfile( $dest_dir, "$base.gz" );
    gzip( $sf, $df )
	or die "Failed to compress $sf: $GzipError";
}

sub _mkdir {
    my @args = @_;
    my $dest_dir = shift @args;
    -d $dest_dir
	or mkdir $dest_dir
	or die "Failed to make $dest_dir: $!\n";
    foreach ( @args ) {
	$dest_dir = File::Spec->catdir( $dest_dir, $_ );
	-d $dest_dir
	    or mkdir $dest_dir
	    or die "Failed to mkdir $dest_dir: $!";
    }
    return $dest_dir;
}

# ExtUtils::MakeMaker metadata does not supply the 'provides' key, so we
# need to be able to make it ourselves. For this, we require the modules
# to be in lib/.

sub _provides {
    my %provides;
    use ExtUtils::Manifest;
    my $manifest = maniread()
	or return {};
    while ( my ( $file, $comment ) = each %{ $manifest } ) {

	( my $module = $file ) =~ s{ [.] pm \z }{}smx
	    or next;
	$module =~ s{ \A lib/ }{}smx
	    or next;
	$module =~ s{ / }{::}smxg;

	my $version = MM->parse_version( $file );
	defined $version or $version = 'undef';

	$provides{$module} ||= {
	    file	=> $file,
	    version	=> $version,
	};
    }

    return \%provides;
}

__END__

=head1 TITLE

Build_Repos.PL - Build the CPAN::Access::AdHoc mock repository

=head1 SYNOPSIS

 Build_Repos.PL
 Build_Repos.PL -help
 Build_Repos.PL -version

=head1 OPTIONS

=head2 -help

This option displays the documentation for this script. The script then
exits.

=head2 -verbose

This option causes progress information to be written. Of course, if you
are building modules with C<ExtUtils::MakeMaker>, the information you
want may get lost in all of C<ExtUtils::MakeMaker>'s verbosity.

=head2 -version

This option displays the version of this script. The script then exits.

=head1 DETAILS

This Perl script builds the mock CPAN repository used to test
CPAN::Access::AdHoc. It expects the source to be in F<mock/src/repos/>, and it
places the output in F<mock/repos/>.

The F<mock/src/repos/> directory is expected to contain one directory
for each pseudo-CPAN ID. Under that directory are source directories for
packages by that author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
