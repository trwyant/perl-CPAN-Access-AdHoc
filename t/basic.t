package main;

use 5.008;

use strict;
use warnings;

use Test::More 0.88;	# Because of done_testing();

use lib qw{ mock };

my @default_class_methods = qw{ get_default };
my @expect_archive_methods = qw{
    new base_directory get_item_content item_present list_contents
    metadata
};

require_ok 'CPAN::Access::AdHoc::Util'
    or BAIL_OUT 'CPAN::Access::AdHoc::Util is required';

can_ok     'CPAN::Access::AdHoc::Util' => qw{
    __attr __expand_distribution_path __guess_media_type
    __load __whinge __wail __weep
};

require_ok 'CPAN::Access::AdHoc::Archive'
    or BAIL_OUT 'CPAN::Access::AdHoc::Archive is required';

can_ok     'CPAN::Access::AdHoc::Archive' => qw{
    archive metadata path
};

require_ok 'CPAN::Access::AdHoc::Archive::Null'
    or BAIL_OUT 'CPAN::Access::AdHoc::Archive::Null is required';

can_ok     'CPAN::Access::AdHoc::Archive::Null' => @expect_archive_methods;

require_ok 'CPAN::Access::AdHoc::Archive::Tar'
    or BAIL_OUT 'CPAN::Access::AdHoc::Archive::Tar is required';

can_ok     'CPAN::Access::AdHoc::Archive::Tar' => @expect_archive_methods;

require_ok 'CPAN::Access::AdHoc::Archive::Zip'
    or BAIL_OUT 'CPAN::Access::AdHoc::Archive::Zip is required';

can_ok     'CPAN::Access::AdHoc::Archive::Zip' => @expect_archive_methods;

require_ok 'CPAN::Access::AdHoc::Default::CPAN::CPAN'
    or BAIL_OUT 'CPAN::Access::AdHoc::Default::CPAN::CPAN is required';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPAN' => @default_class_methods;

require_ok 'CPAN::Access::AdHoc::Default::CPAN::cpanm'
    or BAIL_OUT 'CPAN::Access::AdHoc::Default::CPAN::cpanm is required';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::cpanm' => @default_class_methods;

require_ok 'CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini'
    or BAIL_OUT 'CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini is required';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPAN::Mini' => @default_class_methods;

require_ok 'CPAN::Access::AdHoc::Default::CPAN::CPANPLUS'
    or BAIL_OUT 'CPAN::Access::AdHoc::Default::CPAN::CPANPLUS is required';

can_ok     'CPAN::Access::AdHoc::Default::CPAN::CPANPLUS' => @default_class_methods;

require_ok 'CPAN::Access::AdHoc'
    or BAIL_OUT 'CPAN::Access::AdHoc is required';

can_ok     'CPAN::Access::AdHoc' => qw{ config cpan __debug default_cpan_source };

done_testing;

1;

# ex: set textwidth=72 :
