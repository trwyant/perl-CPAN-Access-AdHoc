package My::Module::Meta;

use 5.010;

use strict;
use warnings;

use Carp;

sub new {
    my ( $class ) = @_;
    ref $class and $class = ref $class;
    my $self = {
	distribution => $ENV{MAKING_MODULE_DISTRIBUTION},
    };
    bless $self, $class;
    return $self;
}

sub abstract {
    return 'Provide ad-hoc access to a CPAN repository';
}

sub add_to_cleanup {
    return [ qw{ cover_db xt/author/optionals } ];
}

sub author {
    return 'Tom Wyant (wyant at cpan dot org)';
}

sub build_requires {
    return +{
	'Config'		=> 0,
	'CPAN::Checksums'	=> 0,
	'ExtUtils::MakeMaker'	=> 0,
	'ExtUtils::Manifest'	=> 0,
	'File::Find'		=> 0,
	'File::Copy'		=> 0,
	'File::Glob'		=> 0,
	'IO::Compress::Gzip'	=> 0,
	'Pod::Usage'		=> 0,
	'POSIX'			=> 0,
	'Test2::V0'		=> 0,
	'Test2::Plugin::BailOnFail'	=> 0,
	'Test2::Tools::LoadModule'	=> 0.002,
	'Time::Local'		=> 0,
	lib			=> 0,
    };
}

sub configure_requires {
    return +{
	'CPAN::Checksums'	=> 0,
	'CPAN::Meta'	=> 2.150006,	# Full phases() support
	'Config'	=> 0,
	'Cwd'	=> 0,
	'ExtUtils::Manifest'	=> 0,
	'File::Copy'	=> 0,
	'File::Find'	=> 0,
	'File::Glob'	=> 0,
	'File::Spec'	=> 0,
	'Getopt::Long'	=> 2.33,
	'IO::Compress::Gzip'	=> 0,
	'IO::File'	=> 0,
	'Pod::Usage'	=> 0,
	'Time::Local'	=> 0,
	'lib'	=> 0,
	'strict'	=> 0,
	'warnings'	=> 0,
    };
}

sub dist_name {
    return 'CPAN-Access-AdHoc';
}

sub distribution {
    my ( $self ) = @_;
    return $self->{distribution};
}

sub license {
    return 'perl';
}

sub meta_merge {
    my ( undef, @extra ) = @_;
    return {
	'meta-spec'	=> {
	    version	=> 2,
	},
	dynamic_config	=> 1,
	resources	=> {
	    bugtracker	=> {
		web	=> 'https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc',
		# web	=> 'https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues',
		mailto  => 'wyant@cpan.org',
	    },
	    license	=> 'http://dev.perl.org/licenses/',
	    repository	=> {
		type	=> 'git',
		url	=> 'git://github.com/trwyant/perl-CPAN-Access-AdHoc.git',
		web	=> 'https://github.com/trwyant/perl-CPAN-Access-AdHoc',
	    },
	},
	@extra,
    };
}

sub module_name {
    return 'CPAN::Access::AdHoc';
}

sub no_index {
    return +{
	directory => [ qw{ eg inc mock t xt } ],
    };
}

sub optionals {
    return ( qw{
	CPAN::Mini CPANPLUS App::cpanminus
    } );
}

sub provides {
    my $provides;
    local $@ = undef;

    eval {
	require CPAN::Meta;
	require ExtUtils::Manifest;
	require Module::Metadata;

	my $manifest;
	{
	    local $SIG{__WARN__} = sub {};
	    $manifest = ExtUtils::Manifest::maniread();
	}
	keys %{ $manifest || {} }
	    or return;

	# Skeleton so we can use should_index_file() and
	# should_index_package().
	my $meta = CPAN::Meta->new( {
		name	=> 'Euler',
		version	=> 2.71828,
		no_index	=> no_index(),
	    },
	);

	# The Module::Metadata docs say not to use
	# package_versions_from_directory() directly, but the 'files =>'
	# version of provides() is broken, and has been known to be so
	# since 2014, so it's not getting fixed any time soon. So:

	foreach my $fn ( sort keys %{ $manifest } ) {
	    $fn =~ m/ [.] pm \z /smx
		or next;
	    my $pvd = Module::Metadata->package_versions_from_directory(
		undef, [ $fn ] );
	    foreach my $pkg ( keys %{ $pvd } ) {
		$meta->should_index_package( $pkg )
		    and $meta->should_index_file( $pvd->{$pkg}{file} )
		    and $provides->{$pkg} = $pvd->{$pkg};
	    }
	}

	1;
    } or return;

    return ( provides => $provides );
}

sub requires {
    my ( undef, @extra ) = @_;		# Invocant is unused
##  if ( ! $self->distribution() ) {
##  }
    return +{
	'Archive::Tar'		=> 1.46,	# For COMPRESS_GZIP
	'Archive::Zip'		=> 0,
	'Carp'			=> 0,
	'Config::Tiny'		=> 0,
	# 'CPAN'			=> 0,	# Core module
	'CPAN::DistnameInfo'	=> 0,
	'CPAN::Meta'		=> 0,	# Core since 5.13.10
	'Cwd'			=> 0,
	'Digest::SHA'		=> 0,
	'Encode',		=> 0,
	'Encode::Guess',	=> 0,
	'Exporter'		=> 0,
	'File::chdir'		=> 0,
	'File::HomeDir'		=> 0,
	'File::Path'		=> 2.07,
	'File::Spec'		=> 0,
	'File::Spec::Unix'	=> 0,
	'File::Temp'		=> 0,
	'Getopt::Long'		=> 2.33,
	'HTTP::Date'		=> 0,
	'HTTP::Response'	=> 0,
	'HTTP::Status'		=> 0,
	'IO::Compress::Bzip2'	=> 0,
	'IO::Compress::Gzip'	=> 0,
	'IO::File'		=> 0,
	'IO::Uncompress::Bunzip2'	=> 0,
	'IO::Uncompress::Gunzip'	=> 0,
	'LWP::Protocol'			=> 0,
	'LWP::MediaTypes'		=> 0,
	'LWP::UserAgent'		=> 0,
	'Module::Metadata'		=> 0,	# Core since 5.13.9
	'Module::Pluggable::Object'	=> 0,
	'parent'		=> 0,
	'Safe'			=> 2.32, # Plays well with Devel::Cover
	'Scalar::Util'		=> 0,
	'strict'		=> 0,
	'Time::Local'		=> 0,
	'Text::ParseWords'	=> 0,
	'Time::Local'		=> 0,
	'URI'			=> 0,
	'URI::file'		=> 0,
	constant		=> 0,
	version			=> 0,
	warnings		=> 0,
	@extra,
    };
}

