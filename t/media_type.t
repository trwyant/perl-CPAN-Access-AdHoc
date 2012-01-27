package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

use CPAN::Access::AdHoc::Util qw{ __guess_media_type };
use HTTP::Response;

sub encoding ($$);
sub media_type ($$);

media_type 'foo.tar.gz', 'application/x-tar';
encoding   'foo.tar.gz', 'gzip';

media_type 'foo.tgz',     'application/x-tar';
encoding   'foo.tgz',     'gzip';

media_type 'foo.tar.bz2', 'application/x-tar';
encoding   'foo.tar.bz2', 'x-bzip2';

media_type 'foo.tbz',     'application/x-tar';
encoding   'foo.tbz',     'x-bzip2';

media_type 'foo.zip',     'application/zip';
encoding   'foo.zip',     undef;

media_type 'foo.txt',     'text/plain';
encoding   'foo.txt',     undef;

media_type 'foo.txt.gz',  'text/plain';
encoding   'foo.txt.gz',  'gzip';

media_type 'foo.pm',      'application/octet-stream';
encoding   'foo.pm',      undef;

media_type 'foo.pm.gz',   'application/octet-stream';
encoding   'foo.pm.gz',   'gzip';

media_type 'foo.data',    'application/octet-stream';
encoding   'foo.data',    undef;

media_type 'foo.data.gz', 'application/octet-stream';
encoding   'foo.data.gz', 'gzip';

done_testing;

1;

sub encoding ($$) {
    my ( $fn, $encoding ) = @_;
    my $resp = HTTP::Response->new();
    __guess_media_type( $resp, $fn );
    my $title = sprintf q{Encoding of '%s' is %s}, $fn,
	defined $encoding ? "'$encoding'" : 'undef';
    @_ = ( scalar $resp->header( 'Content-Encoding' ), $encoding, $title );
    goto &is;
}

sub media_type ($$) {
    my ( $fn, $type ) = @_;
    my $resp = HTTP::Response->new();
    __guess_media_type( $resp, $fn );
    @_ = ( scalar $resp->header( 'Content-Type' ), $type,
	"Media type of '$fn' is '$type'" );
    goto &is;
}

# ex: set textwidth=72 :
