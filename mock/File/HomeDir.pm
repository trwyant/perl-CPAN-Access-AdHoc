package File::HomeDir;

use 5.008;

use strict;
use warnings;

use File::Spec::Unix;

our $VERSION = '0.000_194';

our $BASE ||= 'mock/Perl';

sub my_dist_config {
    my ( $class, $dist ) = @_;
    return File::Spec::Unix->catdir( $BASE, $dist );
}


1;

__END__

=head1 NAME

File::HomeDir - Mock File::HomeDir class

=head1 SYNOPSIS

 use lib qw{ mock };
 use File::HomeDir;
 
 my $config_dir = File::HoneDir->my_dist_config( 'Foo-Bar' );
 print "Foo-Bar dist config directory is $config_dir\n";

=head1 DESCRIPTION

This class implements whatever parts of File::HomeDir are needed to test
L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the
C<CPAN-Access-AdHoc> distribution. All documentation is for the benefit
of the author.

=head1 METHODS

This class supports the following public methods:

=head2 my_dist_config

This method is intended to mock the real L<File::HomeDir|File::HomeDir>
C<my_dist_config()>, and behaves similarly. But it returns a directory
under C<$File::HomeDir::BASE>, which by default is F<mock/Perl>. This
directory will be returned B<whether or not it exists>.

=head1 SEE ALSO

The real L<File::HoneDir|File::HomeDir>.

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
