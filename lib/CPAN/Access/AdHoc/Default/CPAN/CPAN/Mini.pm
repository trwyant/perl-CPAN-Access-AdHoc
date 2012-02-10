package CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{ __load };
use Cwd ();
use URI::file;

our $VERSION = '0.000_13';

my $configured = eval {
    __load( 'CPAN::Mini' );
    1;
};

sub get_default {
    my ( $class ) = @_;

    $configured
	or return;

    my %config = CPAN::Mini->read_config( {} )
	or return;
    defined( my $local = $config{local} )
	or return;
    $local = Cwd::abs_path( $local );
    -d $local
	or return;
    my $uri = URI::file->new_abs( $local );
    return $uri;
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini - Get the default CPAN from CPAN::Mini

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini;
 print CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini->get_default();

=head1 DESCRIPTION

This utility class retrieves a CPAN URL from the user's CPAN::Mini
configuration. This is the local Mini CPAN repository represented as a
C<file://> URL.

=head1 METHODS

This class supports the following public methods:

=head2 get_default

This static method returns the user's CPAN::Mini local repository as a
C<file:> URL. If the repository can not be determined, nothing is
returned.

=head1 SEE ALSO

L<CPAN::Mini|CPAN::Mini>.

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
