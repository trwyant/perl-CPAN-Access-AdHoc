use strict;
use warnings;

use 5.010;

use lib qw{ ./inc };

use Config;
use Module::Build;
use My::Module::Build;
use My::Module::Meta;

$Config{useperlio}
    or die "PerlIO is required\n";

( my $mbv = Module::Build->VERSION() ) =~ s/_//g;

my $meta = My::Module::Meta->new();

my %args = (
    add_to_cleanup	=> [ qw{ cover_db xt/author/optionals } ],
    build_requires	=> $meta->build_requires(),
    configure_requires	=> $meta->configure_requires(),
    dist_abstract	=> $meta->abstract(),
    dist_author	=> $meta->author(),
    dist_name	=> $meta->dist_name(),
    license	=> $meta->license(),
    module_name	=> $meta->module_name(),
    PL_files => {
#	'Build_Repos.PL' => [ qw{
#	    mock/repos/authors/01mailrc.txt.gz
#	    mock/repos/authors/id/B/BA/BACH/CHECKSUMS
#	    mock/repos/authors/id/B/BA/BACH/Johann-0.001.tar.bz2
#	    mock/repos/authors/id/B/BA/BACH/PDQ-0.000_01.zip
#	    mock/repos/authors/id/M/ME/MENUHIN/CHECKSUMS
#	    mock/repos/authors/id/M/ME/MENUHIN/Yehudi-0.001.tar.gz
#	    mock/repos/modules/02packages.details.txt
#	    mock/repos/modules/02packages.details.txt.gz
#	    mock/repos/modules/03modlist.data.gz
#	    mock/repos/mtimes.dat
#	    } ],
    },
    requires	=> $meta->requires(
	perl	=> $meta->requires_perl(),
    ),
);

if ( $mbv >= 0.28 ) {
    $args{meta_merge} = $meta->meta_merge();
    $args{meta_add} = {
	no_index	=> $meta->no_index(),
    };
}

$mbv >= 0.34
    and $args{auto_configure_requires} = 0;	# Don't require Module::Build

my $bldr = My::Module::Build->new( %args );

$bldr->create_build_script();

# ex: set textwidth=72 :
