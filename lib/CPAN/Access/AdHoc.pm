package CPAN::Access::AdHoc;

use 5.008;

use strict;
use warnings;

use Config::Tiny ();
use CPAN::Access::AdHoc::Util;
use CPAN::Meta;
use File::HomeDir ();
use File::Spec ();
use LWP::UserAgent ();
use Module::Pluggable::Object;
use Text::ParseWords ();

our $VERSION = '0.000_02';

my @attributes = (
    [ config		=> \&_attr_config,	],	# Must be first
    [ default_cpan_source => \&_attr_default_cpan_source,	],
    [ __debug		=> \&_attr_literal,	],
    [ cpan		=> \&_attr_cpan,	],	# Must be last
);

sub new {
    my ( $class, %arg ) = @_;

    my $self = bless {}, ref $class || $class;

    foreach my $attr ( @attributes ) {
	my $name = $attr->[0];
	$self->$name( delete $arg{$name} );
    }

    %arg
	and _wail( 'Unknown attribute(s): ', join ', ', sort keys %arg );

    return $self;
}

sub corpus {
    my ( $self, $cpan_id ) = @_;
    $cpan_id = uc $cpan_id;

    my $re = join '/',
	substr( $cpan_id, 0, 1 ),
	substr( $cpan_id, 0, 2 ),
	$cpan_id;

    $re = qr{ \A \Q$re\E / }smx;
    return ( grep { $_ =~ $re } $self->indexed_packages() );
}

{

    my @archivers = Module::Pluggable::Object->new(
	search_path	=> 'CPAN::Access::AdHoc::Archive',
	inner	=> 0,
	require	=> 1,
    )->plugins();

    sub fetch {
	my ( $self, $path ) = @_;

	$path =~ s{ \A / }{}smx;

	my $ua = LWP::UserAgent->new();

	my $url = $self->cpan() . $path;

	my $rslt = $ua->get( $url );

	$rslt->is_success
	    or _wail( "Failed to get $url: ", $rslt->status_line() );

	$rslt->header( 'Content-Location' => $path );

	$self->_normalize_mime_info( $url, $rslt );

	foreach my $archiver ( @archivers ) {
	    my $archive;
	    defined( $archive = $archiver->handle_http_response( $rslt ) )
		and return $archive;
	}

	_wail( sprintf q{Unsupported Content-Type '%s'},
	    $rslt->header( 'Content-Type' ) );

	return;	# Can't get here, but Perl::Critic does not know this.
    }
}

sub fetch_author_index {
    my ( $self ) = @_;

    exists $self->{_cache}{author_index}
	and return $self->{_cache}{author_index};

    my $author_details = $self->fetch( 'authors/01mailrc.txt.gz' );

    my $fh = IO::File->new( \$author_details, '<' );

    my %author_index;
    while ( <$fh> ) {
	s/ \s+ \z //smx;
	my ( $kind, $cpan_id, $address ) = Text::ParseWords::parse_line(
	    qr{ \s+ }smx, 0, $_ );
	( my $name = $address ) =~ s{ \s+ < (.*) > }{}smx;
	my $mail_addr = $1;
	$author_index{ uc $cpan_id } = {
	    name	=> $name,
	    address	=> $mail_addr,
	};
    }

    return ( $self->{_cache}{author_index} = \%author_index );
}

sub fetch_package_archive {
    my ( $self, $package ) = @_;
    return $self->fetch( "authors/id/$package" );
}

sub fetch_module_index {
    my ( $self ) = @_;

    exists $self->{_cache}{module_index}
	and return wantarray ?
	    @{ $self->{_cache}{module_index} } :
	    $self->{_cache}{module_index}[0];

    my $packages_details = $self->fetch( 'modules/02packages.details.txt.gz' );

    my $fh = IO::File->new( \$packages_details, '<' )
	or _wail( "Unable to open string reference: $!" );

    my $meta = $self->_read_meta( $fh );

    my %module;
    while ( <$fh> ) {
	chomp;
	my ( $mod, $ver, $pkg ) = split qr{ \s+ }smx;
##	'undef' eq $ver
##	    and $ver = undef;
	$module{$mod} = {
	    package	=> $pkg,
	    version	=> $ver,
	};
    }

    $self->{_cache}{module_index} = [ \%module, $meta ];

    return wantarray ? ( \%module, $meta ) : \%module;
}

