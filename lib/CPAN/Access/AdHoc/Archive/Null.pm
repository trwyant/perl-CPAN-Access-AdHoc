package CPAN::Access::AdHoc::Archive::Null;

use 5.008;

use strict;
use warnings;

use base qw{ CPAN::Access::AdHoc::Archive };

use CPAN::Access::AdHoc::Util qw{ :carp __guess_media_type };
use File::Path 2.07 ();
use File::Spec ();
use HTTP::Date ();
use IO::File ();
use IO::Uncompress::Bunzip2 ();
use IO::Uncompress::Gunzip ();

our $VERSION = '0.000_18';

my %decode = (
    gzip	=> sub {
	my ( $content ) = @_;
	my $rslt;
	IO::Uncompress::Gunzip::gunzip( $content, \$rslt );
	return $rslt;
    },
    'x-bzip2'	=> sub {
	my ( $content ) = @_;
	my $rslt;
	IO::Uncompress::Bunzip2::bunzip2( $content, \$rslt );
	return $rslt;
    },
);


sub new {
    my ( $class, %arg ) = @_;

    my $self = bless {}, ref $class || $class;
    my $attr = $self->__attr();

    ref $arg{content}
	or defined $arg{path}
	or $arg{path} = $arg{content};

    my $mtime = delete $arg{mtime};

    if ( defined( my $content = delete $arg{content} ) ) {

	if ( my $encoding = delete $arg{encoding} ) {
	    $decode{$encoding}
		or __wail( "Unsupported encoding '$encoding'" );
	    $content = $decode{$encoding}->( $content );
	} elsif ( ! ref $content ) {
	    local $/ = undef;	# Slurp mode
	    open my $fh, '<', $content
		or __wail( "Unable to open $content: $!" );
	    my @stat = stat $fh;
	    $content = <$fh>;
	    close $fh;
	    @stat
		and $mtime = $stat[9];
	} elsif ( 'SCALAR' eq ref $content ) {
	    $content = ${ $content };
	}

	my ( $base_dir, $file_name );
	if ( $arg{path} ) {
	    ( undef, $base_dir, $file_name ) =
		File::Spec->splitpath( $arg{path} );
	    $base_dir =~ s{ \A authors/id/
		([^/]) / ( \1 [^/] ) / \2 [^/]* / }{}smx;
	    $file_name =~ s/ [.] (?: gz | bz2 ) \z //smx;
	} else {
	    ( $base_dir, $file_name ) = ( '', 'unknown' );
	}

	$attr->{base_dir} = $base_dir;
	$attr->{contents}{$file_name} = {
	    content	=> $content,
	    mtime	=> $mtime,
	};

	$self->archive( undef );

    }

    $self->mtime( $mtime );
    $self->path( delete $arg{path} );

    return $self;
}

sub base_directory {
    my ( $self ) = @_;
    my $attr = $self->__attr();

    return $attr->{base_dir};
}

sub extract {
    my ( $self ) = @_;
    my $attr = $self->__attr();

    my @dirs = grep { defined $_ and '' ne $_ } File::Spec->splitdir(
	$self->base_directory() );
    my $where;
    foreach my $dir ( @dirs ) {
	$where = defined $where ? File::Spec->catdir( $where, $dir ) :
	$dir;
	-d $where
	    or mkdir $where
	    or __wail( "Unable to mkdir $where: $!" );
    }

    foreach my $name ( keys %{ $attr->{contents} } ) {
	my $path = File::Spec->catfile( $where, $name );
	my $fh = IO::File->new( $path, '>' )
	    or __wail( "Unable to open $path for output: $!" );
	print { $fh } $attr->{contents}{$name}{content};
	close $fh;
	my $mtime = $attr->{contents}{$name}{mtime};
	utime $mtime, $mtime, $path;
    }

    return $self;
}

sub get_item_content {
    my ( $self, $file ) = @_;
    my $attr = $self->__attr();

    defined $file
	or ( $file ) = keys %{ $attr->{contents} };

    return $attr->{contents}{$file}{content};
}

sub get_item_mtime {
    my ( $self, $file ) = @_;
    my $attr = $self->__attr();

    defined $file
	or ( $file ) = keys %{ $attr->{contents} };

    return $attr->{contents}{$file}{mtime};
}

{

    my %handled = map { $_ => 1 } qw{ application/octet-stream };

    sub __handle_http_response {
	my ( $class, $rslt ) = @_;

	my $content_type = $rslt->header( 'Content-Type' );

	$handled{ $content_type }
	    or $content_type =~ m{ \A text/ }smx
	    or return;

	return $class->new(
	    content	=> \( scalar $rslt->content() ),
	    encoding	=> scalar $rslt->header( 'Content-Encoding' ),
	    mtime	=> HTTP::Date::str2time(
		scalar $rslt->header( 'Last-Modified' ) ),
	    path	=> scalar $rslt->header( 'Content-Location' ),
	);
    }

}

