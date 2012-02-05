package CPAN::Access::AdHoc::Archive::Zip;

use 5.008;

use strict;
use warnings;

use base qw{ CPAN::Access::AdHoc::Archive };

use Archive::Zip;
use CPAN::Access::AdHoc::Util qw{ :carp __guess_media_type };
use File::Spec::Unix ();
use IO::File ();

our $VERSION = '0.000_11';

{

    my %decode;

    sub new {
	my ( $class, %arg ) = @_;

	my $self = bless {}, ref $class || $class;

	my $archive = Archive::Zip->new();

	$self->archive( $archive );

	if ( defined( my $content = delete $arg{content} ) ) {

	    if ( my $encoding = delete $arg{encoding} ) {
		$decode{$encoding}
		    or __wail( "Unsupported encoding '$encoding'" );
		$content = $decode{$encoding}->( $content );
	    } elsif ( ref $content ) {
		$content = IO::File->new( $content, '<' )
		    or __wail( "Unable to open string reference: $!" );
	    }

	    my $status = $archive->read( $content );
	    $status == Archive::Zip::AZ_OK()
		or __wail( "Zip read error" );

	    ref $content
		or defined $arg{path}
		or $arg{path} = $content;

	}

	$self->path( delete $arg{path} );

	return $self;
    }
}

sub base_directory {
    my ( $self ) = @_;

    my @rslt = sort { length $a <=> length $b || $a cmp $b }
	map { $_->fileName() }
	grep { $_->isDirectory() }
	$self->archive()->members();

    if ( ! @rslt ) {
	@rslt = sort { length $a <=> length $b || $a cmp $b }
	map { ( File::Spec::Unix->splitpath( $_->fileName() ) )[1] }
	$self->archive->members();
    }

    my $base = $rslt[0];
    defined $base
	and '' ne $base
	and $base !~ m{ / \z }smx
	and $base .= '/';

    return $base;
}

sub extract {
    my ( $self ) = @_;

    $self->archive()->extractTree();

    return $self;
}

sub get_item_content {
    my ( $self, $file ) = @_;
    $file = $self->base_directory() . $file;
    my $member = $self->archive()->memberNamed( $file )
	or return;
    return scalar $member->contents();
}

sub get_item_mtime {
    my ( $self, $file ) = @_;
    $file = $self->base_directory() . $file;
    my $member = $self->archive()->memberNamed( $file )
	or return;
    return scalar $member->lastModTime();
}

{

    my %handled = map { $_ => 1 } qw{ application/zip };

    sub __handle_http_response {
	my ( $class, $rslt ) = @_;

	$handled{ $rslt->header( 'Content-Type' ) }
	    or return;

	return $class->new(
	    content	=> \( scalar $rslt->content() ),
	    encoding	=> scalar $rslt->header( 'Content-Encoding' ),
	    path	=> scalar $rslt->header( 'Content-Location' ),
	);
    }
}

sub item_present {
    my ( $self, $name ) = @_;
    $name = $self->base_directory() . $name;
    my $re = qr{ \A \Q$name\E \z }smx;
    return scalar $self->archive()->membersMatching( $re );
}

sub list_contents {
    my ( $self ) = @_;

    my $base = $self->base_directory();
    $base = qr{ \A \Q$base\E }smx;

    my @rslt;
    foreach my $file ( $self->archive()->members() ) {
	$file->isDirectory()
	    and next;
	my $name = $file->fileName();
	$name =~ s/ $base //smx
	    or next;
	push @rslt, $name;
    }

    return @rslt;
}

{
    my %known_encoding = (
    );

    sub write : method {	## no critic (ProhibitBuiltInHomonyms)
	my ( $self, $fn ) = @_;
	if ( ! defined $fn ) {
	    $fn = ( File::Spec->splitpath( $self->path() ) )[2];
	}
	my $resp = HTTP::Response->new();
	__guess_media_type( $resp, $fn );
	my $encoding = $resp->header( 'Content-Encoding' );
	defined $encoding
	    or $encoding = '';
	if ( defined $encoding && '' ne $encoding ) {
	    __wail( "Encoding $encoding not supported" );
	}
	my $status = $self->archive()->writeToFileNamed( $fn );
	$status == Archive::Zip::AZ_OK()
	    or __wail( 'Zip write error' );
	return $self;
    }
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Archive::Zip - Provide a consistent interface to Archive::Zip

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Archive::Zip;
 use LWP::UserAgent;
 
 my $ua = LWP::UserAgent->new();
 my $resp = $ua->get( ... );
 my $tar = CPAN::Access::AdHoc::Archive::Zip->new(
     content => \( $resp->content() ),
     encoding => $resp->header( 'Content-Encoding' ),
 );

=head1 DESCRIPTION

This class is a subclass of
L<Archive::Zip::Archive|Archive::Zip::Archive>, provided for the
convenience of L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the
C<CPAN-Access-AdHoc> package.

=head1 METHODS

This class supports the following public methods over and above those
supported by its superclass, or with functionality over and above that
of the superclass.

=head2 new

This override of the superclass' C<new()> method instantiates the
object, and possibly loads it.  There are two supported arguments:

=over

=item content

This is the content to be loaded into the object. A scalar reference is
assumed to be the literal content. A non-reference is assumed to be the
file name. Any other value is unsupported.

However specified, the value must represent a valid zip file.

=item encoding

This is the MIME encoding of the content. It is ignored if the content
is not present. Since the zip format implies its own encoding, this
argument may only be specified as C<undef>.

=back

=head2 get_item_content

This method returns the content of the named item in the archive. It is
simply a wrapper for C<< Archive::Zip->memberNamed()->contents() >>.

=head2 get_item_mtime

Unfortunately, Zip file entry time stamps are in local time, and there
is no zone information included. This means that unless this is called
in the same time zone in which the Zip entry was created you get the
wrong time. In other words, the results of this method are useless.

=head2 list_contents

This method lists the contents of the archive. It is simply a wrapper
for C<< Archive::Zip->memberNames() >>.

=head1 SEE ALSO

The parent class, L<Archive::Zip|Archive::Zip>.


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
