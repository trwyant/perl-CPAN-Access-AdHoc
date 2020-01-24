package main;

use 5.010;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{ __classify_version };
use Test2::V0;

is [ sort( __classify_version() ) ], [ qw{
    development production unreleased } ], 'List of classifications';

foreach (
    [ unreleased	=> '0.000_001'	],
    [ development	=> '0.000_90'	],
    [ production	=> '0.001'	],
    [ development	=> '0.001_01'	],
) {
    my ( $want, $vers ) = @{ $_ };
    is __classify_version( $vers ), $want, "Version $vers is $want";
}

done_testing;

1;

# ex: set textwidth=72 :
