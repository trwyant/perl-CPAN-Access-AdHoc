package main;

use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use File::chdir;
use File::Spec;
use POSIX ();
use Test::More 0.88;	# Because of done_testing();
use Time::Local;
use URI::file;

my $no_temp_dir;

BEGIN {
    eval {
	require File::Temp;
	File::Temp->can( 'new' ) && File::Temp->can( 'newdir' );
    } or do {
	$no_temp_dir =
	'File::Temp unavailable, or does not support new() or newdir()';
    };
}

use lib qw{ mock };

use CPAN::Access::AdHoc;

my %archive_member_mtime;
eval {
    my $base_time = timegm( 0, 0, 0, 1, 0, 100 );
    open my $fh, '<', 'mock/repos/mtimes.dat'
	or die "Failed to open mock/repos/mtimes.dat: $!";
    while ( <$fh> ) {
	my ( $file, $time ) = split qr{ \s+ }smx;
	$archive_member_mtime{$file} = $time + $base_time;
    }
    close $fh;
    1;
} or diag $@;

my $cad = CPAN::Access::AdHoc->new();

# Test access to module index

{

    my $file_name = '02packages.details.txt';

    my $text = slurp( "mock/repos/modules/$file_name" );

    # First the raw index

    my $arc = $cad->fetch( "modules/$file_name" );
    ok $arc, "Fetch the archive for modules/$file_name";

    SKIP: {
	my $mtime = $cad->__test__file_mtime( "modules/$file_name" );
	defined $mtime
	    or skip "Can not get mtime for modules/$file_name", 1;
	cmp_ok $arc->mtime, '==', $mtime,
	    "Modification time of modules/$file_name";
    }

    is $arc->base_directory(), 'modules/',
	'Base directory of null archive.';

    is_deeply [ $arc->list_contents() ], [ $file_name ],
	"The archive contents are $file_name";

    ok $arc->item_present( $file_name ),
	"The $file_name file is in the archive";

    is $arc->get_item_content(),
	$text,
	"Check the contents of $file_name";

    # Yes, this is the correct modification time, since the null archive
    # was made up from the raw file. If it comes from the compressed
    # file it may be another story.
    my $want = ( stat "mock/repos/modules/$file_name" )[9];
    my $got = $arc->get_item_mtime();
    ok abs( $got - $want ) < 2,
	"Check the modification time of $file_name"
	or mtime_diag( $got, $want );

    SKIP: {
	my $tests = 1;

	$no_temp_dir
	    and skip $no_temp_dir, $tests;

	my $td = File::Temp->newdir()
	    or skip "Unable to create temp dir: $!", $tests;

	local $CWD = $td;

	if ( eval { $arc->extract(); 1; } ) {
	    is slurp( File::Spec->catfile( $arc->base_directory(),
		    $file_name ) ), $text,
	    'Correct extraction from archive';
	} else {
	    fail "Unable to extract null archive: $@";
	}

    }

    # Next the compressed index

    is $cad->fetch( "modules/$file_name.gz" )->get_item_content(),
	$text,
	"Check the contents of $file_name.gz";
}

my ( $module_index, $meta ) = $cad->fetch_module_index();

is_deeply $module_index, {
    Johann	=> {
	distribution	=> 'B/BA/BACH/Johann-0.001.tar.bz2',
	version		=> 0.001,
    },
    PDQ		=> {
	distribution	=> 'B/BA/BACH/PDQ-0.000_01.zip',
	version		=> '0.000_01',
    },
    Yehudi => {
	distribution	=> 'M/ME/MENUHIN/Yehudi-0.001.tar.gz',
	version		=> 0.001,
    },
}, 'Contents of the repository index';

is_deeply $meta, {
    Columns	=> 'package name, version, path',
    Description	=> 'Package names found in directory $CPAN/authors/id/',
    File	=> '02packages.details.txt',
}, 'Contents of the repository metadata';

# Test access to author index

my $author_index = $cad->fetch_author_index();

is_deeply $author_index, {
    BACH	=> {
	name	=> 'J. S. Bach',
	address	=> 'bach@cpan.org',
    },
    MENUHIN	=> {
	name	=> 'Y. Menuhin',
	address	=> 'menuhin@cpan.org',
    },
}, 'Contents of the author index';

# Test access to registered module index

