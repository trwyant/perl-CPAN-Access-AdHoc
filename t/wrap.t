package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

use CPAN::Access::AdHoc::Archive;

SKIP: {
    my $tests = 7;	# Not counting instantiation.
    my $pkg = 'M/ME/MENUHIN/Yehudi-0.001.tar.gz';
    my $fn = "mock/repos/authors/id/$pkg";
    my $kit;
    eval {
	$kit = CPAN::Access::AdHoc::Archive->wrap_archive( $fn );
	1;
    } or do {
	fail "Failed to wrap $fn: $@";
	skip 'Unable to instantiate object', 1;
    };
    pass "Wrap $fn";

    is $kit->path(), 'authors/id/M/ME/MENUHIN/Yehudi-0.001.tar.gz',
	'Path to Yehudi-0.001.tar.gz';

    is $kit->base_directory(), 'Yehudi-0.001/',
	'Base directory of Yehudi-0.001.tar.gz';

    is_deeply [ $kit->list_contents() ], [ qw{
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

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'Yehudi', q{Module name is 'Yehudi'};

    is $meta->version(), '0.001', q{Module version is 0.001};

}

SKIP: {
    my $tests = 7;	# Not counting instantiation.
    my $pkg = 'B/BA/BACH/PDQ-0.000_01.zip';
    my $fn = "mock/repos/authors/id/$pkg";
    my $kit;
    eval {
	$kit = CPAN::Access::AdHoc::Archive->wrap_archive(
	    { author => 'SCHICKELE' }, $fn );
	1;
    } or do {
	fail "Failed to wrap $fn: $@";
	skip 'Unable to instantiate object', 1;
    };
    pass "Wrap $fn as user SCHICKELE";

    is $kit->path(), 'authors/id/S/SC/SCHICKELE/PDQ-0.000_01.zip',
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

    my $meta = $kit->metadata();

    ok $meta, "Extract metadata from '$pkg'";

    is $meta->name(), 'PDQ', q{Module name is 'PDQ'};

    is $meta->version(), '0.000_01', q{Module version is 0.000_01};
}

done_testing;

sub slurp {
    my ( $fn ) = @_;
    local $/ = undef;
    open my $fh, '<', $fn
	or die "Unable to open $fn for input: $!\n";
    my $text = <$fh>;
    close $fh;
    return $text;
}

1;

# ex: set textwidth=72 :