sub fetch_registered_module_index {
    my ( $self ) = @_;

    exists $self->{_cache}{registered_module_index}
	and return wantarray ?
	    @{ $self->{_cache}{registered_module_index} } :
	    $self->{_cache}{registered_module_index}[0];

    my $packages_details = $self->fetch( 'modules/03modlist.data.gz' );

    my $fh = IO::File->new( \$packages_details, '<' )
	or _wail( "Unable to open string reference: $!" );

    my $meta = $self->_read_meta( $fh );

    my $code;
    {
	local $/ = undef;
	$code = <$fh>;
    }

    $self->{_cache}{registered_module_index} = [ $code, $meta ];

    return wantarray ? ( $code, $meta ) : $code;
}

sub flush {
    my ( $self ) = @_;
    delete $self->{_cache};
    return $self;
}

sub indexed_packages {
    my ( $self ) = @_;
    $self->{_cache}{indexed_packages}
	and return @{ $self->{_cache}{indexed_packages} };

    my $inx = $self->fetch_module_index();

    my %pkg;
    foreach my $info ( values %{ $inx } ) {
	$pkg{$info->{package}}++;
    }

    return @{ $self->{_cache}{indexed_packages} = [ sort keys %pkg ] };
}

# Set up the accessor/mutators. All mutators interpret undef as being a
# request to restore the default, from the configuration if that exists,
# or from the configured default code.

foreach my $info ( @attributes ) {
    my ( $name, $mutator ) = @{ $info };
    __PACKAGE__->can( $name ) and next;
    no strict qw{ refs };
    *$name = sub {
	my ( $self, @arg ) = @_;
	if ( @arg ) {
	    my $value = $arg[0];
	    if ( ! defined $value ) {
		my $config = $self->config();
		$value = $config->{_}{$name};
	    }
	    $self->{$name} = $mutator->( $self, $name, $value );
	    return $self;
	} else {
	    return $self->{$name};
	}
    };
}

# Compute the value of the config attribute.

{

    # Compute the config file's name and location.

    ( my $dist = __PACKAGE__ ) =~ s{ :: }{-}smxg;
    my $config_file = $dist . '.ini';
    my $config_dir = File::HomeDir->my_dist_config( $dist );
    my $config_path;
    defined $config_dir
	and $config_path = File::Spec->catfile( $config_dir, $config_file );

    sub _attr_config {
	my ( $self, $name, $value ) = @_;

	# If the new value is defined, it must be a Config::Tiny object
	if ( defined $value ) {
	    ref $value
		and eval {
		    $value->isa( 'Config::Tiny' );
		    1;
		}
		or _wail(
		    "Attribute '$name' must be a Config::Tiny reference" );
	# If the config file exists, read it
	} elsif ( defined $config_path && -f $config_path ) {
	    $value = Config::Tiny->read( $config_path );

	# Otherwise generate an empty configuration
	} else {
	    $value = Config::Tiny->new();
	}

	# Disallow the config key.
	delete $value->{_}{config};

	return $value;
    }
}

# Compute the value of the default_cpan_source attribute

sub _attr_default_cpan_source {
    my ( $self, $name, $value ) = @_;

    # The rationale of the default order is:
    # 1) Mini cpan: guaranteed to be local, and since it is non-core,
    #    the user had to install it, and can be presumed to be using it.
    # 2) CPAN minus: since it is non-core, the user had to install it,
    #    and can be presumed to be using it.
    # 3) CPAN: It is core, but it needs to be set up to be used, and the
    #    wrapper will detect if it has not been set up.
    # 4) CPANPLUS: It is core as of 5.10, and works out of the box, so
    #    we can not presume that the user actually uses it.
    defined $value
	or $value = 'CPAN::Mini,cpanm,CPAN,CPANPLUS';
    $self->_expand_default_cpan_source( $value );

    return $value;
}

