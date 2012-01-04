package Config::Tiny;

use 5.008;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_01';

our $CONFIG ||= {};

sub new {
    my ( $class ) = @_;
    # Because our configuration file may or may not exist under testing
    # conditions, new() also needs to return $CONFIG, so that we get the
    # desired result no matter which path we take through the code.
    return $CONFIG;
}

sub read {
    my ( $class, $file ) = @_;
    return $CONFIG;
}


1;

__END__

=head1 NAME

Config::Tiny - Mock Config::Tiny object.

=head1 SYNOPSIS

 use lib qw{ mock };
 use Config::Tiny;
 
 my $empty = Config::Tiny->new();
 my $config = Config::Tiny->read( 'foo.ini' );

=head1 DESCRIPTION

This class implements whatever parts of Config::Tiny are needed to test
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the C<CPAN-Access-AdHoc>
distribution. All documentation is for the benefit of the author.

=head1 METHODS

This class supports the following public methods:

=head2 new

This static method simply returns an empty hash.

=head2 read

This static method returns the contents of C<$Config::Tiny::CONFIG>,
which are assumed to be a hash reference, and which defaults to an empty
hash.

=head1 SEE ALSO

The real L<Config::Tiny|Config::Tiny>.

=head1 SUPPORT

Support is by the author. Please file bug reports at
L<http://rt.cpan.org>, or in electronic mail to the author.

=head1 AUTHOR

Thomas R. Wyant, III F<wyant at cpan dot org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Thomas R. Wyant, III

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl 5.10.0. For more details, see the full text
of the licenses in the directory LICENSES.

This program is distributed in the hope that it will be useful, but
without any warranty; without even the implied warranty of
merchantability or fitness for a particular purpose.

=cut

# ex: set textwidth=72 :
