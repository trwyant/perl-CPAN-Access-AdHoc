package CPAN::Access::AdHoc::Util;

use 5.006002;

use strict;
use warnings;

use File::Find;
use File::Spec;

our $VERSION = '0.000_01';

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

sub plugins {
    my ( $base ) = @_;

    $base =~ m< \A
	[[:alpha:]_] \w*
	(?: :: [[:alpha:]_] \w* )* \z
    >smx
	or do{
	require Carp;
	Carp::croak( "Malformed base module name '$base'" );
    };

    ( my $dir = $base ) =~ s{ :: }{/}smxg;

    foreach my $inc ( @INC ) {
	my $path = File::Spec->catdir( $inc, $dir );
	-d $path
	    or next;
	my @found;
	find( sub {
		-f or return;
		m{ [.] pm \z }smx
		    or return;
		my $module;
		eval {
		    $module = File::Spec->abs2rel( $File::Find::name,
			$inc );
		    $INC{$module}
			or require $module;
		    1;
		} or return;
		$module =~ s{ [.] [^.]* \z }{}smx;
		$module =~ s{ / }{::}smxg;
		push @found, $module;
		return;
	    }, $path );
	return ( sort @found );
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
C<CPAN-Access-AdHoc> package. Documentation is for the benefit of the
author only.

=head1 SUBROUTINES

This module provides the following public subroutines:

=head2 load

This subroutine takes as its arguments one or more module names, and
loads them.

=head2 plugins

This subroutine takes as its argument a base package name space, and
loads any modules found under that name space, returning the names of
all modules loaded, in ASCIIbetical order.

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
