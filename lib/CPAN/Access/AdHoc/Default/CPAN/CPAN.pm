package CPAN::Access::AdHoc::Default::CPAN::CPAN;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{ __load };

our $VERSION = '0.000_194';

my $configured = eval {
    __load( 'CPAN' );
    1;
};

sub get_default {
    my ( $class ) = @_;

    $configured
	or return;

    {
	# Okay, here's the deal on the monkey patch.
	#
	# There is, to the best of my research, no supported way to
	# prevent CPAN from initializing itself; there are just various
	# unsupported ways. As of CPAN::HandleConfig 5.5003 (with CPAN
	# 1.9800 07-Aug-2011) they are:
	#
	# * The monkey patch actually used. This exploits the fact that
	#   the load() method returns if the do_init argument is false
	#   (which it is by default) and there are no missing
	#   configuration items (which the monkey patch takes care of)
	# * Set $CPAN::HandleConfig::loading to a positive number. This
	#   is a guard against accidental recursion.
	#
	# Parse::CPAN::Packages::Fast by Slaven Rezic seems to make the
	# assumption you can get the same effect by setting
	# $CPAN::Be_Silent to a true value, but that is not how I read
	# the CPAN code.

	no warnings qw{ once redefine };	## no critic (ProhibitNoWarnings)
	local *CPAN::HandleConfig::missing_config_data = sub { return };
	CPAN::HandleConfig->load();
    }

    exists $CPAN::Config->{urllist}
	and @{ $CPAN::Config->{urllist} }
	or return;

    return @{ $CPAN::Config->{urllist} };
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN::CPAN - Get the default CPAN URL from CPAN

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Default::CPAN::CPAN;
 print CPAN::Access::AdHoc::Default::CPAN::CPAN->get_default();

=head1 DESCRIPTION

This utility class retrieves a CPAN URL from the user's CPAN
configuration. This is the first C<file:> URL in the C<urllist>
parameter. If there is no C<file:> URL, it is the first URL whatever the
scheme.

=head1 METHODS

This class supports the following public methods:

=head2 get_default

This static method returns the user's CPAN repository URL.  If the
repository URL can not be determined, nothing is returned.

=head1 SEE ALSO

L<CPAN|CPAN>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
