package CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini;

use 5.010;

use strict;
use warnings;

use parent qw{ CPAN::Access::AdHoc::Default::CPAN };

use CPAN::Access::AdHoc::Util qw{ __load };
use Cwd ();
use URI::file;

our $VERSION = '0.000_222';

my $configured = eval {
    __load( 'CPAN::Mini' );
    1;
};

sub get_cpan_url {
##  my ( $class ) = @_;		# Invocant is not used.

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

sub get_clean_checksums {

    $configured
	or return;

    my %config = CPAN::Mini->read_config( {} )
	or return;

    exists $config{exact_mirror}
	or return;

    return ! $config{exact_mirror};
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini - Get the default CPAN from CPAN::Mini

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini;
 print CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini->get_cpan_url();

=head1 DESCRIPTION

This utility class retrieves a CPAN URL from the user's CPAN::Mini
configuration. This is the local Mini CPAN repository represented as a
C<file://> URL.

=head1 METHODS

This class supports the following public methods:

=head2 get_cpan_url

This static method returns the user's CPAN::Mini local repository as a
C<file:> URL. If the repository can not be determined, nothing is
returned.

=head2 get_clean_checksums

This static method returns the negation of the CPAN::Mini
configuration's C<exact_mirror> attribute, or false if that attribute
does not exist.

=head1 SEE ALSO

L<CPAN::Mini|CPAN::Mini>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https:rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2021 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
