package CPAN::Access::AdHoc::Default::CPAN::cpanm;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util;
use Getopt::Long 2.33;

our $VERSION = '0.000_02';

my $configured = eval {
    CPAN::Access::AdHoc::Util::load( 'App::cpanminus' );
    1;
};

sub get_default {
    $configured
	or return;
    my @mirrors;
    if ( defined $ENV{PERL_CPANM_OPT} ) {
	my $psr = Getopt::Long::Parser->new();
	$psr->configure( qw{ pass_through } );
	local @ARGV = split qr{ \s+ }smx, $ENV{PERL_CPANM_OPT};
	$psr->getoptions( 'mirror=s@' => \@mirrors);
    }
    @mirrors
	or @mirrors = ( qw{ http://search.cpan.org/CPAN } );

    return @mirrors;
}


1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN::cpanm - Get the default CPAN URL from cpanminus.

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Default::CPAN::CPAN;
 print CPAN::Access::AdHoc::Default::CPAN::CPAN->get_default();

=head1 DESCRIPTION


This utility class retrieves a CPAN URL from the user's C<PERL_CPAN_OPT>
environment variable.
This is the first C<file:> URL specified by the C<--mirror> option.
parameter. If there is no C<file:> URL, it is the first URL whatever the
scheme. If the C<PERL_CPAN_OPT> variable is defined but does not contain
a C<--mirror> option, L<http://search.cpan.org/CPAN> is returned.

=head1 METHODS

This class supports the following public methods:

=head2 get_default

This static method returns the CPAN repository URLs configured in
F<cpanm>.  If the repository URLs can not be determined, nothing is
returned.

=head1 SEE ALSO

L<cpanm|cpanm>.

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
