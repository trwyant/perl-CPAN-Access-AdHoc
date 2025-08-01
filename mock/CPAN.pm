package CPAN;

use 5.010;

use strict;
use warnings;

use Cwd ();

our $VERSION = '0.000_237';

our $CONFIG ||= {
    urllist	=> [ 'file://' . Cwd::abs_path( 'mock/repos' ) ],
};

sub CPAN::HandleConfig::missing_config_data {
    require Carp;
    Carp::confess( 'This method must be monkey-patched out' );
}

sub CPAN::HandleConfig::load {
    our $Config = $CONFIG;
    return;
}

1;

__END__

=head1 NAME

CPAN - Mock CPAN class.

=head1 SYNOPSIS

 use lib qw{ ./mock };
 use CPAN;
 
 CPAN::HandleConfig->load();
 print 'CPAN urllist is ', join ', ', @{ $CPAN::Config->{urllist} };

=head1 DESCRIPTION

This class implements whatever parts of CPAN are needed to test
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the
C<CPAN-Access-AdHoc> distribution. All documentation is for the benefit
of the author.

=head1 METHODS

This class supports the following public methods:

=head2 CPAN::HandleConfig->load()

This method makes the contents of C<$CPAN::CONFIG> available in
C<$CPAN::Config>. By default, C<$CPAN::CONFIG> contains a configuration
hash with
C<< urllist => [ qw{ 'file://' . Cwd::abs_path( 'mock/repos' ) } ] >>.

=head1 SEE ALSO

The real L<CPAN|CPAN>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc>,
L<https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2022, 2024-2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
