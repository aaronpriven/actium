package Octium::DaysDirections 0.012;

# Day and direction codes, conversion between in Hastus and legacy systems

# should be eliminated in favor of Actium::OperatingDays and Actium::Dir

use Actium;
use Octium;

use Sub::Exporter ( -setup => { exports => [qw<dir_of_hasi>] } )
  ;    ### DEP ###

const my %DIR_OF_HASI => (
    qw(
      0 NB    1 SB
      2 EB    3 WB
      4 IN    5 OU
      6 GO    7 RT
      8 CW    9 CC
      10 1    11 2
      12 UP   13 DN
      14 A    15 B
      )
);

sub dir_of_hasi {
    my $dir = shift;
    croak "Uninitialized direction" if not defined $dir;
    return exists $DIR_OF_HASI{$dir} ? $DIR_OF_HASI{$dir} : $EMPTY;
}

1;

=head1 NAME

Octium::DaysDirections - Day and direcion codes

=head1 VERSION

This documentation refers to version 0.019

=head1 SYNOPSIS

 use Octium::DaysDirections;
 
 print dir_of(
     $hasi->{PAT}{'7' . $KEY_SEPARATOR . '58'}{DirectionValue}
             );
 # prints two-letter direction code for pattern 58 of route 7

=head1 DESCRIPTION

Octium::DaysDirections is obsolete and should be retired.

=head1 SUBROUTINES

=over

=item B<dir_of_hasi()>

Takes one argument, the Hastus 2006 "Directions" code (see table 9.2 in
the  Hastus 2006 AVL Standard Interface document), and returns a
two-letter code representing the direction.

 Code  Meaning
 NB    Northbound
 SB    Southbound
 EB    Eastbound
 WB    Westbound
 CC    Counterclockwise
 CW    Clockwise
 IN    Inbound
 OU    Outbound
 UP    Up
 DN    Down
 GO    Go
 RT    Return
 1     One
 2     Two

Only the first six are actually used at AC Transit.

These codes also come from www.transitinfo.org. There's nothing wrong
with the  codes themselves, but because a route marked "Eastbound" may
not actually  go in an eastward direction, avoid actually displaying
their meanings to customers.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010 and the standard distribution.

=item *

Const::Fast

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

