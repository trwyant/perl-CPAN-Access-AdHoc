package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;
use CPAN::Access::AdHoc::Util qw{ __is_text };

use constant FALSE => 0;
use constant TRUE  => 1;

is __is_text( undef ), undef, '<undef> is neither text not binary';
is __is_text( '' ), undef, q{'' is neither text nor binary};

is __is_text( "A" ), TRUE, q{The letter 'A' is text};
is __is_text( "\t" ), TRUE, q{A horizontal tab is text};
is __is_text( "\0" ), FALSE, q{A null character is not text};

is __is_text( <<'EOD' ), TRUE, q{'How doth the little ...' is text};
How doth the little crocodile
Improve his shining tail,
By pouring waters of the Nile
On every golden scale.
EOD

is __is_text( "K\N{U+F6}lsch" ), TRUE,
    q{The beer they make in Cologne is text};

is __is_text( __c( 1, 10 ) ), FALSE, q{Code points 1-10 are not text};

is __is_text( __c( 24, 127 ) ), TRUE, q{Code points 24-127 are text};

done_testing;

sub __c {
    my ( $low, $high ) = @_;
    my $hex = join '', map { sprintf '%02X', $_ } $low .. $high;
    return pack 'H*', $hex;
}

1;

# ex: set textwidth=72 :