# Compute the value of a literal attribute

sub _attr_literal {
    my ( $self, $name, $value );
    return $value;
}

# Compute the value of the cpan attribute. The actual computation of the
# default URL is outsourced to _get_default_url(). The attribute needs a
# trailing slash so we can just slap the path on the end of it.
sub _attr_cpan {
    my ( $self, $name, $value ) = @_;

    defined $value
	or $value = $self->_get_default_url();

    defined $value
	and not $value =~ m{ / \z }smx
	and $value .= '/';

    return $value;
}

{

    my $search_path = 'CPAN::Access::AdHoc::Default::CPAN';
    my %defaulter = map {
	substr( $_, length( $search_path ) + 2 ) => $_
    } Module::Pluggable::Object->new(
	search_path	=> $search_path,
	inner	=> 0,
	require	=> 1,
    )->plugins();

    sub _expand_default_cpan_source {
	my ( $self, $value ) = @_;
	defined $value
	    or $value = $self->default_cpan_source();
	my @rslt;
	foreach my $source ( split qr{ \s* , \s* }smx, $value ) {
	    defined( my $class = $defaulter{$source} )
		or _wail( "Unknown default_cpan_source '$source'" );
	    push @rslt, $class;
	}
	return @rslt;
    }

}

# Get the repository URL from the first source that actually supplies
# it. The CPAN::Access::AdHoc::Default::CPAN plug-ins are called in the order
# specified in the default_cpan_source attribute, and the first source
# that actually supplies a URL is used. If that source provides a file:
# URL, the first such is returned. Otherwise the first URL is returned,
# whatever its scheme. If no URL can be determined, we die.

sub _get_default_url {
    my ( $self ) = @_;

    my $url;

    my $debug = $self->__debug();

    foreach my $class ( $self->_expand_default_cpan_source() ) {

	my @url_list = $class->get_default()
	    or next;

	foreach ( @url_list ) {
	    m/ \A file: /smx
		or next;
	    $url = $_;
	    last;
	}

	defined $url
	    or $url = $url_list[0];

	$debug
	    and warn "Debug - Default cpan '$url' from $class\n";

	return $url;
    }

    _wail( 'No CPAN URL obtained from ' . $self->default_cpan_source() );

    return;
}

# We would love to rely on the MIME info returned by the CPAN mirror,
# but sad experience shows that these are a bit haphazard. So we compute
# our own Content-Type and Content-Encoding based on the URL we fetched,
# and replace those headers in the HTTP::Result with our computations.
# The only way the original Content-Type and Content-Encoding survive is
# if we don't overwrite them.
#
# The returned value is to be ignored.

sub _normalize_mime_info {
    my ( $self, $url, $rslt ) = @_;

    local $_ = $url;

    s/ [.] gz \z //smx
	and $rslt->header( 'Content-Encoding' => 'gzip' )
	or s/ [.] bz2 \z //smx
	and $rslt->header( 'Content-Encoding' => 'x-bzip2' );

    m/ [.] pm \z /smx
	and return $rslt->header( 'Content-Type' => 'text/plain' );

    m/ [.] txt \z /smx
	and return $rslt->header( 'Content-Type' => 'text/plain' );

    m/ [.] data \z /smx
	and return $rslt->header(
	    'Content-Type' => 'application/octet-stream' );

    m/ [.] tar \z /smx
	and return $rslt->header( 'Content-Type' => 'application/x-tar' );

    m/ [.] zip \z /smx
	and return $rslt->header( 'Content-Type' => 'application/zip' );

    m/ [.] tgz \z /smx
	and return $rslt->header(
	'Content-Type' => 'application/x-tar',
	'Content-Encoding' => 'gzip',
    );

    return;
}

sub _read_meta {
    my ( $self, $fh ) = @_;
    my %meta;
    {
	my ( $name, $value );
	while ( <$fh> ) {
	    chomp;
	    m/ \S /smx or last;
	    if ( s/ \A \s+ //smx ) {
		$meta{$name} .= " $_";
	    } else {
		( $name, $value ) = split qr{ : \s* }smx, $_, 2;
		$meta{$name} = $value;
	    }
	}
    }
    return \%meta;
}

