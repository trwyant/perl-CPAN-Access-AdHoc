package CPAN::Access::AdHoc::Archive;

use 5.008;

use strict;
use warnings;

use CPAN::Access::AdHoc::Util qw{
    __attr __expand_distribution_path __guess_media_type :carp
};
use CPAN::Meta ();
use HTTP::Response ();
use Module::Pluggable::Object;

our $VERSION = '0.000_06';

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

sub guess_media_type {
    my ( $class, $resp, $path ) = @_;

    __whinge( join ' ',
	'CPAN::Access::AdHoc::Archive::guess_media_type() is',
	'deprecated in favor of',
	'CPAN::Access::AdHoc::Util::__guess_media_type()'
    );

    __guess_media_type( $resp, $path );

    return;
}

{
    my @archivers = Module::Pluggable::Object->new(
	search_path	=> 'CPAN::Access::AdHoc::Archive',
	inner	=> 0,
	require	=> 1,
    )->plugins();

    sub handle_http_response {
	__whinge( join ' ',
	    'handle_http_response() is deprecated in favor of',
	    '__handle_http_response()',
	);
	goto &__handle_http_response;
    }

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

sub list_items {
    __weep( 'The list_items() method must be overridden' );
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
    my ( $self, $fn, $author_dir ) = @_;
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
    if ( defined $author_dir ) {
	my $author_path = __expand_distribution_path( $author_dir );
	$author_path =~ s{ / \z }{}smx;
	$path = join '/', 'authors/id', $author_path,
	    ( File::Spec->splitpath( $fn ) )[2];
    } else {
	my ( $dev, $dir, $base ) = File::Spec->splitpath( $fn );
	my @dirs = grep { $_ ne '' } File::Spec->splitdir( $dir );
	@dirs
	    or @dirs = grep { $_ ne '' } Cwd::cwd();
	if ( @dirs ) {
	    $path = join '/', 'authors/id', __expand_distribution_path(
		"$dirs[-1]/$base" );
	} else {
	    $path = $fn;
	}
    }
    my $resp = HTTP::Response->new( 200, 'OK', undef, $content );
    __guess_media_type( $resp, $path );
    return $self->__handle_http_response( $resp );
}

1;

__END__

=head1 NAME

CPAN::Access::AdHoc::Archive - Common archive functionality for CPAN::Access::AdHoc

=head1 SYNOPSIS

This class is not intended to be used directly.

=head1 NOTICE

Effective with version 0.000_06:

* Static method C<__guess_media_type()> is deprecated. The code has been
moved to C<CPAN::Access::AdHoc::Util> as subroutine
C<__guess_media_type()>, which is private to the C<CPAN-Access-AdHoc>
package.

* Static method C<handle_http_response()> is deprecated. The code has
been renamed to C<__handle_http_response()>, and is considered private
to the C<CPAN-Access-AdHoc> package.

Because the deprecated methods have never been in a production release,
they will be removed a week after the publication of version 0.000_06.

I have never been real happy about exposing these in the public
interface, and with the writing of
C<< CPAN::Access::AdHoc::Archive->wrap_archive() >>, the need to expose
them appears to me to have gone away.

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
actually contains the CPAN distribution. This attribute is read-only, so
it is an error to pass an argument.

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

=head3 guess_media_type

 CPAN::Access::AdHoc::Archive->guess_media_type( $resp, $path );

This static method is deprecated. It is a wrapper for
C<CPAN::Access::AdHoc::__guess_media_type()>.

Because this method has never appeared in a production release, it will
be removed a week after the next release, which will be a development
release.

=head3 handle_http_response

This static method is deprecated in favor of __handle_http_response().

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
those loaded by C<LWP::MediaTypes::guess_media_type()>.

For this class (i.e. C<CPAN::Access::AdHoc::Archive>), the method simply
calls C<__handle_http_response()> on all the
C<CPAN::Access::AdHoc::Archive::*> classes until one chooses to handle
the L<HTTP::Response|HTTP::Response> object by returning a
C<CPAN::Access::AdHoc::Archive> object. If none of the subclasses
handles the L<HTTP::Response|HTTP::Response> object, nothing is
returned.

The whole C<guess_media_type()>/C<__handle_http_response()> thing seems
like a crock to me, but I have not been able to think of anything
better. If they make it into a production release, they B<will> go
through a deprecation cycle.

=head3 item_present

 $arc->item_present( 'Build.PL' )
   and say 'Archive buildable with Module::Build';

This method returns a true value if the named item is present in the
archive, and a false value otherwise. The name of the item is specified
relative to C<< $self->base_directory() >>.

=head3 list_items

This method lists the items in the distribution. Only files are listed.

=head3 metadata

This method returns the distribution's metadata as a
L<CPAN::Meta|CPAN::Meta> object. The return of this method is the
decoding of the distribution's F<META.json> or F<META.yml> files, taken
in that order. If neither is present, or neither contains valid metadata
as determined by L<CPAN::Meta|CPAN::Meta>, nothing is returned -- this
method makes no further effort to establish what the metadata are.

=head2 wrap_archive

 my $archive = CPAN::Access::AdHoc::Archive->wrap_archive(
     'foo/MyDistrib-0.001.tar.gz', 'MYCPANID' );

This method (either normal or static) makes a
C<CPAN::Access::AdHoc::Archive> object out of a local file, and returns
it. The second argument is the CPAN ID to assign to the archive. If this
is omitted the directory the file is in will provide the CPAN ID, which
is probably not what you want.

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
