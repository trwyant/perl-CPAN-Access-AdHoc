package App::cpanminus;

use 5.008;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_194';


1;

__END__

=head1 NAME

App::cpanminus - Mock cpanminus class.

=head1 SYNOPSIS

 use lib qw{ mock };
 use App::cpanminus;

=head1 DESCRIPTION

This class implements whatever parts of CPAN are needed to test
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the C<CPAN-Access-AdHoc>
distribution. All documentation is for the benefit of the author.

In the event there is no functionality at all here, but the presence of
this module indicates that L<App::cpanminus|App::cpanminus> has been
installed.

=head1 SEE ALSO

L<cpanm|cpanm>

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2014 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
