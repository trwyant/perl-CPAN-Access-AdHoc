use 5.010;

use strict;
use warnings;

use lib qw{ ./inc };

use Config;
use ExtUtils::MakeMaker;
use My::Module::Meta;

$Config{useperlio}
    or die "PerlIO is required\n";

( my $mmv = ExtUtils::MakeMaker->VERSION ) =~ s/_//g;

my $meta = My::Module::Meta->new();

my %args = (
    ABSTRACT	=> $meta->abstract(),
    AUTHOR	=> $meta->author(),
    DISTNAME	=> $meta->dist_name(),
    EXE_FILES	=> $meta->script_files(),
    NAME	=> $meta->module_name(),
    PREREQ_PM	=> $meta->requires(),
    PL_FILES => {
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
    realclean	=> {
	FILES => join( ' ', @{ $meta->add_to_cleanup() } ),
    },
    VERSION_FROM	=> $meta->version_from(),
);

$mmv >= 6.31
    and $args{LICENSE} = $meta->license();

if ( $mmv >= 6.4501 ) {
    $args{META_ADD} = {
	no_index => $meta->no_index(),
    };
    $args{META_MERGE} = $meta->meta_merge( $meta->provides() );
}

$mmv >= 6.4701
    and $args{MIN_PERL_VERSION} = $meta->requires_perl();


if ( $mmv >= 6.52 ) {
    $args{BUILD_REQUIRES} = $meta->build_requires();
    $args{CONFIGURE_REQUIRES} = $meta->configure_requires();
} elsif ( $mmv >= 6.5501 ) {
    $args{BUILD_REQUIRES} = $meta->build_requires();
    $args{META_MERGE}{configure_requires} = $meta->configure_requires();
} elsif ( $mmv >= 6.4501 ) {
    $args{META_MERGE}{build_requires} = $meta->build_requires();
    $args{META_MERGE}{configure_requires} = $meta->configure_requires();
} else {
    foreach my $method ( qw{ configure_requires build_requires } ) {
	my $req = $meta->$method();
	foreach my $key ( keys %{ $req } ) {
	    exists $args{PREREQ_PM}{$key}
		or $args{PREREQ_PM}{$key} = $req->{$key};
	}
    }
}

WriteMakefile( %args );

sub MY::postamble {
    my ( $self, @args ) = @_;

    my $authortest = $self->test_via_harness(
	'$(FULLPERLRUN)', '$(AUTHORTEST_FILES)' );
    $authortest =~ s/ \s+ \z //smx;
    $authortest =~ s/ \A \s+ //smx;
    chomp $authortest;

    return <<"EOD";

AUTHORTEST_FILES = t/*.t xt/author/*.t xt/author/optionals/*.t

authortest :: pure_all
	\$(FULLPERLRUN) "-Iinc" "-MMy::Module::Meta" "-e" "My::Module::Meta->make_optional_modules_tests()"
	AUTHOR_TESTING=1 $authortest

testcover :: pure_all
	cover -test
EOD
}

# ex: set textwidth=72 :
