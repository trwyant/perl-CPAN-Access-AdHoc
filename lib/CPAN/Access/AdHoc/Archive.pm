package CPAN::Access::AdHoc::Archive;

use 5.008;

use strict;
use warnings;

our $VERSION = '0.000_03';

my $_attr = sub {
    my ( $self ) = @_;
    return ( $self->{+__PACKAGE__} ||= {} );
};

my $_wail = sub {
    require Carp;
    Carp::croak( @_ );
};

my $_wallow = sub {
    require Carp;
    Carp::confess( 'Programming error - ', @_ );
};

my $_whinge = sub {
    require Carp;
    Carp::carp( @_ );
    return;
};

# Note that this can be called as a mutator, but the mutator
# functionality is private to the invocant's class.
sub archive {
    my ( $self, @value ) = @_;
    my $attr = $_attr->( $self );
    if ( @value ) {
	caller eq ref $self
	    or $_wail->( 'Attribute archive is read-only' );
	$attr->{archive} = $value[0];
	return $self;
    } else {
	return $attr->{archive};
    }
}

sub base_directory {
    $_wallow->( 'The base_directory() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub extract {
    $_wallow->( 'The extract() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub get_item_content {
    $_wallow->( 'The get_item_content() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub get_item_mtime {
    $_wallow->( 'The get_item_mtime() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub handle_http_response {
    $_wallow->( 'The handle() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub item_present {
    $_wallow->( 'The item_present() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
}

sub list_items {
    $_wallow->( 'The list_items() method must be overridden' );
    return;	# We can't get here, but Perl::Critic does not know this
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
	    $_whinge->( "CPAN::Meta->$method() failed: $@" );
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
    my $attr = $_attr->( $self );
    if ( @value ) {
	caller eq ref $self
	    or $_wail->( 'Attribute path is read-only' );
	$attr->{path} = $value[0];
	return $self;
    } else {
	return $attr->{path};
    }
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
content is unsupported.

=item encoding

This is the MIME encoding of the content. It is ignored if the content
is not present. Subclasses are expected to support encodings C<'gzip'>
and C<'x-bzip2'>.

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

=head3 handle_http_response

This static method takes as its argument an
L<HTTP::Response|HTTP::Response> object. If this method determines that
it can handle the response object, it does so, returning the
C<CPAN::Access::AdHoc::Archive> object derived from the content of the
L<HTTP::Response|HTTP::Response> object.  Otherwise, it simply returns.

The method can do anything it wants to evaluate its argument, but
typically it examines the C<Content-Type>, C<Content-Encoding>, and
C<Content-Location> headers.

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
