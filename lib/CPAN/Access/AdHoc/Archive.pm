package CPAN::Access::AdHoc::Archive;

use 5.010;

use strict;
use warnings;

use Cwd ();
use CPAN::Access::AdHoc::Util qw{
    __attr __expand_distribution_path __is_text __guess_media_type
    :carp SCALAR_REF
};
use CPAN::Meta ();
use Encode ();
use Encode::Guess;
use ExtUtils::MakeMaker;
use File::chdir;
use File::Spec;
use HTTP::Date ();
use HTTP::Response ();
use Module::Metadata;
use Module::Pluggable::Object;
use URI::file;

our $VERSION = '0.000_234';

# Note that this can be called as a mutator, but the mutator
# functionality is private to the invocant's class.
sub archive {
    my ( $self, @value ) = @_;
    my $attr = $self->__attr();

    if ( @value ) {
	caller eq ref $self
	    or __wail( 'Attribute archive is read-only' );
	$attr->{archive} = $value[0];
	return $self;
    } else {
	return $attr->{archive};
    }
}

sub base_directory {
    __weep( 'The base_directory() method must be overridden' );
}

sub extract {
    my ( $self, $target ) = @_;
    defined $target
	and local $CWD = $target;
    $self->__extract();
    return $self;
}

sub __extract {
    __weep( 'The extract() method must be overridden' );
}

sub get_item_content {
    __weep( 'The get_item_content() method must be overridden' );
}

sub get_item_content_decoded {
    my ( $self, $file ) = @_;
    my $content = $self->get_item_content( $file );
    __is_text( $content )
	or return ( undef, $content );
    my $enc = Encode::Guess::guess_encoding( $content, 'iso-latin-1' );
    ref $enc
	or return ( undef, $content );
    return ( $enc, Encode::decode( $enc, $content ) );
}

sub get_item_mtime {
    __weep( 'The get_item_mtime() method must be overridden' );
}

{
    my @archivers = Module::Pluggable::Object->new(
	search_path	=> 'CPAN::Access::AdHoc::Archive',
	inner	=> 0,
	require	=> 1,
    )->plugins();

    sub __handle_http_response {
	my ( undef, $resp ) = @_;	# Invocant is not used.

	foreach my $archiver ( @archivers ) {
	    my $archive;
	    defined( $archive = $archiver->__handle_http_response( $resp ) )
		and return $archive;
	}

	return;
    }
}

sub item_present {
    __weep( 'The item_present() method must be overridden' );
}

sub list_contents {
    __weep( 'The list_contents() method must be overridden' );
}

sub metadata {
    my ( $self ) = @_;

    foreach my $spec (
	[ load_json_string	=> 'META.json' ],
	[ load_yaml_string	=> 'META.yml' ],
    ) {
	my ( $method, $file ) = @{ $spec };
	$self->item_present( $file )
	    or next;
	my $meta;
	eval {
	    $meta = CPAN::Meta->$method(
		$self->get_item_content( $file ) );
	} or do {
	    __whinge( "CPAN::Meta->$method() failed: $@" );
	    next;
	};
	return $meta;

    }

    return;

}

# Note that this can be called as a mutator, but the mutator
# functionality is private to the invocant's class.
sub mtime {
    my ( $self, @value ) = @_;
    my $attr = $self->__attr();

    if ( @value ) {
	caller eq ref $self
	    or __wail( 'Attribute mtime is read-only' );
	$attr->{mtime} = $value[0];
	return $self;
    } else {
	return $attr->{mtime};
    }
}

# Note that this can be called as a mutator, but the mutator
# functionality is private to the invocant's class.
sub path {
    my ( $self, @value ) = @_;
    my $attr = $self->__attr();

    if ( @value ) {
	caller eq ref $self
	    or __wail( 'Attribute path is read-only' );
	$attr->{path} = $value[0];
	delete $attr->{size};
	return $self;
    } else {
	return $attr->{path};
    }
}