sub _wail {
    my @args = @_;
    require Carp;
    Carp::croak( @args );
}


1;

__END__

=head1 NAME

CPAN::Access::AdHoc - Retrieve stuff from an arbitrary CPAN repository

=head1 SYNOPSIS

 use CPAN::Access::AdHoc;
 
 my ( $module ) = @ARGV;
 my $cad = CPAN::Access::AdHoc->new();
 my $index = $cad->fetch_module_index();
 if ( $index->{$module} ) {
     print "$module is in $index->{package}\n";
 } else {
     print "$module is not indexed\n";
 }

=head1 DESCRIPTION

This class provides a lowish-level interface to an arbitrary CPAN
repository. You can fetch anything, but there is particular support for
the author and module indices, distributions, and their metadata.

What it does not provide is module installation, dependency resolution,
or what-have-you. There are already plenty of tools for that.

The intent is that this should be a zero-configuration system, or at
least a configuration-optional system.

Attributes can be specified explicitly either when the object is
instantiated or afterwards. The default is from the global section of a
L<Config::Tiny|Config::Tiny> configuration file, F<CPAN-Access-AdHoc.ini>,
which is found in directory
C<< File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ) >>. The named sections
are currently unused, though C<CPAN-Access-AdHoc> reserves to itself all
section names which contain no uppercase letters.

In addition, it is possible to take the default CPAN repository URL from
the user's L<CPAN::Mini|CPAN::Mini>, L<cpanm|cpanm>, L<CPAN|CPAN>, or
L<CPANPLUS|CPANPLUS> configuration. They are accessed in this order by
default, and the first available is used. But which of these are
considered, and the order in which they are considered is under the
user's control, via the L<default_cpan_source|/default_cpan_source>
attribute/configuration item.

What actually happened here is that I got an RT ticket on one of my CPAN
distributions, pointing out that the Free Software Foundation had moved,
and I needed to update the copy of the Gnu GPL that I distributed. Well,
it's the same text for all my distributions, so I wanted a tool to tell
me which ones had already been updated in CPAN.

A little later, I realized that a clobbered version of one of my author
tests got shipped in a couple distributions, so I wrote another Perl
script to see how far the rot had spread.

Then I found out about an interesting but somewhat heavyweight module,
and wanted to know what I B<really> needed to install to get it going.
Yes, F<cpanm> will do this, but I have not taken that step yet.

So I found myself writing mostly the same code for the third time, and
decided there ought to be a better way. Hence this module.

=head1 METHODS

This class supports the following public methods:

=head2 Instantiator

=head3 new

This static method instantiates the object. You can specify attribute
values by passing name/value argument pairs. Defaults are documented
with the individual attributes.

If you do not specify an explicit C<cpan> argument, and a default CPAN
URL can not be computed, an exception is thrown. See the L<cpan|/cpan>
attribute documentation for a few more details.

=head2 Accessors/Mutators

=head3 config

When called with no arguments, this method acts as an accessor, and
returns the current configuration as a L<Config::Tiny|Config::Tiny>
object.

When called with an argument, this method acts as a mutator. If the
argument is a L<Config::Tiny|Config::Tiny> object it becomes the new
configuration. If the argument is C<undef>, file F<CPAN-Access-AdHoc.ini> in
C<< File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ) >> is read for the
configuration. If this file does not exist, the configuration is set to
an empty L<Config::Tiny|Config::Tiny> object.

=head3 cpan

When called with no arguments, this method acts as an accessor, and
returns the URL of the CPAN repository accessed by this object.

When called with an argument, this method acts as a mutator, and sets
the URL of the CPAN repository accessed by this object.

If the argument is C<undef>, the default URL as computed from the
sources in L<default_cpan_source|/default_cpan_source> is used. If no
URL can be computed from any source, an exception is thrown.

=head3 default_cpan_source

When called with no arguments, this method acts as an accessor, and
returns the current list of default CPAN sources as a comma-delimited
string.

