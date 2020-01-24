package main;

use strict;
use warnings;

use Test2::Tools::LoadModule;

load_module_or_skip_all 'Test::Spelling';

add_stopwords( <DATA> );

all_pod_files_spelling_ok();

1;
__DATA__
archiver
ASCIIbetical
checksum
checksums
cpan
CPAN
cpanm
cpanminus
CPANPLUS
Foy
GPL
hocery
indices
instantiator
invocant
merchantability
metadata
Miaygawa
OO
Rezic
SQLite
Signes
Slaven
stringifies
subclasses
Tatsuhiko
un
unpackaged
uri
url
Walde
Weyl
Wyant
