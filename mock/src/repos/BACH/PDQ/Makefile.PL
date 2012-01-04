use 5.006;	# for 'our'.

use strict;
use warnings;

use ExtUtils::MakeMaker 6.56;

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my %args = (
    NAME => 'PDQ',
    VERSION_FROM => 'lib/PDQ.pm',
    PREREQ_PM => {
	'Carp'		=> 0,
	'strict'	=> 0,
	'warnings'	=> 0,
    },
    PL_FILES => {},	# Prevent old MakeMaker from running Build.PL
    dist => {
	DIST_DEFAULT	=> 'zipdist',
    },
    AUTHOR => 'J. S. Bach (bach@cpan.org)',
    ABSTRACT => 'PDQ Bach',
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
##	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Encode-RAD50',
	resources => {
	    license => 'http://dev.perl.org/licenses/',
	},
    },
);

WriteMakefile (%args);