# Note that the ExtUtils::MakeMaker version of the metadata does not
# have 'provides' metadata, so we have to generate it.
sub provides {
    my ( $self ) = @_;
    my $meta = $self->metadata();
    my $provides;
    $provides = $meta->provides()
	and keys %{ $provides }
	and return $provides;

    # The Module::Metadata docs say not to use
    # package_versions_from_directory() directly, but the 'files =>'
    # version of provides() is broken, and has been known to be so since
    # 2014, so it's not getting fixed any time soon. So:

    {
	my @files = grep { m/ [.] pm \z /smx } $self->list_contents();

	# Unfortunately Module::Metadata requires a real directory, so
	# we have to provide one. Sigh.
	my $td_obj = File::Temp->newdir();
	my $td_name = $td_obj->dirname();
	$self->extract( $td_name );
	local $CWD = File::Spec->catdir( $td_name, join '-',
	    $meta->name(), $meta->version () );
	$provides = Module::Metadata->package_versions_from_directory(
	    undef,
	    \@files,
	);
    }

    foreach my $pkg ( keys %{ $provides } ) {
	$meta->should_index_package( $pkg )
	    and $meta->should_index_file(
		$provides->{$pkg}{file} )
	    and next;
	delete $provides->{$pkg};
    }
    return $provides;
}

sub __set_archive_mtime {
    my ( $self, $fn ) = @_;
    if ( defined( my $mtime = $self->mtime() ) ) {
	utime $mtime, $mtime, $fn
	    or __whinge( "Failed to set modification time on $fn: $!" );
    }
    return;
}

# Note that this can be called as a mutator, but the mutator
# functionality is private to the invocant's class.
sub size {
    my ( $self, @value ) = @_;
    my $attr = $self->__attr();

    if ( @value ) {
	caller eq ref $self
	    or __wail( 'Attribute path is read-only' );
	$attr->{size} = $value[0];
	return $self;
    } else {
	return $attr->{size} //= $self->__size_of_archive();
    }
}

sub __size_of_archive {
    my ( $self ) = @_;
    return -s $self->path();
};

=begin comment

# This appears to be unused.

sub __change_to_target_dir {
    my ( undef, $target ) = @_;	# Invocant unused
    defined $target
	or return $target;
    return CPAN::Access::AdHoc::chdir->new( $target );
}

=end comment

=cut

sub wrap_archive {
    my ( $class, @args ) = @_;
    my $opt = 'HASH' eq ref $args[0] ? shift @args : {};
    my ( $fn ) = @args;
    -f $fn
	or __wail( "File $fn not found" );
    my @stat = stat _;
    my $size = $stat[7];
    my $mtime = $stat[9];
    my $content;
    {
	local $/ = undef;
	open my $fh, '<', $fn or __wail( "Unable to open $fn: $!" );
	binmode $fh;
	$content = <$fh>;
	close $fh;
    }
    my $path;
    if ( defined $opt->{directory} ) {
	defined $opt->{author}
	    and __wail(
	    q{Specifying both 'author' and 'directory' is ambiguous} );
	$path = $opt->{directory};
	$path =~ s{ (?<! / ) \z }{/}smx;
	$path .= ( File::Spec->splitpath( $fn ) )[2];
    } elsif ( defined $opt->{author} ) {
	my $author_path = __expand_distribution_path( $opt->{author} );
	$author_path =~ s{ / \z }{}smx;
	$path = join '/', 'authors/id', $author_path,
	    ( File::Spec->splitpath( $fn ) )[2];
    } else {
	my $uri = URI::file->new( Cwd::abs_path( $fn ) );
	$path = $uri->as_string();
	$path =~ s{ \A .* / (?= authors/ | modules/ ) }{}smx
	    or do {
	    my @parts = File::Spec->splitpath( $uri->file() );
	    my @dir = File::Spec->splitdir( $parts[1] );
	    $dir[-1] eq ''
		and pop @dir;
	    my $author_path = __expand_distribution_path( $dir[-1] );
	    $author_path =~ s{ / \z }{}smx;
	    $path = join '/', 'authors/id', $author_path, $parts[2];
	};
    }
    my $resp = HTTP::Response->new( 200, 'OK', undef, $content );
    __guess_media_type( $resp, $path );
    defined $mtime
	and $resp->header( 'Last-Modified' => HTTP::Date::time2str(
	    $mtime ) );
    defined $size
	and $resp->header( 'Content-Length' => $size );
    return $class->__handle_http_response( $resp );
}

