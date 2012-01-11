package main;

use 5.008;

use strict;
use warnings;

use POSIX ();
use Test::More 0.88;	# Because of done_testing();

use lib qw{ mock };

use CPAN::Access::AdHoc;

my %maybe_bad_mtime = map { $_ => 1 } qw{ DOS MSWin32 cygwin };

my $text = slurp( 'mock/repos/modules/02packages.details.txt' );

my $cad = CPAN::Access::AdHoc->new();

# Test access to module index

is $cad->fetch( 'modules/02packages.details.txt' )->get_item_content(),
    $text,
    'Fetch the un-compressed packages details';

{
    my $got = $cad->fetch( 'modules/02packages.details.txt'
    )->get_item_mtime(),
    my $want = ( stat 'mock/repos/modules/02packages.details.txt' )[9];
    ok abs( $got - $want ) < 2,
    'Can get modules/02packages.details.txt mod time'
	or mtime_diag( $got, $want );
}

is $cad->fetch( 'modules/02packages.details.txt.gz' )->get_item_content(),
    $text,
    'Fetch the compressed packages details';

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

# Test access to .tar.gz archive

SKIP: {
    my $tests = 8;

    my $pkg = $module_index->{Yehudi}{distribution}
	or skip q{Module 'Yehudi' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    is $kit->path(), 'authors/id/M/ME/MENUHIN/Yehudi-0.001.tar.gz',
	'Path to Yehudi-0.001.tar.gz';

    is $kit->get_item_content( 'Makefile.PL' ),
	slurp( 'mock/src/repos/MENUHIN/Yehudi/Makefile.PL' ),
	"Can extract Makefile.PL from $pkg";

TODO: {

	local $TODO = 'Does not work on kit expanded from tarball';

	my $got = $kit->get_item_mtime( 'Makefile.PL' );
	my $want = ( stat 'mock/src/repos/MENUHIN/Yehudi/Makefile.PL' )[9];
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
    my $tests = 5;

    my $pkg = $module_index->{Johann}{distribution}
	or skip q{Module 'Johann' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    is $kit->path(), 'authors/id/B/BA/BACH/Johann-0.001.tar.bz2',
	'Path to Johann-0.001.tar.bz2';

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'Johann', q{Module name is 'Johann'};

    is $meta->version(), '0.001', q{Module version is 0.001};

}

# Test access to .zip archive

SKIP: {
    my $tests = 8;

    my $pkg = $module_index->{PDQ}{distribution}
	or skip q{Module 'PDQ' not indexed}, $tests;

    my $kit = $cad->fetch_distribution_archive( $pkg );

    ok $kit, "Fetch distribution '$pkg'";

    is $kit->path(), 'authors/id/B/BA/BACH/PDQ-0.000_01.zip',
	'Path to PDQ-0.000_01.zip';

    is $kit->get_item_content( 'Makefile.PL' ),
	slurp( 'mock/src/repos/BACH/PDQ/Makefile.PL' ),
	"Can extract Makefile.PL from $pkg";

TODO: {
	local $TODO = 'Does not work on kit expanded from tarball';

	my $got = $kit->get_item_mtime( 'Makefile.PL' );
	my $want = ( stat 'mock/src/repos/BACH/PDQ/Makefile.PL' )[9];
	ok abs( $got - $want ) < 2,
	"Can get Makefile.PL mod time from $pkg"
	    or mtime_diag( $got, $want );
    }

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

sub strftime {
    my ( $time ) = @_;
    return POSIX::strftime( '%d-%b-%Y %H:%M:%S GMT', gmtime $time );
}

1;

# ex: set textwidth=72 :
