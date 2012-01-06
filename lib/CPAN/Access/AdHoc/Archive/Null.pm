package CPAN::Access::AdHoc::Archive::Null;

use 5.008;

use strict;
use warnings;

use base qw{ CPAN::Access::AdHoc::Archive };

use File::Path 2.07 ();
use File::Spec ();
use IO::File ();
use IO::Uncompress::Bunzip2 ();
use IO::Uncompress::Gunzip ();

our $VERSION = '0.000_02';

my $_attr = sub {
    my ( $self ) = @_;
    return ( $self->{+__PACKAGE__} ||= {} );
};

my $_wail = sub {
    require Carp;
    Carp::croak( @_ );
};

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
    my $attr = $_attr->( $self );

    if ( defined( my $content = delete $arg{content} ) ) {

	my $file_name = ref $content ? 'unknown' : $content;

	if ( my $encoding = delete $arg{encoding} ) {
	    $decode{$encoding}
		or $_wail->( "Unsupported encoding '$encoding'" );
	    $content = $decode{$encoding}->( $content );
	} elsif ( ! ref $content ) {
	    local $/ = undef;	# Slurp mode
	    open my $fh, '<', $content
		or $_wail->( "Unable to open $content: $!" );
	    $content = <$fh>;
	    close $fh;
	} elsif ( 'SCALAR' eq ref $content ) {
	    $content = ${ $content };
	}

	$attr->{contents}{$file_name} = $content;

	$self->archive( undef );

	ref $content
	    or defined $arg{path}
	    or $arg{path} = $content;

    }

    $self->path( delete $arg{path} );

    return $self;
}

sub base_directory {
    return '';
}

sub extract {
    my ( $self ) = @_;
    my $attr = $_attr->( $self );

    foreach my $name ( keys %{ $attr->{contents} } ) {
	my $fh = IO::File->new( $name, '>' )
	    or $_wail->( "Failed to open $name for output: $!" );
	print { $fh } $attr->{contents}{$name};
    }

    return $self;
}

sub get_item_content {
    my ( $self, $file ) = @_;
    my $attr = $_attr->( $self );

    if ( defined $file ) {
	$file = $self->base_directory() . $file;
    } else {
	( $file ) = keys %{ $attr->{contents} };
    }

    return $attr->{contents}{$file};
}

{

    my %handled = map { $_ => 1 } qw{ application/octet-stream };

    sub handle_http_response {
	my ( $class, $rslt ) = @_;

	my $content_type = $rslt->header( 'Content-Type' );

	$handled{ $content_type }
	    or $content_type =~ m{ \A text/ }smx
	    or return;

	return $class->new(
	    content	=> \( scalar $rslt->content() ),
	    encoding	=> scalar $rslt->header( 'Content-Encoding' ),
	    path	=> scalar $rslt->header( 'Content-Location' ),
	)->get_item_content();
    }

}

sub item_present {
    my ( $self, $item ) = @_;

    $item = $self->base_directory() . $item;

    my $attr = $_attr->( $self );
    return defined $attr->{contents}{$item};
}

sub list_contents {
    my ( $self ) = @_;
    my $attr = $_attr->( $self );

    my $re = $self->base_directory();
    $re = qr{ \A \Q$re\E }smx;

    my @rslt;
    foreach my $file ( sort keys %{ $attr->{content} } ) {
	$file =~ s/ $re //smx
	    or next;
	push @rslt, $file;
    }

    return @rslt;
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

This static method instantiates the object, and possibly loads it.
There are two supported arguments:

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

=back

=head2 get_item_content

This method returns the content of the named item in the archive.
Because there can only ever be one file in the pseudo-archive, if the
argument is C<undef>, the content of that file is returned.

=head2 list_contents

This method lists the contents of the archive. It always returns exactly
one name, which will be C<'unknown'> if the the object was initialized
with C<< content => \$scalar >>.


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
