package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

require_ok 'Johann';

is( Johann->instrument(), 'clavier', 'Johann plays the clavier' );

done_testing;

1;

# ex: set textwidth=72 :
