package main;

use 5.010;

use strict;
use warnings;

use lib qw{ ./mock };

use Scalar::Util qw{ blessed };
use Test2::V0;

use CPAN::Access::AdHoc;
use CPAN::Access::AdHoc::Archive;
use CPAN::Access::AdHoc::Util qw{ :all };

init();

caveat( \&__whinge, 'Awww', qr{\AAwww\b}, 'Check __whinge' );

exception( \&__wail, 'Pfui', qr{\APfui\b}, 'Check __wail' );

exception( \&__weep, 'Fubar', qr{\AProgramming Error - Fubar},
    'Check __weep' );

exception( \&__load, '1module', qr{\AMalformed module name '1module'},
    'Check __load' );

exception( new => [ fubar => 'bazzle' ],
    qr{\A\QUnknown attribute(s): fubar},
    'New with invalid arguments.' );

exception( fetch => 'fubar/bazzle',
    qr{/fubar/bazzle: 404\b},
    'fetch a non-existant file.' );

exception( fetch => [ 'fubar/bazzle', http_error_handler => sub {
	$_[2]->code( 'CDIV' );	# Roman numeral for 404
	$_[2]->message( 'Otnay Oundfay' );
	goto &CPAN::Access::AdHoc::DEFAULT_HTTP_ERROR_HANDLER;
    }, ],
    qr{/fubar/bazzle: CDIV\b},
    'fetch a non-existant file, temporary error handler.' );

exception( fetch => 'fubar/bazzle',
    qr{/fubar/bazzle: 404\b},
    'fetch a non-existant file, back to default behaviour.' );

caveat( http_error_handler => sub {
##  my ( $self, $url, $resp ) = @_;
    my ( undef, $url ) = @_;		# Invocant and response not used
    $url =~ m{ /modules/02packages_details [.] txt [.] gz \z }smx
	and return;
    die "$url not found\n"
}, undef,
    'Set an alternate HTTP error handler' );

exception( fetch => 'fubar/bazzle',
    qr{\Afubar/bazzle not found\b},
    'Fetch a non-existant file and get alternate caveat.' );

eval {
    caveat( fetch => 'fubar/modules/02packages.details.txt.gz', undef,
	'Can supress exception with HTTP error handler' );
    1;
} or fail "HTTP error handler allowed unexpected error $@";

caveat( http_error_handler => undef, undef,
    'Restore the original HTTP error handler' );

exception( fetch => 'fubar/bazzle',
    qr{/fubar/bazzle: 404\b},
    'Fetch a non-existant file and get original caveat.' );


SKIP: {
    my $tests = 1;

    eval {
	require LWP::UserAgent;
	1;
    } or skip 'LWP::UserAgent can not be loaded', $tests;

    eval {
	require HTTP::Response;
	1;
    } or skip 'HTTP::Response can not be loaded', $tests;

    no warnings qw{ redefine };

    local *LWP::MediaTypes::guess_media_type = sub {
##	my ( $url, $rslt ) = @_;
	my ( undef, $rslt ) = @_;	# URL not used
	$rslt->header( 'Content-Type' => 'something/awful' );
	return;
    };

    exception( fetch => 'authors/01mailrc.txt.gz',
	qr{Unsupported Content-Type 'something/awful'},
	'Unexpected Content-Type' );
}

SKIP: {
    my $tests = 3;

    eval {
	require Errno;
	Errno->can( 'ENOENT' );
	1;
    } or skip 'Errno can not be loaded, or does not support ENOENT', $tests;

    no warnings qw{ redefine };

    local *IO::File::new = sub {
	$! = Errno::ENOENT();
	return;
    };

    exception( fetch_author_index => [],
	qr{\AUnable to open string reference:},
	'Failure to open a string reference in fetch_author_index()' );

    exception( fetch_module_index => [],
	qr{\AUnable to open string reference:},
	'Failure to open a string reference in fetch_module_index()' );

    exception( fetch_registered_module_index => [],
	qr{\AUnable to open string reference:},
	'Failure to open a string reference in fetch_registered_module_index()' );
}

exception( fetch_distribution_checksums => 'fubar',
    qr{\AFailed to get file:},
    'Fetch checksums for an invalid distribution name' );