sub requires_perl {
    return 5.010;
}

sub script_files {
    return [
    ];
}

sub version_from {
    return 'lib/CPAN/Access/AdHoc.pm';
}

1;

__END__

=head1 NAME

My::Module::Meta - Information needed to build CPAN::Access::AdHoc

=head1 SYNOPSIS

 use lib qw{ ./inc };
 use My::Module::Meta;
 my $meta = My::Module::Meta->new();
 use YAML;
 print "Required modules:\n", Dump(
     $meta->requires() );

=head1 DETAILS

This module centralizes information needed to build
C<CPAN::Access::AdHoc>. It is private to the C<CPAN::Access::AdHoc>
distribution, and may be changed or retracted without notice.

=head1 METHODS

This class supports the following public methods:

=head2 new

 my $meta = My::Module::Meta->new();

This method instantiates the class.

=head2 abstract

This method returns the distribution's abstract.

=head2 add_to_cleanup

This method returns a reference to an array of files to be added to the
cleanup.

=head2 author

This method returns the name of the distribution author

=head2 build_requires

 use YAML;
 print Dump( $meta->build_requires() );

This method computes and returns a reference to a hash describing the
modules required to build the C<CPAN::Access::AdHoc> distribution,
suitable for use in a F<Build.PL> C<build_requires> key, or a
F<Makefile.PL> C<< {META_MERGE}->{build_requires} >> or
C<BUILD_REQUIRES> key.

=head2 abstract

This method returns the distribution's abstract.

=head2 author

This method returns the name of the distribution author

=head2 configure_requires

 use YAML;
 print Dump( $meta->configure_requires() );

This method returns a reference to a hash describing the modules
required to configure the package, suitable for use in a F<Build.PL>
C<configure_requires> key, or a F<Makefile.PL>
C<< {META_MERGE}->{configure_requires} >> or C<CONFIGURE_REQUIRES> key.

=head2 dist_name

This method returns the distribution name.

=head2 distribution

 if ( $meta->distribution() ) {
     print "Making distribution\n";
 } else {
     print "Not making distribution\n";
 }

This method returns the value of the environment variable
C<MAKING_MODULE_DISTRIBUTION> at the time the object was instantiated.

=head2 license

This method returns the distribution's license.

=head2 meta_merge

 use YAML;
 print Dump( $meta->meta_merge() );

This method returns a reference to a hash describing the meta-data which
has to be provided by making use of the builder's C<meta_merge>
functionality. This includes the C<dynamic_config> and C<resources>
data.

Any arguments will be appended to the generated array.

=head2 license

This method returns the distribution's license.

=head2 meta_merge

 use YAML;
 print Dump( $meta->meta_merge() );

This method returns a reference to a hash describing the meta-data which
has to be provided by making use of the builder's C<meta_merge>
functionality. This includes the C<dynamic_config> and C<resources>
data.

Any arguments will be appended to the generated array.

=head2 module_name

This method returns the name of the module the distribution is based
on.

=head2 no_index

This method returns the names of things which are not to be indexed
by CPAN.

=head2 optionals

 say for My::Module::Meta->optionals();

This static method simply returns the names of the optional modules.

=head2 provides

 use YAML;
 print Dump( [ $meta->provides() ] );

This method attempts to load L<Module::Metadata|Module::Metadata>. If
this succeeds, it returns a C<provides> entry suitable for inclusion in
L<meta_merge()|/meta_merge> data (i.e. C<'provides'> followed by a hash
reference). If it can not load the required module, it returns nothing.

=head2 requires

 use YAML;
 print Dump( $meta->requires() );

This method computes and returns a reference to a hash describing
the modules required to run the C<CPAN::Access::AdHoc>
distribution, suitable for use in a F<Build.PL> C<requires> key, or a
F<Makefile.PL> C<PREREQ_PM> key. Any additional arguments will be
appended to the generated hash. In addition, unless
L<distribution()|/distribution> is true, configuration-specific modules
may be added.

=head2 requires_perl

 print 'This distribution requires Perl ',
     $meta->requires_perl(), "\n";

This method returns the version of Perl required by the distribution.

=head2 script_files

This method returns a reference to an array containing the names of
script files provided by this distribution. This array may be empty.

=head2 version_from

This method returns the name of the distribution file from which the
distribution's version is to be derived.

=head1 ATTRIBUTES

This class has no public attributes.

=head1 ENVIRONMENT

=head2 MAKING_MODULE_DISTRIBUTION

This environment variable should be set to a true value if you are
making a distribution. This ensures that no configuration-specific
information makes it into F<META.yml>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc>,
L<https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues>, or in
electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2022, 2024-2025 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
