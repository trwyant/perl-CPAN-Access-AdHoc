package main;

use strict;
use warnings;

BEGIN {
    eval {require Test::Spelling};
    $@ and do {
	print "1..0 # skip Test::Spelling not available.\n";
	exit;
    };
    Test::Spelling->import();
}

add_stopwords (<DATA>);

all_pod_files_spelling_ok ();

1;
__DATA__
archiver
ASCIIbetical
checksum
checksums
cpan
cpanm
cpanminus
CPANPLUS
GPL
hocery
indices
instantiator
merchantability
metadata
subclasses
un
url
Wyant
