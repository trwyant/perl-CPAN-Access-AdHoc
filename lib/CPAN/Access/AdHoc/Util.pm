package CPAN::Access::AdHoc::Util;

use 5.010;

use strict;
use warnings;

use parent qw{ Exporter };

use LWP::MediaTypes ();

our @EXPORT_OK = qw{
    __attr __cache __classify_version __expand_distribution_path
    __guess_media_type __load __whinge __wail __weep
    ARRAY_REF CODE_REF HASH_REF REGEXP_REF SCALAR_REF
};

our %EXPORT_TAGS = (
    all	=> [ @EXPORT_OK ],
    carp => [ qw{ __whinge __wail __weep } ],
    ref	=> [ grep { m/ \A [[:upper:]_]+ _REF \z /smx } @EXPORT_OK ],
);

our $VERSION = '0.000_230';

use constant ARRAY_REF	=> ref [];
use constant CODE_REF	=> ref sub {};
use constant HASH_REF	=> ref {};
use constant REGEXP_REF	=> ref qr{};
use constant SCALAR_REF	=> ref \0;

sub __attr {
    my ( $self ) = @_;
    my $name_space = caller;
    return ( $self->{$name_space} ||= {} );
}

sub __cache {
    my ( $self ) = @_;
    my $name_space = caller;
    return ( $self->{'.cache'}{$name_space} ||= {} );
}

sub __classify_version {
    local $_ = pop @_;
    defined
	or return ( qw{ development production unreleased } );
    return m/ \A 0+ [.] 0+ _ [0-8] /smx ? 'unreleased' :
	m/ _ /smx ? 'development' : 'production';
}

sub __expand_distribution_path {
    my ( $path ) = @_;
    $path =~ m{ \A ( [^/] ) / ( \1 [^/] ) / ( \2 [^/]* ) }smx
	and return $path;
    $path =~ m< \A ( [^/]{2} ) / ( \1 [^/]* ) >smx
	and return join '/', substr( $1, 0, 1 ), $path;
    $path =~ m< \A ( [^/]+ ) >smx
	or __wail( "Invalid distribution path '$path'" );
    return join '/', substr( $1, 0, 1 ),
	substr( $1, 0, 2 ), $path;
}

{

    my %expand_ending = (
	tbz	=> 'tar.bz2',
	tgz	=> 'tar.gz',
    );

    sub __guess_media_type {
	my ( $resp, $path ) = @_;

	if ( defined $path ) {
	    $resp->header( 'Content-Location' => $path );
	} else {
	    defined( $path = $resp->header( 'Content-Location' ) )
		or __wail(
		'No path provided, and none in Content-Location' );
	}

	# LWP::MediaTypes needs help with some paths.
	$path =~ s{ (?<= [.] ) ( [^.]+ ) \z }
	{ $expand_ending{$1} || $1 }smxie;

	LWP::MediaTypes::guess_media_type( $path, $resp );

	return;
    }

}

sub __load {
    my ( @args ) = @_;
    foreach my $module ( @args ) {

	$module =~ m< \A
	    [[:alpha:]_] \w*
	    (?: :: [[:alpha:]_] \w* )* \z
	>smx
	    or __wail( "Malformed module name '$module'" );

	( my $fn = $module ) =~ s{ :: }{/}smxg;
	$fn .= '.pm';
	require $fn;
    }
    return;
}

our @CARP_NOT = qw{
    CPAN::Access::AdHoc
    CPAN::Access::AdHoc::Archive
    CPAN::Access::AdHoc::Archive::Null
    CPAN::Access::AdHoc::Archive::Tar
    CPAN::Access::AdHoc::Archive::Zip
};

sub __whinge {
    my @args = @_;
    require Carp;
    Carp::carp( @args );
    return;
}

sub __wail {
    my @args = @_;
    require Carp;
    Carp::croak( @args );
}

sub __weep {
    my @args = @_;
    require Carp;
    Carp::confess( 'Programming Error - ', @args );
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

This module provides the following public subroutines (which are
nonetheless private to the C<CPAN-Access-AdHoc> distribution):

=head2 __attr

This subroutine/method returns the hash element of its argument which is
named after the caller's name space. This element is initialized to an
empty hash if necessary.

=head2 __cache

This method returns a hash containing all values cached by the object.
This hash may be modified, and in fact must be to cache new values.

=head2 __classify_version

This subroutine takes as its argument a version number, and returns one
of the strings C<'production'>, C<'development'>, or C<'unreleased'>
based on the following convention:

=over

=item unreleased

is returned if the version matches C<m/ \A 0+ [.] 0+ _ [0-8] /smx>;
otherwise

=item development

is returned if the version matches C<m/ _ /smx>; otherwise

=item production

is returned.

=back

If no argument is specified, a list of all three is returned.

=head2 __expand_distribution_path

This subroutine takes as its argument a putative distribution path
relative to the F<authors/id/> directory. If it does not begin with the
two levels of directory that are derived from the author name, these are
added. The expanded path is returned.

=head3 __guess_media_type

 __guess_media_type( $resp, $path );

This subroutine guesses the media type and encoding.

The first argument is an L<HTTP::Response|HTTP::Response> object such as
would have been returned by a successful fetch of the data.

The second argument is optional, and is the URL or path used to fetch
the data. If the second argument is defined, it sets the
C<Content-Location> header in C<$resp>.  If C<$path> is not defined, it
defaults to C<< $resp->header( 'Content-Location' ) >>, and an exception
is thrown if there is none.

The method loads the C<Content-Type> and C<Content-Encoding> headers of
the C<$resp> object with its best guess at what they are. Nothing is
returned.

Note that the arguments are reversed from
C<LWP::MediaTypes::guess_media_type()>.

=head2 __load

This subroutine takes as its arguments one or more module names, and
loads them.

=head2 __whinge

This subroutine loads L<Carp|Carp>, and then passes its arguments to
C<carp()>.

=head2 __wail

This subroutine loads L<Carp|Carp>, and then passes its arguments to
C<croak()>.

=head2 __weep

This subroutine loads L<Carp|Carp>, and then passes its arguments to
C<confess()>, prefixed by the text C<'Programming Error - '>.

=head1 MANIFEST CONSTANTS

The following manifest constants are exportable:

=head2 ARRAY_REF

This manifest constant is simply C<'ARRAY'>.

=head2 CODE_REF

This manifest constant is simply C<'CODE'>.

=head2 HASH_REF

This manifest constant is simply C<'HASH'>.

=head2 REGEXP_REF

This manifest constant is simply C<'Regexp'>.

=head2 SCALAR_REF

This manifest constant is simply C<'SCALAR'>.

=head1 EXPORT TAGS

=head2 :all

This tag exports everything exportable

=head2 :carp

This tag exports L<__whinge|/__whinge>, L<__wail|/__wail>, and
L<__weep|/__weep>.

=head2 :ref

This tag exports all the reference manifest constants; that is, those
ending in C<'_REF'>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc>,
L<https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues>, or in
electronic mail to the author.

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
