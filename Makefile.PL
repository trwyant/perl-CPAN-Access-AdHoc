use 5.008;

use strict;
use warnings;

use lib qw{ inc };

use Config;
use ExtUtils::MakeMaker;
use My::Module::Meta;

$Config{useperlio}
    or die "PerlIO is required\n";

(my $mmv = ExtUtils::MakeMaker->VERSION) =~ s/_//g;

my $meta = My::Module::Meta->new();

my %args = (
    NAME => 'CPAN::Access::AdHoc',
    VERSION_FROM => 'lib/CPAN/Access/AdHoc.pm',
    PREREQ_PM => $meta->requires(),
    PL_FILES => {
	'Build_Repos.PL' => [ qw{
	    mock/repos/authors/01mailrc.txt.gz
	    mock/repos/authors/id/B/BA/BACH/CHECKSUMS
	    mock/repos/authors/id/B/BA/BACH/Johann-0.001.tar.bz2
	    mock/repos/authors/id/B/BA/BACH/PDQ-0.000_01.zip
	    mock/repos/authors/id/M/ME/MENUHIN/CHECKSUMS
	    mock/repos/authors/id/M/ME/MENUHIN/Yehudi-0.001.tar.gz
	    mock/repos/modules/02packages.details.txt
	    mock/repos/modules/02packages.details.txt.gz
	    mock/repos/modules/03modlist.data.gz
	    mock/repos/mtimes.dat
	    } ],
    },
    'dist' => {COMPRESS => 'gzip', SUFFIX => '.gz'},
#   realclean => { FILES => join ' ', qw{ mock/repos/ } },
    AUTHOR => 'Tom Wyant (wyant at cpan dot org)',
    ABSTRACT => 'Provide ad-hoc access to a CPAN repository',
);

$mmv >= 6.31 and $args{LICENSE} = 'perl';

$mmv >= 6.4501 and do {
    $args{META_ADD} = {
	no_index => {
	    directory => [ qw{ inc mock t xt } ],
	},
    };
    $args{META_MERGE} = {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?CPAN-Access-AdHoc',
	resources => {
	    license => 'http://dev.perl.org/licenses/',
	},
    };
};

$mmv >= 6.4701 and $args{MIN_PERL_VERSION} = $meta->requires_perl();

$mmv >= 6.5501
    and $args{BUILD_REQUIRES} = $meta->build_requires()
    or $mmv >= 6.4501
    and $args{META_MERGE}{build_requires} = $meta->build_requires();

WriteMakefile (%args);

