package CPAN::Access::AdHoc;

use 5.008;

use strict;
use warnings;

use Config::Tiny ();
use CPAN::Access::AdHoc::Archive;
use CPAN::Access::AdHoc::Util qw{
    :carp __attr __cache __expand_distribution_path __guess_media_type
};
use Digest::SHA ();
use File::HomeDir ();
use File::Spec ();
use IO::File ();
use LWP::UserAgent ();
use LWP::Protocol ();
use Module::Pluggable::Object;
use Safe;
use Text::ParseWords ();
use URI ();

our $VERSION = '0.000_15';

# In the following list of attribute names, 'config' must be first
# because it supplies default values for everything else. 'cpan' must be
# after 'default_cpan_source' because 'default_cpan_source' determines
# how the default value of 'cpan' is computed.
my @attributes = qw{
    config __debug http_error_handler default_cpan_source cpan
};

sub new {
    my ( $class, %arg ) = @_;

    my $self = bless {}, ref $class || $class;

    $self->__init( \%arg );

    %arg
	and __wail( 'Unknown attribute(s): ', join ', ', sort keys %arg );

    return $self;
}

sub __init {
    my ( $self, $arg ) = @_;

    foreach my $name ( @attributes ) {
	$self->$name( delete $arg->{$name} );
    }

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
    return ( grep { $_ =~ $re } $self->indexed_distributions() );
}

sub fetch {
    my ( $self, $path ) = @_;

    $path =~ s{ \A / }{}smx;

    my $ua = LWP::UserAgent->new();

    my $url = $self->cpan() . $path;

    my $rslt = $ua->get( $url );

    $rslt->is_success
	or return $self->http_error_handler()->( $self, $path, $rslt );

    __guess_media_type( $rslt, $path );

    $self->_checksum( $rslt );

    my $archive =
	CPAN::Access::AdHoc::Archive->__handle_http_response( $rslt )
	or __wail( sprintf q{Unsupported Content-Type '%s'},
	$rslt->header( 'Content-Type' ) );

    return $archive;
}

sub fetch_author_index {
    my ( $self ) = @_;

    my $cache = $self->__cache();
    exists $cache->{author_index}
	and return $cache->{author_index};

    my $author_details = $self->fetch(
	'authors/01mailrc.txt.gz'
    )->get_item_content();

    my $fh = IO::File->new( \$author_details, '<' )
	or __wail( "Unable to open string reference: $!" );

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

    return ( $cache->{author_index} = \%author_index );
}

sub fetch_distribution_archive {
    my ( $self, $distribution ) = @_;
    my $path = __expand_distribution_path( $distribution );
    return $self->fetch( "authors/id/$path" );
}

sub fetch_distribution_checksums {
    my ( $self, $distribution ) = @_;
    $distribution =~ m{ \A ( .* / ) ( [^/]* ) \z }smx
	or __wail( "Invalid distribution '$distribution'" );
    my ( $dir, $file ) = ( $1, $2 );
    $file eq 'CHECKSUMS'
	and $file = '';
    my $path = __expand_distribution_path( $dir . 'CHECKSUMS' );
    ( $dir = $path ) =~ s{ [^/]* \z }{}smx;
    my $cache = $self->__cache();
    $cache->{checksums}{$dir} ||= _eval_string(
	$self->fetch( "authors/id/$path" )->get_item_content() );
    $file eq ''
	and return $cache->{checksums}{$dir};
    return $cache->{checksums}{$dir}{$file};
}

sub fetch_module_index {
    my ( $self ) = @_;

    my $cache = $self->__cache();

    exists $cache->{module_index}
	and return wantarray ?
	    @{ $cache->{module_index} } :
	    $cache->{module_index}[0];

    my ( $meta, %module );

    # The only way this can return undef is if the http_error_handler
    # returns it. We take that as a request to cache an empty index.
    if ( my $packages_details = $self->fetch(
	    'modules/02packages.details.txt.gz' ) ) {
	$packages_details = $packages_details->get_item_content();

	my $fh = IO::File->new( \$packages_details, '<' )
	    or __wail( "Unable to open string reference: $!" );

	$meta = $self->_read_meta( $fh );

	while ( <$fh> ) {
	    chomp;
	    my ( $mod, @info ) = split qr{ \s+ }smx;
##	    'undef' eq $ver
##		and $ver = undef;
	    my ( $pkg, $ver ) = reverse @info;
	    defined $ver or $ver = 'undef';
	    $module{$mod} = {
		distribution	=> $pkg,
		version		=> $ver,
	    };
	}

    } else {
	$meta = {};
    }

    $cache->{module_index} = [ \%module, $meta ];

    return wantarray ? ( \%module, $meta ) : \%module;
}

