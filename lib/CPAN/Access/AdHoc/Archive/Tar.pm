package CPAN::Access::AdHoc::Archive::Tar;

use 5.008;

use strict;
use warnings;

use base qw{ CPAN::Access::AdHoc::Archive };

use Archive::Tar ();
use CPAN::Access::AdHoc::Util qw{ :carp __guess_media_type };
use File::Spec::Unix ();
use IO::File ();
use IO::Uncompress::Bunzip2 ();
use IO::Uncompress::Gunzip ();

our $VERSION = '0.000_08';

{

    my %decode = (
	gzip	=> sub {
	    my ( $content ) = @_;
	    return IO::Uncompress::Gunzip->new( $content );
	},
	'x-bzip2'	=> sub {
	    my ( $content ) = @_;
	    return IO::Uncompress::Bunzip2->new( $content );
	},
    );

    sub new {
	my ( $class, %arg ) = @_;

	my $self = bless {}, ref $class || $class;

	my $archive = Archive::Tar->new();

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

	    ref $content
		or defined $arg{path}
		or $arg{path} = $content;

	    $archive->read( $content );

	}

	$self->path( delete $arg{path} );

	return $self;
    }

}

sub base_directory {
    my ( $self ) = @_;

    my @rslt = sort { length $a <=> length $b || $a cmp $b }
	map { _construct_name( $_ ) }
	grep { $_->is_dir() }
	$self->archive()->get_files();

    if ( ! @rslt ) {
	@rslt = sort { length $a <=> length $b || $a cmp $b }
	    map { ( File::Spec::Unix->splitpath( _construct_name( $_ ) ) )[1] }
	    $self->archive()->get_files();
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

    $self->archive()->extract();

    return $self;
}

sub get_item_content {
    my ( $self, $file ) = @_;
    $file = $self->base_directory() . $file;
    return $self->archive()->get_content( $file );
}

sub get_item_mtime {
    my ( $self, $file ) = @_;
    $file = $self->base_directory() . $file;
    my @files = $self->archive()->get_files( $file );
    @files
	and return $files[0]->mtime();
    return;
}

{

    my %handled = map { $_ => 1 } qw{ application/x-tar };

    sub handle_http_response {
	__whinge( join ' ',
	    'handle_http_response() is deprecated in favor of',
	    '__handle_http_response()',
	);
	goto &__handle_http_response;
    }

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
    return $self->archive()->contains_file( $name );
}

sub list_contents {
    my ( $self ) = @_;

    my @rslt;

    my $base = $self->base_directory();
    $base = qr{ \A \Q$base\E }smx;

    foreach my $file ( $self->archive()->get_files() ) {
	$file->is_file()
	    or next;
	my $name = _construct_name( $file );
	$name =~ s/ $base //smx
	    or next;
	push @rslt, $name;
    }

    return @rslt;
}

{
    my %known_encoding = (
	'gzip'		=> Archive::Tar->COMPRESS_GZIP(),
	'x-bzip2'	=> Archive::Tar->COMPRESS_BZIP(),
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
	my @args = ( $fn );
	if ( defined $encoding && '' ne $encoding ) {
	    exists $known_encoding{$encoding}
		or __wail( "Encoding $encoding not supported" );
	    push @args, $known_encoding{$encoding};
	}
	$self->archive()->write( @args );
	return $self;
    }
}

sub _construct_name {
    my ( $file ) = @_;
    my $prefix = $file->prefix();
    if ( defined $prefix && '' ne $prefix ) {
	$prefix =~ m{ / \z }smx
	    or $prefix .= '/';
	return $prefix . $file->name();
    } else {
	return $file->name();
    }
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Archive::Tar - Provide consistent interface to Archive::Tar

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Archive::Tar;
 use LWP::UserAgent;
 
 my $ua = LWP::UserAgent->new();
 my $resp = $ua->get( ... );
 my $tar = CPAN::Access::AdHoc::Archive::Tar->new(
     content => \( $resp->content() ),
     encoding => $resp->header( 'Content-Encoding' ),
 );

=head1 DESCRIPTION

This class is a subclass of L<Archive::Tar|Archive::Tar>, provided for
the convenience of L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the
C<CPAN-Access-AdHoc> package.

=head1 METHODS

This class supports the following public methods over and above those
supported by its superclass:

=head2 new

This override of the superclass' C<new()> method instantiates the
object, and possibly loads it.  There are two supported arguments:

=over

=item content

This is the content to be loaded into the object. A scalar reference is
assumed to be the literal content. A non-reference is assumed to be the
file name. Any other value is unsupported.

However specified, the content must represent a valid tar file.

=item encoding

This is the MIME encoding of the content. It is ignored if the content
is not present. Encodings C<'gzip'> and C<'x-bzip2'> are supported. If
not present, the content is assumed not to be encoded.

=back

=head2 get_item_content

This method returns the content of the named item in the archive. It is
simply a wrapper for C<< Archive::Tar->get_content() >>.

=head2 list_contents

This method lists the contents of the archive. It is simply a wrapper
for C<< Archive::Tar->list_files() >>.

=head1 SEE ALSO

L<Archive::Tar|Archive::Tar>

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
