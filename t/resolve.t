package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;

use lib qw{ ./mock };

use CPAN::Access::AdHoc;

my $cad = CPAN::Access::AdHoc->new();

is [ $cad->resolve_distributions( qw{ Johann PDQ } ) ],
    [ qw{ B/BA/BACH/Johann-0.001.tar.bz2 B/BA/BACH/PDQ-0.000_01.zip } ],
    'resolve_distributions()';

is $cad->resolve_unique_distribution( 'Yehudi' ),
    'M/ME/MENUHIN/Yehudi-0.001.tar.gz',
    'resolve_unique_distribution()';

done_testing;

1;

# ex: set textwidth=72 :
