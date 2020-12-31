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

sub build_requires {
    return +{
	'ExtUtils::MakeMaker'	=> 0,
	'ExtUtils::Manifest'	=> 0,
	'File::Find'		=> 0,
	'File::Copy'		=> 0,
	'File::Glob'		=> 0,
	'IO::Compress::Gzip'	=> 0,
	'Pod::Usage'		=> 0,
	'Test2::V0'		=> 0,
	'Test2::Plugin::BailOnFail'	=> 0,
	'Test2::Tools::LoadModule'	=> 0.002,
	'Time::Local'		=> 0,
    };
}

sub distribution {
    my ( $self ) = @_;
    return $self->{distribution};
}

sub meta_merge {
    return {
	'meta-spec'	=> {
	    version	=> 2,
	},
	no_index	=> {
	    directory	=> [ qw{ inc t xt } ],
	},
	resources	=> {
#	    bugtracker	=> {
#                web	=> 'https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues',
#                mailto  => 'wyant@cpan.org',
#            },
	    license	=> 'http://dev.perl.org/licenses/',
#	    repository	=> {
#		type	=> 'git',
#		url	=> 'git://github.com/trwyant/perl-CPAN-Access-AdHoc.git',
#		web	=> 'https://github.com/trwyant/perl-CPAN-Access-AdHoc',
#	    },
	}
    };
}

sub make_optional_modules_tests {
    eval {
	require Test::Without::Module;
	1;
    } or return;
    my $dir = 'xt/author/optionals';
    -d $dir
	or mkdir $dir
	or die "Can not create $dir: $!\n";
    opendir my $dh, 't'
	or die "Can not access t/: $!\n";
    while ( readdir $dh ) {
	m/ \A [.] /smx
	    and next;
	m/ [.] t \z /smx
	    or next;
	my $fn = "$dir/$_";
	-e $fn
	    and next;
	print "Creating $fn\n";
	open my $fh, '>:encoding(utf-8)', $fn
	    or die "Can not create $fn: $!\n";
	print { $fh } <<"EOD";
package main;

use strict;
use warnings;

use lib qw{ ./inc };

use My::Module::Meta;
use Test2::Tools::LoadModule;

load_module_or_skip_all 'Test::Without::Module', undef, [
    My::Module::Meta->optionals() ];

do 't/$_';

1;

__END__

# ex: set textwidth=72 :
EOD
    }
    closedir $dh;

    return $dir;
}

sub optionals {
    return ( qw{
	CPAN::Mini CPANPLUS App::cpanminus
    } );
}

sub requires {
    my ( undef, @extra ) = @_;		# Invocant is unused
##  if ( ! $self->distribution() ) {
##  }
    return +{
	'Archive::Tar'		=> 0,
	'Archive::Zip'		=> 0,
	'Carp'			=> 0,
	'Config::Tiny'		=> 0,
	'CPAN'			=> 0,	# Core module
	'CPAN::DistnameInfo'	=> 0,
	'CPAN::Meta'		=> 0,
	'Cwd'			=> 0,
	'Digest::SHA'		=> 0,
	'File::chdir'		=> 0,
	'File::HomeDir'		=> 0,
	'File::Path'		=> 2.07,
	'File::Spec'		=> 0,
	'File::Spec::Unix'	=> 0,
	'Getopt::Long'		=> 2.33,
	'HTTP::Date'		=> 0,
	'HTTP::Response'	=> 0,
	'HTTP::Status'		=> 0,
	'IO::File'		=> 0,
	'IO::Uncompress::Bunzip2'	=> 0,
	'IO::Uncompress::Gunzip'	=> 0,
	'LWP::Protocol'			=> 0,
	'LWP::MediaTypes'		=> 0,
	'LWP::UserAgent'		=> 0,
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
	'version'		=> 0,
	'warnings'		=> 0,
	@extra,
    };
}

sub requires_perl {
    return 5.010;
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

=head2 build_requires

 use YAML;
 print Dump( $meta->build_requires() );

This method computes and returns a reference to a hash describing the
modules required to build the C<CPAN::Access::AdHoc> distribution,
suitable for use in a F<Build.PL> C<build_requires> key, or a
F<Makefile.PL> C<< {META_MERGE}->{build_requires} >> or
C<BUILD_REQUIRES> key.

=head2 distribution

 if ( $meta->distribution() ) {
     print "Making distribution\n";
 } else {
     print "Not making distribution\n";
 }

This method returns the value of the environment variable
C<MAKING_MODULE_DISTRIBUTION> at the time the object was instantiated.

=head2 make_optional_modules_tests

 My::Module::Meta->make_optional_modules_tests()

This static method creates the optional module tests. These are stub
files in F<xt/author/optionals/> that use C<Test::Without::Module> to
hide all the optional modules and then invoke the normal tests in F<t/>.
The aim of these tests is to ensure that we get no test failures if the
optional modules are missing.

This method is idempotent; that is, it only creates the directory and
the individual stub files if they are missing.

On success this method returns the name of the optional tests directory.
If C<Test::Without::Module> can not be loaded this method returns
nothing. If the directory or any file can not be created, an exception
is thrown.

=head2 meta_merge

 use YAML;
 print Dump( $meta->meta_merge() );

This method returns a reference to a hash describing the meta-data which
has to be provided by making use of the builder's C<meta_merge>
functionality. This includes the C<dynamic_config>, C<no_index> and
C<resources> data.

=head2 optionals

 say for My::Module::Meta->optionals();

This static method simply returns the names of the optional modules.

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

=head1 ATTRIBUTES

This class has no public attributes.

=head1 ENVIRONMENT

=head2 MAKING_MODULE_DISTRIBUTION

This environment variable should be set to a true value if you are
making a distribution. This ensures that no configuration-specific
information makes it into F<META.yml>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<https:rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2020 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