sub fetch_registered_module_index {
    my ( $self ) = @_;

    my $cache = $self->__cache();
    exists $cache->{registered_module_index}
	and return wantarray ?
	    @{ $cache->{registered_module_index} } :
	    $cache->{registered_module_index}[0];

    my $packages_details = $self->fetch(
	'modules/03modlist.data.gz'
    )->get_item_content();

    my ( $meta, $reg );

    {

	my $fh = IO::File->new( \$packages_details, '<' )
	    or __wail( "Unable to open string reference: $!" );

	$meta = $self->_read_meta( $fh );

	local $/ = undef;
	$reg = <$fh>;
    }

    my $hash = _eval_string( "$reg\nCPAN::Modulelist->data();" );

    $cache->{registered_module_index} = [ $hash, $meta ];

    return wantarray ? ( $hash, $meta ) : $hash;
}

sub flush {
    my ( $self ) = @_;
    delete $self->{'.cache'};
    return $self;
}

sub indexed_distributions {
    my ( $self ) = @_;

    my $cache = $self->__cache();

    $cache->{indexed_distributions}
	and return @{ $cache->{indexed_distributions} };

    my $inx = $self->fetch_module_index();

    my %pkg;
    foreach my $info ( values %{ $inx } ) {
	$pkg{$info->{distribution}}++;
    }

    return @{ $cache->{indexed_distributions} = [ sort keys %pkg ] };
}

# Set up the accessor/mutators. All mutators interpret undef as being a
# request to restore the default, from the configuration if that exists,
# or from the configured default code.

__PACKAGE__->__create_accessor_mutators( @attributes );

sub _create_accessor_mutator_helper {
    my ( $class, $name, $code ) = @_;
    $class->can( $name )
	and return;
    my $full_name = "${class}::$name";
    no strict qw{ refs };
    *$full_name = $code;
    return;
}

sub __create_accessor_mutators {
    my ( $class, @attrs ) = @_;
    foreach my $name ( @attrs ) {
	$class->can( $name ) and next;
	my $full_name = "${class}::$name";
	$class->_create_accessor_mutator_helper(
	    "__attr__${name}__validate" => sub { return $_[1] } );
	$class->_create_accessor_mutator_helper(
	    "__attr__${name}__post_assignment" => sub { return $_[1] } );
	no strict qw{ refs };
	*$full_name = sub {
	    my ( $self, @arg ) = @_;
	    my $attr = $self->__attr();
	    if ( @arg ) {
		my $value = $arg[0];
		not defined $value
		    and 'config' ne $name
		    and $value = $self->config()->{_}{$name};
		my $code;
		not defined $value
		    and $code = $self->can( "__attr__${name}__default" )
		    and $value = $code->( $self );
		$code = $self->can( "__attr__${name}__validate" )
		    and $value = $code->( $self, $value );
		$attr->{$name} = $value;
		$code = $self->can( "__attr__${name}__post_assignment" )
		    and $code->( $self );
		return $self;
	    } else {
		return $attr->{$name};
	    }
	};
    }
    return;
}

{

    # Compute the config file's name and location.

    ( my $dist = __PACKAGE__ ) =~ s{ :: }{-}smxg;
    my $config_file = $dist . '.ini';
    my $config_dir = File::HomeDir->my_dist_config( $dist );
    my $config_path;
    defined $config_dir
	and $config_path = File::Spec->catfile( $config_dir, $config_file );

    sub __attr__config__default {
	my ( $self ) = @_;
	defined $config_path
	    and -f $config_path
	    and return Config::Tiny->read( $config_path );
	return Config::Tiny->new();
    }
}

sub __attr__config__validate {
    my ( $self, $value ) = @_;

    my $err = "Attribute 'config' must be a file name or a " .
	"Config::Tiny reference";
    if ( ref $value ) {
	eval {
	    $value->isa( 'Config::Tiny' );
	} or __wail( $err );
    } else {
	-f $value
	    or __wail( $err );
	$value = Config::Tiny->read( $value );
    }

    delete $value->{_}{config};
    return $value;
}

