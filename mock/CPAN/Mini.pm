package CPAN::Mini;

use 5.008;

use strict;
use warnings;

use Carp ();

our $VERSION = '0.000_01';

our $LOCAL ||= 'mock/repos';

sub read_config {
    return (
	local	=> $LOCAL,
    );
}

1;

__END__

=head1 NAME

CPAN::Mini - Mock CPAN::Mini class

=head1 SYNOPSIS

 use lib qw{ mock };
 use CPAN::Mini;
 
 my %config = CPAN::Mini->read_config();
 print "Local repository is $config{local};

=head1 DESCRIPTION

This class implements whatever parts of CPAN::Mini are needed to test
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the C<CPAN-Access-AdHoc>
distribution. All documentation is for the benefit of the author.

=head1 METHODS

This class supports the following public methods:

=head2 read_config

This method returns a L<CPAN::Mini|CPAN::Mini> configuration hash, with
whatever keys the author plans to use. At the moment, the only key
supplied is C<local>. This takes the value of C<$CPAN::Mini::LOCAL>,
which defaults to F<mock/repos>.

=head1 SEE ALSO

The real L<CPAN::Mini|CPAN::Mini>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012-2013 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
