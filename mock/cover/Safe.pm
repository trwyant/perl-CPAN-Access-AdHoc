package Safe;

use 5.006002;

use strict;
use warnings;

use Carp;

our $VERSION = '0.000_01';

sub new {
    my ( $class, $root, $mask ) = @_;
    return bless {}, ref $class || $class;
}

sub share {
    return;
}

sub share_from {
    return;
}

sub reval {
    my ( $self, $expr, $strict ) = @_;
    $strict = $strict ? 'use' : 'no';
    return eval sprintf "%s strict;\n%s", $strict, $expr;
}

1;

__END__

=head1 NAME

Safe - Mock Safe class.

=head1 SYNOPSIS

 use lib qw{ mock/safe };
 my $sandbox = Safe->new();
 print $sandbox->reval( '"Hello, sailor!"' );

=head1 DESCRIPTION

Package implements whatever parts of C<Safe> are necessary to test the
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc> module. It is not placed
directly into the F<mock/> directory, because during normal testing we
want to use the real C<Safe> module.

But the real C<Safe> module and the real C<Devel::Cover> module do not
play nicely together, so some other arrangement was necessary.

The intended way to make this work is to have F<mock/safe> in C<@INC>
when running coverage tests. If using L<Module::Build|Module::Build>,
this is as easy as overriding C<ACTION_testcover()>, having the override
insert F<mock/safe/> in C<@INC> (after localizing, of course), and then
call C<< $self->SUPER::ACTION_testcover() >>.

=head1 METHODS

This class supports the following public methods:

=head2 new

 use lib qw{ meta/safe/ };
 my $sandbox = Safe->new();

This static method simply return a blessed hash reference. Any arguments
are ignored.

=head2 share

 $sandbox->share( '&compute' );

This method simply returns.

=head2 share_from

 $sandbox->share_from( 'Foo::Bar' => [ '&compute' ] );

This method simply returns.

=head2 reval

 my $rslt = $sandbox->reval( 'fubar()' );

This method does a stringy C<eval> on its argument, and returns the
result. You have to check C<$@> to see if an exception occurred, but
that's the way the real C<Safe> module works.

=head1 SEE ALSO

The real L<Safe|Safe> module.

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
