package CPAN::Access::AdHoc::Default::CPAN::cpanm;

use 5.010;

use strict;
use warnings;

use parent qw{ CPAN::Access::AdHoc::Default::CPAN };

use CPAN::Access::AdHoc::Util qw{ __load };
use Getopt::Long 2.33;

our $VERSION = '0.000_235';

use constant CONFIGURED	=> eval {
    __load( 'App::cpanminus' );
    1;
} || 0;

sub get_cpan_url {

    CONFIGURED
	or return;

    my @mirrors;
    if ( defined $ENV{PERL_CPANM_OPT} ) {
	my $psr = Getopt::Long::Parser->new();
	$psr->configure( qw{ pass_through } );
	local @ARGV = split qr{ \s+ }smx, $ENV{PERL_CPANM_OPT};
	$psr->getoptions( 'mirror=s@' => \@mirrors);
    }
    @mirrors
	or @mirrors = ( qw{ https://cpan.metacpan.org } );

    return @mirrors;
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Default::CPAN::cpanm - Get the default CPAN URL from cpanminus.

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Default::CPAN::CPAN;
 print CPAN::Access::AdHoc::Default::CPAN::CPAN->get_cpan_url();

=head1 DESCRIPTION

This utility class retrieves a CPAN URL from the user's C<PERL_CPAN_OPT>
environment variable.
This is the first C<file:> URL specified by the C<--mirror> option.
parameter. If there is no C<file:> URL, it is the first URL whatever the
scheme. If the C<PERL_CPAN_OPT> variable is defined but does not contain
a C<--mirror> option, L<https://cpan.metacpan.org> is returned.

=head1 METHODS

This class supports the following public methods:

=head2 get_cpan_url

This static method returns the CPAN repository URLs configured in
F<cpanm>.  If the repository URLs can not be determined, nothing is
returned.

=head1 SEE ALSO

L<App::cpanminus|App::cpanminus>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc>,
L<https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2022, 2024 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