# The rationale of the default order is:
# 1) Mini cpan: guaranteed to be local, and since it is non-core,
#    the user had to install it, and can be presumed to be using it.
# 2) CPAN minus: since it is non-core, the user had to install it,
#    and can be presumed to be using it.
# 3) CPAN: It is core, but it needs to be set up to be used, and the
#    wrapper will detect if it has not been set up.
# 4) CPANPLUS: It is core as of 5.10, and works out of the box, so
#    we can not presume that the user actually uses it.
sub __attr__default_cpan_source__default {
    return 'CPAN::Mini,cpanm,CPAN,CPANPLUS';
}

sub DEFAULT_HTTP_ERROR_HANDLER {
    my ( $self, $path, $resp ) = @_;
    my $url = $self->cpan() . $path;
    __wail( "Failed to get $url: ", $resp->status_line() );
}

sub __attr__http_error_handler__default {
    return \&DEFAULT_HTTP_ERROR_HANDLER;
}

sub __attr__http_error_handler__validate {
    my ( $self, $value ) = @_;
    'CODE' eq ref $value
	or __wail(
	q{Attribute 'http_error_handler' must be a code reference}
    );
    return $value;
}

sub __attr__cpan__post_assignment {
    my ( $self ) = @_;

    $self->flush();

    return;
}

sub __attr__cpan__validate {
    my ( $self, $value ) = @_;

    $value = "$value";	# Stringify
    $value =~ s{ (?<! / ) \z }{/}smx;

    my $url = URI->new( $value )
	or _wail( "Bad URL '$value'" );
    $value = $url;

    my $scheme = $value->scheme();
    my $ua = LWP::UserAgent->new();
    $value->can( 'authority' )
	and LWP::Protocol::implementor( $scheme )
	or __wail ( "URL scheme $scheme: is unsupported" );

    return $value;
}

# Check the file's checksum if appropriate.
#
# The argument is the HTTP::Response object that contains the data to
# check. This object is expected to have its Content-Location set to the
# path relative to the root of the site.
#
# Files are not checked unless they are in authors/id/, and are not
# named CHECKSUM.

sub _checksum {
    my ( $self, $rslt ) = @_;
    defined( my $path = $rslt->header( 'Content-Location' ) )
	or return;
    $path =~ m{ \A authors/id/ ( [^/] ) / ( \1 [^/] ) / \2 }smx
	or return;
    $path =~ m{ /CHECKSUMS \z }smx
	and return;
    my $cks_path = $path;
    $cks_path =~ s{ \A authors/id/ }{}smx
	or return;
    my $cksum = $self->fetch_distribution_checksums( $cks_path )
	or return;
    $cksum->{sha256}
	or return;
    my $got = Digest::SHA::sha256_hex( $rslt->content() );
    $got eq $cksum->{sha256}
	or __wail( "Checksum failure on $path" );
    return;
}

# Expand the default_cpan_source attribute into a list of class names,
# each implementing one of the listed defaults.

{

    my $search_path = 'CPAN::Access::AdHoc::Default::CPAN';
    my %defaulter = map { (
        $_ => $_,
	substr( $_, length( $search_path ) + 2 ) => $_,
    ) } Module::Pluggable::Object->new(
	search_path	=> $search_path,
	inner	=> 0,
	require	=> 1,
    )->plugins();

    sub __attr__default_cpan_source__validate {
	my ( $self, $value ) = @_;

	ref $value
	    or $value = [ split qr{ \s* , \s* }smx, $value ];

	'ARRAY' eq ref $value
	    or __wail( q{Attribute 'default_cpan_source' takes an array } .
	    q{reference or a comma-delimited string} );
	my @rslt;
	foreach my $source ( @{ $value } ) {
	    defined( my $class = $defaulter{$source} )
		or __wail( "Unknown default_cpan_source '$source'" );
	    push @rslt, $class;
	}
	return \@rslt;
    }

}

# Eval a string in a sandbox, and return the result. This was cribbed
# _very_ heavily from CPAN::Distribution CHECKSUM_check_file().
sub _eval_string {
    my ( $string ) = @_;
    $string =~ s/ \015? \012 /\n/smxg;
    my $sandbox = Safe->new();
    $sandbox->permit_only( ':default' );
    my $rslt = $sandbox->reval( $string );
    $@ and __wail( $@ );
    return $rslt;
}

# Get the repository URL from the first source that actually supplies
# it. The CPAN::Access::AdHoc::Default::CPAN plug-ins are called in the
# order specified in the default_cpan_source attribute, and the first
# source that actually supplies a URL is used. If that source provides a
# file: URL, the first such is returned. Otherwise the first URL is
# returned, whatever its scheme. If no URL can be determined, we die.

