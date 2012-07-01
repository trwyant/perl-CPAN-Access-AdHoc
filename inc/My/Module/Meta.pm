package My::Module::Meta;

use 5.008;

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
	'Test::More'		=> 0.88,	# Because of done_testing().
    };
}

sub distribution {
    my ( $self ) = @_;
    return $self->{distribution};
}

sub requires {
    my ( $self, @extra ) = @_;
##  if ( ! $self->distribution() ) {
##  }
    return +{
	'Archive::Tar'		=> 0,
	'Archive::Zip'		=> 0,
	'base'			=> 0,
	'Carp'			=> 0,
	'Config::Tiny'		=> 0,
	'CPAN::Meta'		=> 0,
	'Cwd'			=> 0,
	'Digest::SHA'		=> 0,
	'File::HomeDir'		=> 0,
	'File::Path'		=> 2.07,
	'File::Spec'		=> 0,
	'File::Spec::Unix'	=> 0,
	'Getopt::Long'		=> 2.33,
	'HTTP::Date'		=> 0,
	'HTTP::Response'	=> 0,
	'IO::File'		=> 0,
	'IO::Uncompress::Bunzip2'	=> 0,
	'IO::Uncompress::Gunzip'	=> 0,
	'LWP::Protocol'			=> 0,
	'LWP::MediaTypes'		=> 0,
	'LWP::UserAgent'		=> 0,
	'Module::Pluggable::Object'	=> 0,
	'URI'			=> 0,
	'URI::file'		=> 0,
	'Safe'			=> 2.32, # Plays well with Devel::Cover
	'strict'		=> 0,
	'Text::ParseWords'	=> 0,
	'Time::Local'		=> 0,
	'warnings'		=> 0,
	@extra,
    };
}

sub requires_perl {
    return 5.008;
}


1;

__END__

=head1 NAME

My::Module::Meta - Information needed to build CPAN::Access::AdHoc

=head1 SYNOPSIS

 use lib qw{ inc };
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