sub item_present {
    my ( $self, $item ) = @_;
    my $attr = $self->__attr();

    return defined $attr->{contents}{$item};
}

sub list_contents {
    my ( $self ) = @_;
    my $attr = $self->__attr();

    return ( sort keys %{ $attr->{contents} } );
}

{
    my %known_encoding = (
	# The null encoder does a binmode() on its file handle because I
	# believe that is equivalent to what happens with the
	# IO::Compress::* packages - i.e. they compress bytes, not
	# characters.
	''		=> sub {
	    my ( $fn, $content ) = @_;
	    open my $fh, '>', $fn or __wail( "Open $fn failed: $!" );
	    binmode $fh;
	    print { $fh } $content;
	    close $fh;
	    return;
	},
	'gzip'		=> sub {
	    my ( $fn, $content ) = @_;
	    require IO::Compress::Gzip;
	    IO::Compress::Gzip::gzip( \$content, $fn, AutoClose => 1 )
		or __wail("gzip $fn failed: $IO::Compress::Gzip::GzipError"
	    );
	    return;
	},
	'x-bzip2'	=> sub {
	    my ( $fn, $content ) = @_;
	    require IO::Compress::Bzip2;
	    IO::Compress::Bzip2::bzip2( \$content, $fn )
		or __wail("bzip2 $fn failed: $IO::Compress::Bzip2::Bzip2Error"
	    );
	    return;
	},
    );

    sub write : method {	## no critic (ProhibitBuiltInHomonyms)
	my ( $self, $fn ) = @_;
	my $attr = $self->__attr();

	my ( $file ) = keys %{ $attr->{contents} };
	if ( ! defined $fn ) {
	    $fn = ( File::Spec->splitpath( $self->path() ) )[2];
	}
	my $resp = HTTP::Response->new();
	__guess_media_type( $resp, $fn );
	my $encoding = $resp->header( 'Content-Encoding' );
	defined $encoding
	    or $encoding = '';
	my $code = $known_encoding{$encoding}
	    or __wail( "Encoding $encoding not supported" );
	$code->( $fn, $attr->{contents}{$file}{content} );
	return $self;
    }
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Archive::Null - Archive-like wrapper for un-archived data.

=head1 SYNOPSIS

 use CPAN::Access::AdHoc::Archive::Null;
 use LWP::UserAgent;
 
 my $ua = LWP::UserAgent->new();
 my $resp = $ua->get( ... );
 my $tar = CPAN::Access::AdHoc::Archive::Null->new(
     content => \( $resp->content() ),
     encoding => $resp->header( 'Content-Encoding' ),
 );

=head1 DESCRIPTION

This class wraps an un-archived file or text block, providing a
C<CPAN::Access::AdHoc::Archive>-compliant interface. It is private to the
C<CPAN-Access-AdHoc> package.

=head1 METHODS

This class supports the following public methods:

=head2 new

This static method instantiates the object, and possibly loads it. The
supported arguments are:

=over

=item content

This is the content to be loaded into the object. A scalar reference is
assumed to be the literal content. A non-reference is assumed to be the
file name. Any other value is unsupported.

If this argument is a scalar reference, the file name is set to
'unknown', and the contents are accessed under that name.

=item encoding

This is the MIME encoding of the content. It is ignored if the content
is not present.

=item mtime

This is the modification time of the content. If the content is not a
reference, it is taken as a file name, so this argument is ignored and
the modification time of the file is used instead.

=item path

This is intended to be a path to the content. If not specified, and the
content argument is a file name (i.e. not a reference), this defaults to
the content argument.

=back

=head2 base_directory

Because there is no real distribution inside this wrapper, we have no
real place to get a base directory. So we have to invent one.

For files that appear to be single-file unpackaged distributions (that
is, with paths like
F<authors/id/T/TO/TOMC/scripts/whenon.dir/LastLog/File.pm.gz>), the base
directory is taken to be the directory portion of the path which is to
the right of the author directory; that is,
F<scripts/whenon.dir/LastLog/> in the above example.

For other files, the base directory is simply the directory portion of
the file path relative to the base of the CPAN mirror.

=head2 extract

Because there is no real distribution inside this wrapper, we have to do
our own extract functionality.

This simply creates the base directory tree and then extracts the file
into it.

=head2 get_item_content

This method returns the content of the named item in the archive.
Because there can only ever be one file in the pseudo-archive, if the
argument is C<undef>, the content of that file is returned.

=head2 list_contents

This method lists the contents of the archive. It always returns exactly
one name.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
