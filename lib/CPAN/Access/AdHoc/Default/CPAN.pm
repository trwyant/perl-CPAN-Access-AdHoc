package CPAN::Access::AdHoc::Default::CPAN;

use 5.010;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_216';

sub get_clean_checksums {
    return 0;
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN - Superclass for default values mechanism.

=head1 SYNOPSIS

None -- this is an abstract class.

=head1 DESCRIPTION

This Perl class forms the root of the class hierarchy that retrieves
default configuration values from the various CPAN clients.

=head1 METHODS

This class supports the following public methods:

=head2 get_cpan_url

This method returns the CPAN url from the client configuration.

This method B<must> be overridden.

=head2 get_clean_checksums

This method returns the appropriate C<clean_checksums> default based on
the client configuration.

Unless overridden, this will return a false value.

=head1 ATTRIBUTES

This class has the following attributes:


=head1 SEE ALSO

<<< replace or remove boilerplate >>>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https:rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Tom Wyant F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2016-2020 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