sub write : method {	## no critic (ProhibitBuiltInHomonyms)
    __weep( 'The write() method must be overridden' );
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Archive - Common archive functionality for CPAN::Access::AdHoc

=head1 SYNOPSIS

This class is not intended to be used directly.

=head1 DESCRIPTION

This class provides common functionality needed by the accessors for the
various archive formats that are found in CPAN.

=head1 METHODS

This class supports the following public methods:

=head2 Instantiator

=head3 new

 my $arc = CPAN::Access::AdHoc::Archive->new(
     content => \$content,
     encoding => 'gzip',
 );

This static method instantiates the object. It is actually implemented
on the subclasses, and may not be called on this class. In use, it is
expected that the user will not call this method directly, but get the
archive objects from L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>'s
L<fetch_distribution_archive()|CPAN::Access::AdHoc/fetch_distribution_archive> method. See
that method's documentation for how it initialized this object.

This method takes arguments as name/value pairs. The following are
supported:

=over

=item content

This is the content to be loaded into the object. A scalar reference is
assumed to be the literal content. A non-reference is assumed to be the
file name. Any other value is unsupported.

Passing content to a subclass that is not designed to support that
content is unsupported. That is to say, if you pass the contents of a
C<Zip> file to C<< CPAN::Access::AdHoc::Archive::Tar->new() >>, nothing
good will happen.

=item encoding

This is the MIME encoding of the content. It is ignored if the content
is not present. If the content is not encoded, this argument can be
omitted or passed a value of C<undef>.

Subclasses are expected to support encodings C<'gzip'> and C<'x-bzip2'>.

Again, nothing good will happen if the content is not actually encoded
this way.

=item mtime

This is the modification time of the archive.

=item path

This optional argument is intended to contain the path to the archive.
Subclasses may (but need not) default it to the value of the C<content>
argument, provided the C<content> argument is not a reference.

The intent is that the various components of this distribution should
conspire to make this the path to the file relative to the CPAN URL.

=back

If you do not specify at least C<content>, you get an empty object,
which is of limited usefulness.

=head2 Accessors/Mutators

These methods retrieve or modify the attributes of the class.

=head3 archive

This method is an accessor for the object representing the archive that
actually contains the CPAN distribution.

This attribute is read-only, so it is an error to pass an argument.

=head3 mtime

This method is an accessor for the time the archive was last modified.

This attribute is read-only, so it is an error to pass an argument.

=head3 path

This method is an accessor for the path of the archive.

This attribute is read-only, so it is an error to pass an argument.

=head3 size

This method is an accessor for the size of the archive in bytes.

This attribute is read-only, so it is an error to pass an argument.

=head2 Other methods

These are either convenience methods or methods that provide a
consistent interface to the underlying archive object.

=head3 base_directory

This method returns the natural base directory of the distribution, as
computed from the directories contained in the distribution.

=head3 extract

This method extracts the contents of the archive to files. It simply
wraps whatever the extraction method is for the underlying archiver.

An optional argument specifies the name of the directory to extract
into. If this directory can not be used, an exception is thrown.

=head3 get_item_content

 print "README:\n", $arc->get_item_content( 'README' );

This method returns the content of the named item in the archive. The
name of the item is specified relative to C<< $arc->base_directory() >>.

=head3 get_item_content_decoded

 my ( $encoding, $content ) =
   $src->get_item_content_decoded( 'README' );
 my $content = $src->get_item_content_decoded( 'README' );

Added in version 0.000_234.

This method returns a list containing the encoding object and contents
of the item. If the encoding object is C<undef> the raw contents are
returned.  If called in scalar context just the possibly-decoded
contents are returned.

L<Encode::Guess|Encode::Guess> is used to guess the encoding.

The name of the item is specified relative to
C<< $arc->base_directory() >>.

=head3 get_item_mtime

 use POSIX qw{ strftime };
 print 'README modified ', strftime(
     '%d-%b-%Y %H:%M:%S',
      $arc->get_item_mtime( 'README' ) ), "\n";

This method returns the modification time of the named item in the
archive. The name of the item is specified relative to
C<< $arc->base_directory() >>.

=head3 get_item_size

 printf "README size %d bytes\n",
     $arc->get_item_size( 'README' );

This method returns the uncompressed size in bytes of the named item in
the archive. The name of the item is specified relative to
C<< $arc->base_directory() >>.

=head3 __handle_http_response

This static method is private to the C<CPAN-Access-AdHoc> package.

This method takes as its argument an L<HTTP::Response|HTTP::Response>
object. If this method determines that it can handle the response
object, it does so, returning the C<CPAN::Access::AdHoc::Archive> object
derived from the content of the L<HTTP::Response|HTTP::Response> object.
Otherwise, it simply returns.

The method can do anything it wants to evaluate its argument, but
typically it examines the C<Content-Type>, C<Content-Encoding>, and
C<Content-Location> headers. The expected values of these headers are
those loaded by C<CPAN::Access::AdHoc::Util::__guess_media_type()>.

For this class (i.e. C<CPAN::Access::AdHoc::Archive>), the method simply
calls C<__handle_http_response()> on all the
C<CPAN::Access::AdHoc::Archive::*> classes until one chooses to handle
the L<HTTP::Response|HTTP::Response> object by returning a
C<CPAN::Access::AdHoc::Archive> object. If none of the subclasses
handles the L<HTTP::Response|HTTP::Response> object, nothing is
returned.

=head3 item_present

 $arc->item_present( 'Build.PL' )
   and say 'Archive buildable with Module::Build';

This method returns a true value if the named item is present in the
archive, and a false value otherwise. The name of the item is specified
relative to C<< $self->base_directory() >>.

=head3 list_contents

This method lists the items in the distribution. Only files are listed.

=head3 metadata

This method returns the distribution's metadata as a
L<CPAN::Meta|CPAN::Meta> object. The return of this method is the
decoding of the distribution's F<META.json> or F<META.yml> files, taken
in that order. If neither is present, or neither contains valid metadata
as determined by L<CPAN::Meta|CPAN::Meta>, nothing is returned -- this
method makes no further effort to establish what the metadata are.

=head3 provides

This method returns the names of all modules provided by this
distribution. It comes from the corresponding metadata item if that
exists; otherwise we try to generate it ourselves.

=head3 __set_archive_mtime

  $self->__set_archive_mtime( $file_name );

This method is private to the C<CPAN-Access-AdHoc> package.

This method sets the access and modification time of the given file to
the value of $self->mtime(), provided that is defined. It returns
nothing.

This method is intended for the use of subclass' write() methods, and is
not intended to be called by the user of this package.

=head3 wrap_archive

 my $archive = CPAN::Access::AdHoc::Archive->wrap_archive(
     { author => 'MYCPANID' },
     'foo/MyDistrib-0.001.tar.gz' );

This method (either normal or static) makes a
C<CPAN::Access::AdHoc::Archive> object out of a local file, and returns
it.

The leading hash before the file name is optional, and specifies the
path to the item in a CPAN archive. This is combined with the base name
of the file and the result is used to populate the C<path> attribute of
the archive.  Possible keys are

 author => the CPAN author ID for the archive;
 directory => The directory relative to the CPAN archive root.

You may not specify both C<author> and C<directory>, since this is
ambiguous.

If no option hash is specified, or neither C<author> nor C<directory> is
specified in it, the full path name will be made into a C<file:> URL,
and any prefix before C</authors/> or C</modules/> is removed; if these
are not found, the full path name of the file is used.

=head3 write

 $archive->write( $file_name );
 $archive->write();

This method writes the contents of the archive to the given file name.
If the name indicates that the file should be encoded and the archiver
supports that encoding, the encoding is applied. For example, a Tar
archive written to a file whose name ends in F<.gz> will be compressed
with gzip.

If the file name is omitted, it defaults to the base name of
C<< $archive->path() >>.

The access and modification time of the output file will be set to
C<< $self->mtime() >> provided the latter is not C<undef>.

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