{
    my ( $registered_module_index, $meta ) =
	$cad->fetch_registered_module_index();

    my $desc = <<'EOD';
These are the data that are published in the module
list, but they may be more recent than the latest posted
modulelist. Over time we'll make sure that these data
can be used to print the whole part two of the
modulelist. Currently this is not the case.
EOD
    $desc =~ s/ \s+ / /smxg;
    $desc =~ s/ \s+ \z //smx;

    is_deeply $meta, {
	File	=> '03modlist.data',
	Description => $desc,
	Modcount	=> 2,
	'Written-By'	=> 'Tom Wyant',
	Date =>		'Mon, 26 Dec 2011 17:10:00 GMT',
    }, 'Metadata for 03modlist.data';

    is_deeply $registered_module_index, {
	Johann	=> {
	    modid	=> 'Johann',
	    statd	=> 'R',
	    stats	=> 'd',
	    statl	=> 'p',
	    stati	=> 'O',
	    statp	=> 'p',
	    description	=> 'Represents Johann Sebastian Bach',
	    userid	=> 'BACH',
	    chapterid	=> '023',
	},
	Yehudi	=> {
	    modid	=> 'Yehudi',
	    statd	=> 'R',
	    stats	=> 'd',
	    statl	=> 'p',
	    stati	=> 'O',
	    statp	=> 'p',
	    description	=> 'Represents Yehudi Menuhin',
	    userid	=> 'MENUHIN',
	    chapterid	=> '023',
	},
    }, 'Data for 03modlist.data';

}

# Test access to CHECKSUMS.

{
    my $cksum = do 'mock/repos/authors/id/B/BA/BACH/CHECKSUMS';

    is_deeply $cad->fetch_distribution_checksums( 'BACH/' ),
        $cksum, 'BACH/CHECKSUMS';

    is_deeply $cad->fetch_distribution_checksums(
	    'BACH/Johann-0.001.tar.bz2' ),
	$cksum->{ 'Johann-0.001.tar.bz2' },
	'BACH/Johann-0.001.tar.bz2 checksums';

    ok ! defined scalar $cad->fetch_distribution_checksums(
	    'BACH/Carl-Philipp-Emanuel-0.001.tar.gz' ),
	'BACH/Carl-Philipp-Emanuel-0.001.tar.gz has no checksum';
}

# Test other thingies

is_deeply [ $cad->corpus( 'BACH' ) ], [ qw{
    B/BA/BACH/Johann-0.001.tar.bz2
    B/BA/BACH/PDQ-0.000_01.zip
    } ], q{Corpus of CPAN ID 'BACH'};

is_deeply [ $cad->indexed_distributions() ], [ qw{
    B/BA/BACH/Johann-0.001.tar.bz2
    B/BA/BACH/PDQ-0.000_01.zip
    M/ME/MENUHIN/Yehudi-0.001.tar.gz
    } ], 'All indexed distributions';

# Test access to .tar.gz archive