sub __attr__cpan__default {
    my ( $self ) = @_;

    my $url;

    my $debug = $self->__debug();

    foreach my $class ( @{ $self->default_cpan_source() } ) {

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

    __wail( 'No CPAN URL obtained from ' . $self->default_cpan_source() );
}

# modules/02packages.details.txt.gz and modules/03modlist.data.gz have
# metadata at the top. This metadata is organized as lines of
#     key: value
# with the key left-justified. Lines can be wrapped, with leading
# spaces.

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
     print "$module is in $index->{distribution}\n";
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
L<Config::Tiny|Config::Tiny> configuration file,
F<CPAN-Access-AdHoc.ini>, which is found in directory
C<< File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ) >>. The named
sections are currently unused, though C<CPAN-Access-AdHoc> reserves to
itself all section names which contain no uppercase letters.

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
configuration. If the argument is C<undef>, file
F<CPAN-Access-AdHoc.ini> in
C<< File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ) >> is read for
the configuration. If this file does not exist, the configuration is set
to an empty L<Config::Tiny|Config::Tiny> object.

=head3 cpan

When called with no arguments, this method acts as an accessor, and
returns a L<URI|URI> object representing the URL of the CPAN repository
being accessed.

When called with an argument, this method acts as a mutator. It sets the
URL of the CPAN repository accessed by this object, and (for reasons of
sanity) calls L<flush()|/flush> to purge any data cached from the old
repository. The argument can be either a string or an object that
stringifies (such as a L<URI|URI> object). To be valid, the scheme must
be supported by L<LWP::UserAgent|LWP::UserAgent> (that is,
C<LWP::Protocol::implementor()> must return a true value), and must
support a hierarchical name space. That means that schemes like
C<file:>, C<http:>, and C<ftp:> are accepted, but schemes like
C<mailto:> (non-hierarchical name space) and C<foobar:> (not known to be
supported by C<LWP::UserAgent>) are not.

If the argument is C<undef>, the default URL as computed from the
sources in L<default_cpan_source|/default_cpan_source> is used. If no
URL can be computed from any source, an exception is thrown.

=head3 default_cpan_source

When called with no arguments, this method acts as an accessor, and
returns the current list of default CPAN sources as an array reference.
B<This is incompatible with version 0.000_08 and before>, where the
return was a comma-delimited string.

When called with an argument, this method acts as a mutator, and sets
the list of default CPAN sources. This list is either an array reference
or a comma-delimited string, and consists of the names of zero or more
C<CPAN::Access::AdHoc::Default::CPAN::*> classes. With either mechanism
the names of the classes may be passed without the common prefix, which
will be added back if needed. See the documentation of these classes for
more information.

If any of the elements in the string does not represent an existing
C<CPAN::Access::AdHoc::Default::CPAN::> class, an exception is thrown
and the value of the attribute remains unmodified.

If the argument is C<undef>, the default is restored.

The default is C<'CPAN::Mini,cpanm,CPAN,CPANPLUS'>.

=head3 http_error_handler

When called with no arguments, this method acts as an accessor, and
returns the current HTTP error handler.

When called with an argument, this method acts as a mutator, and sets
the HTTP error handler. This must be a code reference.

When an HTTP error is encountered, the handler will be called and passed
three arguments: the C<CPAN::Access::AdHoc> object, the path relative to
the base URL of the CPAN repository, and the C<HTTP::Response> object.
Whatever it returns will be returned by the caller.

If the argument is C<undef>, the default is restored.

The default is C<\&CPAN::Access::AdHoc::DEFAULT_HTTP_ERROR_HANDLER>,
which throws an exception, giving the URL and the HTTP status line. If
you do not want to code for every error you might encounter, handle the
uninteresting errors with

 goto &CPAN::Access::AdHoc::DEFAULT_HTTP_ERROR_HANDLER:

This assumes that you have not modified C<@_>.

=head2 Functionality

These methods are what all the rest is in aid of.

=head3 corpus

This convenience method returns a list of the indexed distributions by
the author with the given CPAN ID. This information is derived from the
output of L<indexed_distributions()|/indexed_distributions>. The
argument is converted to upper case before use.

=head3 fetch

This method fetches the named file from the CPAN repository. Its
argument is the name of the file relative to the root of the repository.

