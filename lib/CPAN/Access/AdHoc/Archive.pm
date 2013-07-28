package CPAN::Access::AdHoc::Archive;

use 5.008;

use strict;
use warnings;

use Cwd ();
use CPAN::Access::AdHoc::Util qw{
    __attr __expand_distribution_path __guess_media_type :carp
};
use CPAN::Meta ();
use HTTP::Response ();
use Module::Pluggable::Object;
use URI::file;

our $VERSION = '0.000_18';

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
    __weep( 'The extract() method must be overridden' );
}

sub get_item_content {
    __weep( 'The get_item_content() method must be overridden' );
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
	my ( $class, $resp ) = @_;

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
	    or __wail( 'Attribute archive is read-only' );
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
	return $self;
    } else {
	return $attr->{path};
    }
}

sub wrap_archive {
    my ( $class, @args ) = @_;
    my $opt = 'HASH' eq ref $args[0] ? shift @args : {};
    my ( $fn ) = @args;
    -f $fn
	or __wail( "File $fn not found" );
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

=head1 NOTICE

Effective with version 0.000_12:

Method C<wrap_archive()> takes an optional leading hash. You can use
either key C<{author}> to specify the CPAN author ID for the archive, or
key C<{directory}> to specify its archive relative to the CPAN root. The
argument after the file name is deprecated, and will be removed a week
after the publication of 0.000_12.

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

=head2 Other methods

These are either convenience methods or methods that provide a
consistent interface to the underlying archive object.

=head3 base_directory

This method returns the natural base directory of the distribution, as
computed from the directories contained in the distribution.

=head3 extract

This method extracts the contents of the archive to files. It simply
wraps whatever the extraction method is for the underlying archiver.

=head3 get_item_content

 print "README:\n", $arc->get_item_content( 'README' );

This method returns the content of the named item in the archive. The
name of the item is specified relative to C<< $arc->base_directory() >>.

=head3 get_item_mtime

 use POSIX qw{ strftime };
 print 'README modified ', strftime(
     '%d-%b-%Y %H:%M:%S',
      $arc->get_item_mtime( 'README' ) ), "\n";

This method returns the modification time of the named item in the
archive. The name of the item is specified relative to
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
