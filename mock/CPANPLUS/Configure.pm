package CPANPLUS::Configure;

use 5.008;

use strict;
use warnings;

use Carp ();
use Cwd ();
use Storable ();

our $VERSION = '0.000_01';

our $CONFIG ||= {
    hosts	=> [
	{
	    scheme	=> 'file',
	    host	=> '',
	    path	=> Cwd::abs_path( 'mock/repos' ),
	},
    ],
};

sub new {
    my ( $class ) = @_;
    my $self = Storable::dclone( $CONFIG );
    return bless $self, ref $class || $class;
}

sub get_conf {
    my ( $self, $key ) = @_;
    return $self->{$key};
}

1;

__END__

=head1 NAME

CPANPLUS::Configure - Mock CPANPLUS::Configure class

=head1 SYNOPSIS

 use lib qw{ mock };
 use CPANPLUS::Configure;
 
 my $conf = CPANPLUS::Configure->new();
 print 'Configured repositories: ',
     join( ', ', @{ $conf->get_conf( 'hosts' ) ), "\n";

=head1 DESCRIPTION

This class implements whatever parts of CPANPLUS::Configure are needed
to test L<CPAN::Access::AdHoc|CPAN::Access::AdHoc>. It is private to the C<CPAN-Access-AdHoc>
distribution. All documentation is for the benefit of the author.

=head1 METHODS

This class supports the following public methods:

=head2 new

This static method instantiates the class. Under the hood, it
deep-clones the contents of C<$CPANPLUS::Configure::CONFIG> (which
B<must>) be a hash reference) and returns it. By default
C<$CPANPLUS::Configure::CONFIG> contains a configuration hash with
C<< hosts => [ qw{ 'file://' . Cwd::abs_path( 'mock/repos' ) } ] >>.

=head2 get_config

This method returns the given configuration item, which is the data for
the given key in the underlying hash.

=head1 SEE ALSO

The real L<CPANPLUS::Configure|CPANPLUS::Configure> class.

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
