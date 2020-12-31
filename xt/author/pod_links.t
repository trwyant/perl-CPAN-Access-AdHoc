package main;

use strict;
use warnings;

use Test2::V0;
use Test2::Tools::LoadModule;

BEGIN {	# Need BEGIN block so compiler sees constants.
    load_module_or_skip_all 'Test::Pod::LinkCheck::Lite', undef, [ ':const' ];
}

Test::Pod::LinkCheck::Lite->new(
    # TODO - drop when published to GitHub
    ignore_url		=> qr< \A https://github.com/ >smx,
    prohibit_redirect	=> ALLOW_REDIRECT_TO_INDEX,
)->all_pod_files_ok();

done_testing;

1;

# ex: set textwidth=72 :