When called with an argument, this method acts as a mutator, and sets
the list of default CPAN sources. This list is a comma-delimited string,
and consists of the names of zero or more
C<CPAN::Access::AdHoc::Default::CPAN::*> classes, with the common
prefix removed.  object. See the documentation of these classes for more
information.

If any of the elements in the string does not represent an existing
C<CPAN::Access::AdHoc::Default::CPAN::> class, an exception is thrown
and the value of the attribute remains unmodified.

If the argument is C<undef>, the default is restored.

The default is C<'CPAN::Mini,cpanm,CPAN,CPANPLUS'>.

=head2 Functionality

These methods are what all the rest is in aid of.

=head3 corpus

This convenience method returns a list of the indexed packages by the
author with the given CPAN ID. This information is derived from the
output of L<indexed_packages()|/indexed_packages>. The argument is
converted to upper case before use.

=head3 fetch

This method fetches the named file from the CPAN repository. Its
argument is the name of the file relative to the root of the repository.
If the file is compressed in some way it will be decompressed.

If the fetched file is an archive of some sort, an object representing
the archive will be returned. This object will be of one of the
C<CPAN::Access::AdHoc::Archive::*> classes, each of which wraps the
corresponding C<Archive::*> class and provides C<CPAN::Access::AdHoc>
with a consistent interface. These classes will be initialized with

 content => the literal content of the archive, as downloaded,
 encoding => the MIME encoding used to decode the archive,
 path => the path to the archive, relative to the base URL.

If the fetched file is not an archive, the file contents are returned.

All other fetch functionality is implemented in terms of this method.

=head3 fetch_author_index

This method fetches the author index, F<authors/01mailrc.txt.gz>. It is
expanded and interpreted, and returned as a hash reference keyed by the
authors' CPAN IDs. The data for each author is an anonymous hash with
the following keys:

=over

=item name => the name of the author;

=item address => the electronic mail address of the author.

=back

The results of the first fetch are cached; subsequent calls are supplied
from cache.

=head3 fetch_module_index

This method fetches the module index,
F<modules/02packages.details.txt.gz>. It is expanded and interpreted,
and returned as a hash reference keyed by the module names. The data for
each module is an anonymous hash with the following keys:

=over

=item package => the name of the package that contains the module,
relative to the F<authors/id/> directory;

=item version => the version of the module.

=back

If called in list context, the first return is the index, and the second
is another hash reference containing the metadata that appears at the
top of the expanded index file.

The results of the first fetch are cached; subsequent calls are supplied
from cache.

=head3 fetch_package_archive

This method takes as its argument the name of a package file relative to
the archive's F<authors/id/> directory, and returns the package as a
C<CPAN::Access::AdHoc::Archive::*> object.

Note that since this method is implemented in terms of
L<fetch()|/fetch>, the archive method's C<path> attribute will be set to
its path relative to the base URL of the CPAN repository, not its path
relative to the F<authors/id/> directory. So, for example,

 $arc = $cad->fetch_package_archive( 'B/BA/BACH/PDQ-0.000_01.zip
 say $arc->path(); # authors/id/B/BA/BACH/PDQ-0.000_01.zip

=head3 fetch_registered_module_index

This method fetches the registered module index,
F<modules/03modlist.data.gz>. It is expanded and returned as a string.
This string, when when run through a stringy C<eval>, creates
C<< CPAN::Modulelist->data() >>, which returns the list.

If called in list context, the first return is the index, and the second
is a hash reference containing the metadata that appears at the top of
the expanded index file.

The results of the first fetch are cached; subsequent calls are supplied
from cache.

=head3 flush

This method deletes all cached results, causing them to be re-fetched
when needed.

=head3 indexed_packages

This convenience method returns a list of all indexed packages in
ASCIIbetical order. This information is derived from the results of
L<fetch_module_index()|/fetch_module_index>, and is cached.

=head1 SEE ALSO

L<CPAN::DistnameInfo|CPAN::DistnameInfo>, which parses distribution name
and version (among other things) from the name of a particular
distribution archive. This was very helpful in some of my CPAN
ad-hocery.

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
