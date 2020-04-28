package main;

use 5.010;

use strict;
use warnings;

use Test2::V0;
use Test2::Plugin::BailOnFail;
use Test2::Tools::LoadModule;

my @expect_default_class_methods = qw{ get_clean_checksums get_cpan_url };
my @expect_archive_methods = qw{
    new base_directory extract get_item_content get_item_mtime
    __handle_http_response item_present list_contents metadata
    path wrap_archive write
};

load_module_ok 'CPAN::Access::AdHoc::Util';

can_ok     'CPAN::Access::AdHoc::Util' => [ qw{
    __attr __cache __expand_distribution_path __guess_media_type
    __load __whinge __wail __weep
} ];

load_module_ok 'CPAN::Access::AdHoc::Archive';

can_ok     'CPAN::Access::AdHoc::Archive' => [ qw{
    archive metadata path
} ];

load_module_ok 'CPAN::Access::AdHoc::Archive::Null';

can_ok     'CPAN::Access::AdHoc::Archive::Null' => \@expect_archive_methods;

load_module_ok 'CPAN::Access::AdHoc::Archive::Tar';

can_ok     'CPAN::Access::AdHoc::Archive::Tar' => \@expect_archive_methods;

load_module_ok 'CPAN::Access::AdHoc::Archive::Zip';

can_ok     'CPAN::Access::AdHoc::Archive::Zip' => \@expect_archive_methods;

load_module_ok 'CPAN::Access::AdHoc::Default::CPAN';

load_module_ok 'CPAN::Access::AdHoc::Default::CPAN::CPAN';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPAN' =>
	    \@expect_default_class_methods;

load_module_ok 'CPAN::Access::AdHoc::Default::CPAN::cpanm';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::cpanm' =>
	    \@expect_default_class_methods;

load_module_ok 'CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini' =>
	    \@expect_default_class_methods;

load_module_ok 'CPAN::Access::AdHoc::Default::CPAN::CPANPLUS';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPANPLUS' =>
	    \@expect_default_class_methods;

load_module_ok 'CPAN::Access::AdHoc';

can_ok     'CPAN::Access::AdHoc' => [
    qw{ config cpan __debug default_cpan_source } ];

all_modules_tried_ok;

done_testing;

1;

# ex: set textwidth=72 :
