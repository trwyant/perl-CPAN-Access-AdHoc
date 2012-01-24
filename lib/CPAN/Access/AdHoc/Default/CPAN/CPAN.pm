package CPAN::Access::AdHoc::Default::CPAN::CPAN;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{ __load };

our $VERSION = '0.000_05';

my $configured = eval {
    __load( 'CPAN' );
    1;
};

sub get_default {
    my ( $class ) = @_;

    $configured
	or return;

    {
	no warnings qw{ once redefine };	## no critic (ProhibitNoWarnings)
	local *CPAN::HandleConfig::missing_config_data = sub { return };
	CPAN::HandleConfig->load();
    }

    exists $CPAN::Config->{urllist}
	and @{ $CPAN::Config->{urllist} }
	or return;

    return _mung_url( @{ $CPAN::Config->{urllist} } );
}

sub _mung_url {
    my @arg = @_;
    foreach my $url ( @arg ) {
	$url =~ m{ / \z }smx
	    or $url .= '/';
    }
    return @arg;
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

Copyright (C) 2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
