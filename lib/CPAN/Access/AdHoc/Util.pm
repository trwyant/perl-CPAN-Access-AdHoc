package CPAN::Access::AdHoc::Util;

use 5.008;

use strict;
use warnings;

use File::Find;
use File::Spec;

our $VERSION = '0.000_03';

my %loaded;

sub load {
    my ( @args ) = @_;
    foreach my $module ( @args ) {

	$module =~ m< \A
	    [[:alpha:]_] \w*
	    (?: :: [[:alpha:]_] \w* )* \z
	>smx
	    or do {
		require Carp;
		Carp::croak( "Malformed module name '$module'" );
	    };

	( my $fn = $module ) =~ s{ :: }{/}smxg;
	$fn .= '.pm';
	require $fn;
    }
    return;
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Util - Utility functions for CPAN::Access::AdHoc

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Util;

 say 'The CPAN default plugins are ',
     join ', ', CPAN::Access::AdHoc::Util::plugins(
         'CPAN::Access::AdHoc::Default::CPAN' );

=head1 DESCRIPTION

This module provides utility functions to
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the
C<CPAN-Access-AdHoc> distribution. Documentation is for the benefit of
the author only.

=head1 SUBROUTINES

This module provides the following public subroutines:

=head2 load

This subroutine takes as its arguments one or more module names, and
loads them.

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
