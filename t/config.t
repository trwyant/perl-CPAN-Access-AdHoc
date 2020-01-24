package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::LoadModule;

use lib qw{ ./mock };

use Cwd();
use File::Spec;
use File::Spec::Unix;
use URI::file;

use constant LOAD_MOCK_ERR	=> 'Mock object required for testing';

load_module_ok 'Config::Tiny'		# Load mock object
    or bail_out( LOAD_MOCK_ERR );
load_module_ok 'CPAN'			# Load mock object
    or bail_out( LOAD_MOCK_ERR );
load_module_ok 'CPAN::Mini'		# Load mock object
    or bail_out( LOAD_MOCK_ERR );
load_module_ok 'CPANPLUS::Configure'	# Load mock object
    or bail_out( LOAD_MOCK_ERR );
load_module_ok 'File::HomeDir'		# Load mock object.
    or bail_out( LOAD_MOCK_ERR );
load_module_ok 'CPAN::Access::AdHoc'
    or bail_out( 'CPAN::Access::AdHoc does not load using mock objects' );

# Make sure mock objects work as desired.

# Compute file:// URL for mock repository.
my $default_mock_repos = URI::file->new( Cwd::abs_path( 'mock/repos' )
    )->as_string();

# Mock File::HomeDir

is( File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ),
'mock/Perl/CPAN-Access-AdHoc',
q{File::HomeDir->my_dist_config( 'CPAN-Access-AdHoc' ) returns 'mock/Perl/CPAN-Access-AdHoc'});

{
    no warnings qw{ once };

    local $File::HomeDir::BASE = 'mock';

    is( File::HomeDir->my_dist_config( 'CPAN' ), 'mock/CPAN',
	q{File::HomeDir base directory can be overridden} );
}

# Mock Config::Tiny

is( Config::Tiny->new(), {}, 'Config::Tiny->new() returns empty hash' );

is( Config::Tiny->read( 'fu.bar' ), {},
    q{Config::Tiny->read( 'fu.bar' ) returns an empty hash by default} );

{
    local $Config::Tiny::CONFIG = {
	fu	=> 'bar',
    };

    is( Config::Tiny->read( 'fu.bar' ), { fu => 'bar' },
	q{Config::Tiny->read( 'fu.bar' ) can return a custom config} );
}

is( Config::Tiny->read( 'fu.bar' ), {},
    q{Config::Tiny->read( 'fu.bar' ) reverts if changes are localized} );

# Mock CPAN::Mini

is( { CPAN::Mini->read_config() }, { local => 'mock/repos' },
    q{CPAN::Mini->read_config() returns 'mock/repos'} );

# Mock CPAN

CPAN::HandleConfig->load();

{
    no warnings qw{ once };
    is $CPAN::Config, {
	urllist	=> [ $default_mock_repos ],
    }, "CPAN::HandleConfig loads urllist [ '$default_mock_repos' ]";
}

# Mock CPANPLUS

is(
    CPANPLUS::Configure->new(),
    {
	hosts	=> [
	    {
		scheme	=> 'file',
		host	=> '',
		path	=> Cwd::abs_path( 'mock/repos' ),
	    },
	],
    }, "CPANPLUS::Configure loads hosts [ '$default_mock_repos' ]" );

# Now test configuration of the CPAN::Access::AdHoc object.

my $cad = CPAN::Access::AdHoc->new(
    cpan	=> 'http://someone/',
);

is $cad->default_cpan_source(),
    [ qw{ 
	CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini
	CPAN::Access::AdHoc::Default::CPAN::cpanm
	CPAN::Access::AdHoc::Default::CPAN::CPAN
	CPAN::Access::AdHoc::Default::CPAN::CPANPLUS
	} ],
    'Confirm default_cpan_source() is set up correctly';

is $cad->cpan(), 'http://someone/', 'Explicit cpan';

{
    local $Config::Tiny::CONFIG = {
	_	=> {
	    cpan	=> 'file:///home/foo/bar',
	},
    };

    $cad = CPAN::Access::AdHoc->new();

    is $cad->cpan(), 'file:///home/foo/bar/', 'cpan from configuration';

}

{

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source	=> 'CPAN::Mini',
    );

    ( my $expect = $default_mock_repos ) =~ s{ (?<! / ) \z }{/}smx;

    is $cad->cpan(), $expect,
	'cpan from CPAN::Mini';
}

{
    local $CPAN::CONFIG = {
	urllist	=> [ qw{
	    http://somewhere/out/there/
	    file://here/and/there
	    } ],
    };

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source => 'CPAN',
    );

    is $cad->cpan(), 'file://here/and/there/',
	'cpan from CPAN prefers file: scheme';
}

{
    local $CPAN::CONFIG = {
	urllist => [ qw{
	    http://somewhere/out/there/
	    http://here/and/there
	    } ],
    };

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source => 'CPAN',
    );

    is $cad->cpan(), 'http://somewhere/out/there/',
	'cpan from CPAN takes first if not file: scheme';
}

{
    local $ENV{PERL_CPANM_OPT} =
	'--mirror http://somewhere/out/there/ --mirror file:///here/and/there --fubar';

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source => 'cpanm',
    );

    is $cad->cpan(), 'file:///here/and/there/',
	'cpan from cpanm prefers file: scheme';
}

{
    local $CPANPLUS::Configure::CONFIG = {
	hosts	=> [
	    {
		scheme	=> 'http',
		host	=> 'somewhere',
		path	=> '/out/there/',
	    },
	    {
		scheme	=> 'file',
		host	=> 'here',
		path	=> '/and/there',
	    },
	],
    };

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source => 'CPANPLUS',
    );

    is $cad->cpan(), 'file://here/and/there/',
	'cpan from CPANPLUS prefers file: scheme';

}

{
    local $CPANPLUS::Configure::CONFIG = {
	hosts	=> [
	    {
		scheme	=> 'http',
		host	=> 'somewhere',
		path	=> '/out/there/',
	    },
	    {
		scheme	=> 'http',
		host	=> 'here',
		path	=> '/and/there',
	    },
	],
    };

    $cad = CPAN::Access::AdHoc->new(
	default_cpan_source => 'CPANPLUS',
    );

    is $cad->cpan(), 'http://somewhere/out/there/',
	'cpan from CPANPLUS takes first if not file: scheme';

}

done_testing;

1;

# ex: set textwidth=72 :