If this method determines that there might be checksums for this file,
it attempts to retrieve them, and if successful will compare the
C<SHA256> checksum of the retrieved data to the retrieved value.

If the file is compressed in some way it will be decompressed.

If the fetched file is an archive of some sort, an object representing
the archive will be returned. This object will be of one of the
C<CPAN::Access::AdHoc::Archive::*> classes, each of which wraps the
corresponding C<Archive::*> class and provides C<CPAN::Access::AdHoc>
with a consistent interface. These classes will be initialized with

 content => the literal content of the archive, as downloaded,
 encoding => the MIME encoding used to decode the archive,
 path => the path to the archive, relative to the base URL.

If the fetched file is not an archive, it is wrapped in a
L<CPAN::Access::AdHoc::Archive::Null|CPAN::Access::AdHoc::Archive::Null>
object and returned.

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

=item distribution => the name of the distribution that contains the
module, relative to the F<authors/id/> directory;

=item version => the version of the module.

=back

If called in list context, the first return is the index, and the second
is another hash reference containing the metadata that appears at the
top of the expanded index file.

If an HTTP error is encountered while fetching the index, normally an
error is thrown. But if the C<http_error_handler> returns nothing, an
empty index (and empty index metadata) are returned.

The results of the first fetch are cached; subsequent calls are supplied
from cache.

=head3 fetch_distribution_archive

This method takes as its argument the name of a distribution file
relative to the archive's F<authors/id/> directory, and returns the
distribution as a C<CPAN::Access::AdHoc::Archive::*> object.

Note that since this method is implemented in terms of
L<fetch()|/fetch>, the archive method's C<path> attribute will be set to
its path relative to the base URL of the CPAN repository, not its path
relative to the F<authors/id/> directory. So, for example,

 $arc = $cad->fetch_distribution_archive(
     'B/BA/BACH/PDQ-0.000_01.zip' );
 say $arc->path(); # authors/id/B/BA/BACH/PDQ-0.000_01.zip

For convenience, either the top or the top two directories can be
omitted, since they can be reconstructed from the rest. So the above
example can also be written as

 $arc = $cad->fetch_distribution_archive(
     'BACH/PDQ-0.000_01.zip' );
 say $arc->path(); # authors/id/B/BA/BACH/PDQ-0.000_01.zip

=head3 fetch_distribution_checksums

 use YAML::Any;
 print Dump( $cad->fetch_distribution_checksums(
     'B/BA/BACH/' ) );
 print Dump( $cad->fetch_distribution_checksums(
     'B/BA/BACH/Johann-0.001.tar.bz2' ) );

This method takes as its argument either a file name or a directory name
relative to F<authors/id/>. A directory is indicated by a trailing
slash.

If the request if for the F<CHECKSUMS> file, the return is a reference
to a hash which contains the interpreted contents of the entire file.

If the argument is a file name other than F<CHECKSUMS>, the return is a
reference to the F<CHECKSUMS> entry for that file, provided it exists.

If the argument is a directory name, it is treated like a request for
the F<CHECKSUMS> file in that directory.

If the F<CHECKSUMS> file does not exist, an exception is raised. If the
argument was a file name and the file has no entry in the F<CHECKSUMS>
file, nothing is returned.

For convenience, either the top or the top two directories can be
omitted, since they can be reconstructed from the rest.

The result of the first fetch for a given directory is cached, and
subsequent calls for the same author are supplied from cache.

=head3 fetch_registered_module_index

This method fetches the registered module index,
F<modules/03modlist.data.gz>. It is interpreted, and returned as a hash
reference keyed by module name.

If called in list context, the first return is the index, and the second
is a hash reference containing the metadata that appears at the top of
the expanded index file.

The results of the first fetch are cached; subsequent calls are supplied
from cache.

=head3 flush

This method deletes all cached results, causing them to be re-fetched
when needed.

=head3 indexed_distributions

This convenience method returns a list of all indexed distributions in
ASCIIbetical order. This information is derived from the results of
L<fetch_module_index()|/fetch_module_index>, and is cached.

=head2 Subclass Methods

The following methods exist for the benefit of subclasses, and should
not be considered part of the public interface. I am willing to make
this interface public on request, but until the request comes I will
consider myself at liberty to modify it without notice.

=head3 __attr

This method returns a hash containing all attributes specific to the
class that makes the call. This hash may be modified, and in fact must
be to store new attribute values.

=head3 __cache

