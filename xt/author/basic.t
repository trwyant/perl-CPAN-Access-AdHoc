package main;

use 5.006002;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

require_ok 'Test::Without::Module';

# The following are not requirements for development because mock
# objects are used in testing.

# require_ok 'CPANPLUS';
# require_ok 'App::cpanm';
# require_ok 'CPAN::Mini';

done_testing;

1;

# ex: set textwidth=72 :
