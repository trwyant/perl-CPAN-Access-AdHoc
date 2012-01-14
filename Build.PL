use strict;
use warnings;

use 5.008;

use lib qw{ inc };

use Config;
use Module::Build;
use My::Module::Build;
use My::Module::Meta;

$Config{useperlio}
    or die "PerlIO is required\n";

(my $mbv = Module::Build->VERSION()) =~ s/_//g;

my $meta = My::Module::Meta->new();

my %args = (
    dist_author => 'Tom Wyant (wyant at cpan dot org)',
    dist_abstract => 'Provide ad-hoc access to a CPAN repository',
    module_name => 'CPAN::Access::AdHoc',
    build_requires => $meta->build_requires(),
    requires => $meta->requires(
	perl => $meta->requires_perl(),
    ),
    license => 'perl',
#   add_to_cleanup	=> [ qw{ mock/repos/ } ],
    add_to_cleanup =>[ qw{ xt/author/optionals } ],
    PL_files => {
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
);

$mbv >= 0.28 and $args{meta_merge} = {
    no_index => {
	directory => [qw{ inc mock t xt }],
    },
    resources => {
	bugtracker => 'https://rt.cpan.org/Public/Dist/Display.html?Name=CPAN-Access-AdHoc',
    },
};

$mbv >= 0.34
    and $args{auto_configure_requires} = 0;	# Don't require Module::Build

my $bldr = My::Module::Build->new (%args);

$bldr->create_build_script ();
