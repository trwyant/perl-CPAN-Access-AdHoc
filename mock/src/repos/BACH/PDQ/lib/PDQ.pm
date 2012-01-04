package PDQ;

use 5.006002;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_01';

sub instrument {
    return 'windbreaker';
}

1;

__END__

=head1 NAME

PDQ - A class representing PDQ Bach

=head1 SYNOPSIS

 use PDQ;
 
 say PDQ->instrument;

=head1 DESCRIPTION

This class represents PDQ Bach to the extent required to
build a mock CPAN to test L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>

=head1 METHODS

This class supports the following public methods:

=head2 instrument

Returns C<'windbreaker'>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
