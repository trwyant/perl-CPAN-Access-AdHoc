use 5.010;	# for 'our'.

use strict;
use warnings;

use ExtUtils::MakeMaker 6.56;

# ( my $mmv = ExtUtils::MakeMaker->VERSION ) =~ s/_//g;

my %args = (
    NAME => 'Johann',
    VERSION_FROM => 'lib/Johann.pm',
    PREREQ_PM => {
	'Carp'		=> 0,
	'strict'	=> 0,
	'warnings'	=> 0,
    },
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    dist => {
	COMPRESS => 'bzip2 -f',
	SUFFIX => 'bz2',
    },
    AUTHOR => 'J. S. Bach (bach@cpan.org)',
    ABSTRACT => 'Johann Sebastian Bach',
    LICENSE => 'perl',
    BUILD_REQUIRES => {
	'Test::More'	=> 0.88,
    },
    MIN_PERL_VERSION	=> 5.006002,
    META_ADD => {
	no_index => {
	    directory => [ qw{ inc t xt } ],
	},
    },
    META_MERGE => {
##	bugtracker => 'https://github.com/trwyant/perl-CPAN-Access-AdHoc/issues/Public/Dist/Display.html?Name=Encode-RAD50',
	provides => {
	    'Johann'	=> {
		file	=> 'lib/Johann.pm',
		version	=> '0.001',
	    },
	},
	resources => {
	    license => 'http://dev.perl.org/licenses/',
	},
    },
);

WriteMakefile (%args);
