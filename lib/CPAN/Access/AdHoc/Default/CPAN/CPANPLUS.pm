package CPAN::Access::AdHoc::Default::CPAN::CPANPLUS;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{ __load };

our $VERSION = '0.000_08';

my $configured = eval {
    __load( 'CPANPLUS::Configure' );
    1;
};

sub get_default {
    my ( $class ) = @_;

    $configured
	or return;

    my $cpp = CPANPLUS::Configure->new();
    my $hosts = $cpp->get_conf( 'hosts' )
	or return;
    @{ $hosts }
	or return;

    foreach my $host ( @{ $hosts } ) {
	'file' eq $host->{scheme}
	    and return _make_url( $host );
    }

    return _make_url( $hosts->[0] );
}

sub _make_url {
    my @arg = @_;
    my @rslt;
    foreach my $host ( @arg ) {
	( my $path = $host->{path} ) =~ s{ \A (?! / ) }{/}smx;
	push @rslt, sprintf '%s://%s%s', $host->{scheme}, $host->{host}, $path;
    }
    return @rslt;
}

1;

__END__

=head1 NAME

CPANPLUS::AdHoc::Default::CPAN::CPANPLUS - Get the default CPAN from CPANPLUS

=head1 SYNOPSIS

 use CPANPLUS::AdHoc::Default::CPAN::CPANPLUS;
 print CPANPLUS::AdHoc::Default::CPAN::CPANPLUS->get_default();

=head1 DESCRIPTION

This utility class retrieves a CPANPLUS CPAN from the user's CPANPLUS
configuration. This is the first C<file:> CPAN in the C<hosts>
parameter. If there is no C<file:> CPAN, it is the first CPAN whatever the
scheme.

=head1 METHODS

This class supports the following public methods:

=head2 get_default

This static method returns the user's CPANPLUS repository CPAN.  If the
repository CPAN can not be determined, nothing is returned.

=head1 SEE ALSO

L<CPANPLUS|CPANPLUS>.

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