This method returns a hash containing all values cached by the object.
This hash may be modified, and in fact must be to cache new values.

=head3 __create_accessor_mutators

 __PACKAGE__->__create_accessor_mutators( @attributes );

This static method creates accessor/mutator methods for the attributes
named in its argument list. If a subroutine with the same name as an
attribute exists at the time this method is called, that subroutine is
assumed to be the accessor/mutator for that attribute.

The methods created by C<__create_accessor_mutators()> have three hooks
for behavior modification. For any attribute C<whatever>, these are:

=over

=item __attr__whatever__default

 my ( $self, $value ) = @_;
 my $code;
 not defined $value
     and $code = $self->can( '__attr__whatever__default' )
     and $value = $code->( $self );

This is called when the mutator is passed a new value of C<undef>. Its
only argument is the invocant. It must return a valid value of the
attribute.

If a subclass overrides this, the subclass probably should not call
C<< $self->SUPER::__attr__whatever__default() >>.

=item __attr__whatever__validate

 my ( $self, $value ) = @_;
 my $code;
 $code = $self->can( '__attr__whatever__validate' )
     and $value = $code->( $self, $value );

This method is called after C<__attr__whatever__default()>, and
validates the value. It rejects a value by throwing an exception. The
preferred way to do this is by calling C<__wail()>.

If a subclass overrides this, the subclass B<must> execute

 $value = $self->SUPER::__attr__whatever__validate( $value );

before it performs its own validation. The superclass method B<must>
return the internal format of the attribute's value, which the subclass
B<must> return after validating.

=item __attr__whatever__post_assignment

 $self->__attr__whatever__post_assignment()

This method is called after the new value has been assigned to the
attribute.

If a subclass overrides this, it B<must> call
C<< $self->SUPER::__attr__whatever__post_assignment() >>, and it
B<should> call it last thing before returning.

=back

All these hooks are optional, but C<__create_accessor_mutators()> will
generate dummy C<__attr__whatever__validate()> and
C<__attr__whatever__post_assignment()> methods for any attributes that
do not have them at the time it is called.

=head3 __init

This method is called when a new object is instantiated. Its arguments
are the invocant and a reference to a hash containing attribute names
and values.

If a subclass adds attributes, it B<must> override this method. The
override B<must> call C<< $self->SUPER::__init( $args ) >> first thing.
It B<must> then set its own attributes from the C<$args> hash reference,
deleting them from the hash. The override returns nothing.

=head1 SEE ALSO

L<App::cpanlistchanges|App::cpanlistchanges> by Tatsuhiko Miaygawa lists
Changes files -- by default the changes from the version you have
installed to the most-current CPAN version.

L<CPAN::DistnameInfo|CPAN::DistnameInfo> by Graham Barr, which parses
distribution name and version (among other things) from the name of a
particular distribution archive. This was very helpful in some of my
CPAN ad-hocery.

L<CPAN::Easy|CPAN::Easy> by Chris Weyl, which retrieves distributions
and their meta information. As of this writing, it does not support
version 2.0 of the meta spec.

L<CPAN::Index|CPAN::Index> by Adam Kennedy, which accesses the CPAN
indices, storing them in an SQLite database.

L<CPAN::Inject|CPAN::Inject> by Adam Kennedy, which injects tarballs
into a F<.cpan/sources> directory for a given CPAN ID.

L<CPAN::Meta|CPAN::Meta> by David Golden, which presents a unified
interface for the various versions of the CPAN meta-data specification.

L<CPAN::Mini|CPAN::Mini> by Ricardo Signes, which lets you have your own
personal CPAN, optionally with only the latest distributions.

L<CPAN::Mini::Devel|CPAN::Mini::Devel> by David Golden, which is
L<CPAN::Mini|CPAN::Mini> with the addition of developer releases.

L<CPAN::Mini::Inject|CPAN::Mini::Inject> by Christian Walde, which
injects distributions into a Mini-CPAN.

L<CPAN::PackageDetails|CPAN::PackageDetails> by Brian D Foy, which reads
and writes the CPAN F<modules/02packages.details.txt.gz> file.

L<Parse::CPAN::Packages|Parse::CPAN::Packages> by Christian Wade, which
parses the CPAN F<modules/02packages.details.txt.gz> file.

L<Parse::CPAN::Packages::Fast|Parse::CPAN::Packages::Fast> by Slaven
Rezic, non-OO code which parses the CPAN
F<modules/02packages.details.txt.gz> file.

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
