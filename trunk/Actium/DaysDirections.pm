# Actium/DaysDirections
# Day and direction codes, conversion between in Hastus and legacy systems

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::DaysDirections 0.001;

use Readonly;

use Perl6::Export::Attrs;

Readonly my %DAY_OF_HASI => {
    qw(
      1234567 DA
      12345   WD
      6       SA
      7       SU
      67      WE
      24      TT
      25      TF
      35      WF
      135     MZ
      )
};

Readonly my %DIR_OF_HASI => {
    qw(
      0 NB    1 SB
      2 EB    3 WB
      4 IN    5 OU
      6 GO    7 RT
      8 CW    9 CC
      10 1    11 2
      12 UP   13 DN
      )
};

sub day_of_hasi : Export {
    my $days = shift;
    $days =~ s/[^\d]//g;
    return $DAY_OF_HASI{ $days };
}

sub dir_of_hasi : Export {
    return $DIR_OF_HASI{ $_[0] };
}

1;

__END__


=head1 NAME

Actium::DaysDirections - Day and direcion codes

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::DaysDirections;
 
 print day_of($hasi->{TRP}{'1632120'}{OperatingDays}) ;
 # prints two-letter day code for the operating days 
 # of trip with internal trip number 1632120
 
 print dir_of(
     $hasi->{PAT}{'7' . $KEY_SEPARATOR . '58'}{DirectionValue}
             );
 # prints two-letter direction code for pattern 58 of route 7

=head1 DESCRIPTION

Actium::DaysDirections 

=head1 SUBROUTINES

=over

=item B<day_of_hasi)>

Takes one argument, the Hastus "Operating Days" code (which is usually one or 
more digits from 1 to 7), and returns a two-letter code for the days:

 WD Weekdays
 SA Saturday
 SU Sunday
 WE Weekend
 DA Daily
 WF Wednesday and Friday
 TT Tuesday and Thursday
 TF Tuesday and Friday
 
Ultimately, these codes (which originated at the old www.transitinfo.org 
web site) are obsolete and should be replaced since they do not allow for 
the full range of date possibilities.

=item B<dir_of_hasi()>

Takes one argument, the Hastus 2006 "Directions" code (see table 9.2 in the 
Hastus 2006 AVL Standard Interface document), and returns a two-letter code
representing the direction.

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

These codes also come from www.transitinfo.org. There's nothing wrong with the 
codes themselves, but because a route marked "Eastbound" may not actually 
go in an eastward direction, avoid actually displaying their meanings
to customers.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010 and the standard distribution.

=item *

Readonly.

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