SKIP: {
    my $tests = 1;

    eval {
	require Digest::SHA;
	1;
    } or skip 'Unable to load Digest::SHA', $tests;

    no warnings qw{ redefine };

    local *Digest::SHA::sha256_hex = sub {
	return 'impossible checksum';
    };

    exception( fetch_distribution_archive => 'BACH/Johann-0.001.tar.bz2',
	qr{\AChecksum failure on},
	'Checksum failure' );
}

exception( config => {},
    qr{\AAttribute 'config' must be a file name or a Config::Tiny reference},
    'Set config() to invalid configuration' );

exception( default_cpan_source => 'fubar',
    qr{\AUnknown default_cpan_source 'fubar'},
    'Set default_cpan_source() to bad value' );

exception( cpan => 'fubar://bazzle/',
    qr{\AURL scheme fubar: is unsupported},
    'Set cpan() to invalid URL.' );

init( bless {}, 'CPAN::Access::AdHoc::Archive' );

exception( base_directory => [],
    qr{\A\QProgramming Error - The base_directory() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive base_directory method' );

exception( extract => [],
    qr{\A\QProgramming Error - The extract() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive extract method' );

exception( get_item_content => [],
    qr{\A\QProgramming Error - The get_item_content() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive get_item_content method' );

exception( get_item_mtime => [],
    qr{\A\QProgramming Error - The get_item_mtime() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive get_item_mtime method' );

exception( item_present => [],
    qr{\A\QProgramming Error - The item_present() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive item_present method' );

exception( list_contents => [],
    qr{\A\QProgramming Error - The list_contents() method must be overridden},
    'Must override the CPAN::Access::AdHoc::Archive list_contents method' );

exception( wrap_archive => [
	{ author => 'NOBODY', directory => 'modules/' },
	'mock/repos/modules/02packages.details.txt.gz',
    ],
    qr{\ASpecifying both 'author' and 'directory' is ambiguous\b},
    q{Can not specify both 'author and 'directory' to wrap_archive} );

done_testing;

{

    my $cad;

    my %instantiator;

    BEGIN {
	%instantiator = map { $_ => 1 } qw{ new };
    }

    sub _xqt {
	my ( $method, $args ) = @_;
	ARRAY_REF eq ref $args
	    or $args = [ $args ];
	my $rslt = eval {
	    if ( CODE_REF eq ref $method ) {
		$method->( @{ $args } );
	    } elsif ( $instantiator{$method} ) {
		CPAN::Access::AdHoc->$method( @{ $args } );
	    } else {
		$cad->$method( @{ $args } );
	    }
	    1;
	};
	return $rslt;
    }

    sub exception {
	my ( $method, $args, $exception, $title ) = @_;
	_xqt( $method, $args ) or do {
	    if ( defined( my $err = $@ ) ) {
		@_ = ( $err, $exception, $title );
		REGEXP_REF eq ref $exception
		    and goto &like;
		goto &is;
	    } else {
		@_ = "$method() failed, but \$@ not set";
		goto &fail;
	    }
	};
	@_ = "$method() unexpectedly succeeded";
	goto &fail;
    }

    sub init {
	my ( $class, @args ) = @_;

	if ( blessed( $class ) ) {
	    $cad = $class;
	    return;
	}

	$class ||= 'CPAN::Access::AdHoc';
	$cad = undef;
	eval {
	    $cad = $class->new( @args );
	    1;
	} and $cad or do {
	    @_ = 'Failed to instantiate CPAN::Access::AdHoc';
	    goto &fail;
	};
	@_ = 'Instantiated CPAN::Access::AdHoc';
	goto &pass;
    }


    sub caveat {	# was warning() but conflicted with Test2::V0
	my ( $method, $args, $caveat, $title ) = @_;
	my $err;
	{
	    local $SIG{__WARN__} = sub { $err = $_[0] };
	    _xqt( $method, $args );
	}
	if ( defined $err ) {
	    if ( defined $caveat ) {
		@_ = ( $err, $caveat, $title );
		REGEXP_REF eq ref $caveat
		    and goto &like;
		goto &is;
	    } else {
		@_ = ( "$title gave caveat '$err'" );
		goto &fail;
	    }
	} elsif ( defined $caveat ) {
	    @_ = ( "$method() did not generate a caveat" );
	    goto &fail;
	} else {
	    @_ = ( $title );
	    goto &pass;
	}
    }

}

1;

# ex: set textwidth=72 :
