package main;

use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use Test::More 0.88;	# Because of done_testing();
use CPAN::Access::AdHoc::Archive;
use File::chdir;

eval {
    require File::Temp;
    File::Temp->can( 'new' ) && File::Temp->can( 'newdir' );
} or plan skip_all =>
    'File::Temp unavailable, or does not support new() or newdir()';

sub are_archives_same (@);

SKIP: {
    my $tests = 1;
    my $name = 'Yehudi-0.001.tar.gz';

    my $arc1 = CPAN::Access::AdHoc::Archive->wrap_archive(
	"mock/repos/authors/id/M/ME/MENUHIN/$name" )
	or skip "Can not wrap original $name", $tests;

    my $td = File::Temp->newdir()
	or skip "Unable to create temp dir: $!", $tests;

    local $CWD = $td;

    $arc1->write();

    my $arc2 = CPAN::Access::AdHoc::Archive->wrap_archive(
	{ author => 'MENUHIN' }, $name );

    are_archives_same "rewritten $name" => $arc2,
	"original $name" => $arc1;
}

SKIP: {
    my $tests = 1;
    my $name = 'Johann-0.001.tar.bz2';

    my $arc1 = CPAN::Access::AdHoc::Archive->wrap_archive(
	"mock/repos/authors/id/B/BA/BACH/$name" )
	or skip "Can not wrap original $name", $tests;

    my $td = File::Temp->newdir()
	or skip "Unable to create temp dir: $!", $tests;

    local $CWD = $td;

    $arc1->write();

    my $arc2 = CPAN::Access::AdHoc::Archive->wrap_archive(
	{ author => 'BACH' }, $name );

    are_archives_same "rewritten $name" => $arc2,
	"original $name" => $arc1;

}

SKIP: {
    my $tests = 1;
    my $name = 'PDQ-0.000_01.zip';

    my $arc1 = CPAN::Access::AdHoc::Archive->wrap_archive(
	"mock/repos/authors/id/B/BA/BACH/$name" )
	or skip "Can not wrap original $name", $tests;

    my $td = File::Temp->newdir()
	or skip "Unable to create temp dir: $!", $tests;

    local $CWD = $td;

    $arc1->write();

    my $arc2 = CPAN::Access::AdHoc::Archive->wrap_archive(
	{ author => 'BACH' }, $name );

    are_archives_same "rewritten $name" => $arc2,
	"original $name" => $arc1;

}

SKIP: {
    my $tests = 1;
    my $name = '02packages.details.txt.gz';

    my $arc1 = CPAN::Access::AdHoc::Archive->wrap_archive(
	"mock/repos/modules/$name" )
	or skip "Can not wrap original $name", $tests;

    my $td = File::Temp->newdir()
	or skip "Unable to create temp dir: $!", $tests;

    local $CWD = $td;

    $arc1->write();

    my $arc2 = CPAN::Access::AdHoc::Archive->wrap_archive(
	{ directory => 'modules' }, $name );

    are_archives_same "rewritten $name" => $arc2,
	"original $name" => $arc1;

}

done_testing;

sub are_archives_same (@) {
    my ( $name1, $arc1, $name2, $arc2 ) = @_;
    my $got1 = $arc1->base_directory();
    my $got2 = $arc2->base_directory();
    $got1 eq $got2 or do {
	@_ = ( $got1, $got2, "$name1 and $name2 base directories same" );
	goto &is;
    };
    my %file;
    my $mask = 1;
    my $full_mask = 0;
    foreach my $arc ( $arc1, $arc2 ) {
	foreach my $fn ( $arc->list_contents() ) {
	    $file{$fn} |= $mask;
	}
	$full_mask |= $mask;
	$mask <<= 1;
    }
    foreach my $fn ( sort keys %file ) {
	if ( $file{$fn} == 1 ) {
	    @_ = ( "$fn appears in $name1 but not $name2" );
	    goto &fail;
	} elsif ( $file{$fn} == 2 ) {
	    @_ = ( "$fn appears in $name2 but not $name1" );
	    goto &fail;
	} elsif ( $file{$fn} == 3 ) {
	    $got1 = $arc1->get_item_content( $fn );
	    $got2 = $arc2->get_item_content( $fn );
	    $got1 eq $got2 or do {
		@_ = ( $got1, $got2,
		    "File $fn is the same in $name1 and $name2" );
		goto &is;
	    };
	}
    }
    @_ = ( "$name1 is the same as $name2" );
    goto &pass;
}

1;

# ex: set textwidth=72 :