SKIP: {
    my $tests = 11;

    my $pkg = $module_index->{Yehudi}{distribution}
	or skip q{Module 'Yehudi' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    is $kit->path(), 'authors/id/M/ME/MENUHIN/Yehudi-0.001.tar.gz',
	'Path to Yehudi-0.001.tar.gz';

    SKIP: {
	my $mtime = $cad->__test__file_mtime( $pkg );
	defined $mtime
	    or skip "Can not get mtime for $pkg", 1;
	cmp_ok $kit->mtime, '==', $mtime,
	    "Modification time of $pkg";
    }

    is $kit->base_directory(), 'Yehudi-0.001/',
	'Base directory of Yehudi-0.001.tar.gz';

    is_deeply [ sort $kit->list_contents() ], [ sort qw{
	    lib/Yehudi.pm
	    Makefile.PL
	    MANIFEST
	    META.json
	    META.yml
	    t/basic.t
	} ],
	'Contents of Yehudi-0.001.tar.gz';

    is $kit->get_item_content( 'Makefile.PL' ),
	slurp( 'mock/src/repos/MENUHIN/Yehudi/Makefile.PL' ),
	"Can extract Makefile.PL from $pkg";

    {
	my $got = $kit->get_item_mtime( 'Makefile.PL' );
	my $want = $archive_member_mtime{ 'MENUHIN/Yehudi/Makefile.PL' };
	ok abs( $got - $want ) < 2,
	"Can get Makefile.PL mod time from $pkg"
	    or mtime_diag( $got, $want );
    }

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'Yehudi', q{Module name is 'Yehudi'};

    is $meta->version(), '0.001', q{Module version is 0.001};

    SKIP: {

	Archive::Tar->can( 'extract' )
	    or skip 'No Archive::Tar->extract()', 1;

	my $extracted;

	no warnings qw{ redefine };

	local *Archive::Tar::extract = sub {
	    $extracted++;
	};

	$kit->extract();

	ok $extracted,
	    'The extract() method calls Archive::Tar->extract()';

    }

}

# Test access to .tar.bz2 archive

SKIP: {
    my $tests = 6;

    my $pkg = $module_index->{Johann}{distribution}
	or skip q{Module 'Johann' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    SKIP: {
	my $mtime = $cad->__test__file_mtime( $pkg );
	defined $mtime
	    or skip "Can not get mtime for $pkg", 1;
	cmp_ok $kit->mtime, '==', $mtime,
	    "Modification time of $pkg";
    }

    is $kit->path(), 'authors/id/B/BA/BACH/Johann-0.001.tar.bz2',
	'Path to Johann-0.001.tar.bz2';

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'Johann', q{Module name is 'Johann'};

    is $meta->version(), '0.001', q{Module version is 0.001};
}

# Test access to .zip archive

SKIP: {
    my $tests = 10;

    my $pkg = $module_index->{PDQ}{distribution}
	or skip q{Module 'PDQ' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    SKIP: {
	my $mtime = $cad->__test__file_mtime( $pkg );
	defined $mtime
	    or skip "Can not get mtime for $pkg", 1;
	cmp_ok $kit->mtime, '==', $mtime,
	    "Modification time of $pkg";
    }

    is $kit->path(), 'authors/id/B/BA/BACH/PDQ-0.000_01.zip',
	'Path to PDQ-0.000_01.zip';

    is $kit->base_directory(), 'PDQ-0.000_01/',
	'Base directory of BACH/PDQ-0.000_01.zip';

    is_deeply [ $kit->list_contents() ], [ qw{
	lib/PDQ.pm
	Makefile.PL
	MANIFEST
	META.json
	META.yml
	t/basic.t
	} ],
    'Contents of BACH/PDQ-0.000_01.zip';

    is $kit->get_item_content( 'Makefile.PL' ),
	slurp( 'mock/src/repos/BACH/PDQ/Makefile.PL' ),
	"Can extract Makefile.PL from $pkg";

#   {
##	Zip file time stamps are in local time. The only way to get this
##	test to work would be to carry zone information outside the Zip
##	file. Since in the general case this is not available, the whole
##	test seems pretty pointless.
#	my $got = $kit->get_item_mtime( 'Makefile.PL' );
#	my $want = $archive_member_mtime{ 'BACH/PDQ/Makefile.PL' };
#	ok abs( $got - $want ) < 2,
#	"Can get Makefile.PL mod time from $pkg"
#	    or mtime_diag( $got, $want );
#   }

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'PDQ', q{Module name is 'PDQ'};

    is $meta->version(), '0.000_01', q{Module version is 0.000_01};

    SKIP: {

	Archive::Zip::Archive->can( 'extractTree' )
	    or skip 'No Archive::Zip::Archive->extractTree()', 1;

	my $extracted;

	no warnings qw{ redefine };

	local *Archive::Zip::Archive::extractTree = sub {
	    $extracted++;
	};

	$kit->extract();

	ok $extracted,
	    'The extract() method calls Archive::Zip::Archive->extractTree()';

    }

}

$cad = CPAN::Access::AdHoc->new(
    http_error_handler => sub {
	my ( $self, $path, $resp ) = @_;
	$resp->code() == 404
	    and $path eq q{modules/02packages.details.txt.gz}
	    and return;
	goto &CPAN::Access::AdHoc::DEFAULT_HTTP_ERROR_HANDLER;
    },
    cpan => URI::file->new( Cwd::abs_path( 'mock/src' ) )
);

is_deeply scalar $cad->fetch_module_index(), {},
    'Can use HTTP error handler to change non-existant index to empty index';

$cad->flush();				# Flush cache
$cad->http_error_handler( undef );	# Restore default handler

eval {
    $cad->fetch_module_index();
    fail 'Restored HTTP error handler failed to throw error';
    1;
} or pass 'Restored HTTP error handler threw error';

done_testing;

sub mtime_diag {
    my ( $got, $want ) = map { strftime( $_ ) } @_;
    return diag( <<"EOD" );
    got: $got
    expected: $want
    This test may fail if your kit is on a FAT filesystem
EOD
}


sub slurp {
    my ( $fn ) = @_;
    local $/ = undef;
    open my $fh, '<', $fn
	or die "Unable to open $fn for input: $!\n";
    my $text = <$fh>;
    close $fh;
    return $text;
}

sub slurp_bin {
    my ( $fn ) = @_;
    local $/ = undef;
    open my $fh, '<', $fn
	or die "Unable to open $fn for input: $!\n";
    binmode $fh;
    my $text = <$fh>;
    close $fh;
    return $text;
}

sub strftime {
    my ( $time ) = @_;
    return POSIX::strftime( '%d-%b-%Y %H:%M:%S GMT', gmtime $time );
}

sub CPAN::Access::AdHoc::__test__file_mtime {
    my ( $self, $path ) = @_;
    defined( my $fqfn = $self->__test__file_name( $path ) )
	or return;
    my @stat = stat $fqfn
	or return;
    return $stat[9];
}

sub CPAN::Access::AdHoc::__test__file_name {
    my ( $self, $path ) = @_;
    my $uri = $self->cpan();
    $uri->isa( 'URI::file' )
	or return;
    if ( $path =~ m{ / \z }smx ) {
	return File::Spec->catdir( $uri->dir(), $path );
    } else {
	return File::Spec->catfile( $uri->file(), $path );
    }
}

1;

# ex: set textwidth=72 :
