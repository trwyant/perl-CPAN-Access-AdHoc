package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;

eval {
    require Test::Kwalitee;
    1;
} or plan skip_all => 'Test::Kwalitee not found';

Test::Kwalitee->import();

-f 'Debian_CPANTS.txt'			# Don't know what this is,
    and unlink 'Debian_CPANTS.txt';	# but _I_ didn't order it.

1;

# ex: set textwidth=72 :
