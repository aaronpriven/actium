# Actium/DaysDirections
# Day and direction codes, conversion between in Hastus and legacy systems

# Subversion: $Id$

# legacy stage 2, mostly
# should be eliminated in favor of Actium::O::Days and Actium::O::Dir

use 5.012;
use warnings;

package Actium::DaysDirections 0.005;

use Const::Fast;
use Actium::Constants;
use Carp;

use Sub::Exporter -setup => { exports => [qw<day_of_hasi dir_of_hasi>] };

# New day codes have a character for each set of days that are used.

# 1 - 7 : Monday through Sunday (like in Hastus)
# A - G : School day Mondays through school day Sundays
# H - Holidays
# J - Z reserved for future use

const my %DAY_OF_HASI => (
    qw(
      1234567 DA
      12345   WD
      6       SA
      7       SU
      67      WE
      56      FS
      24      TT
      25      TF
      35      WF
      135     MZ
      )
);

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


sub day_of_hasi {
    my $days = shift;
    croak "Uninitialized direction" if not defined $days;
    $days =~ s/[^\d]//g;
    return exists $DAY_OF_HASI{ $days } ? $DAY_OF_HASI{$days} : $EMPTY_STR;
}

sub dir_of_hasi  {
    my $dir = shift;
    croak "Uninitialized direction" if not defined $dir;
    return exists $DIR_OF_HASI{ $dir } ? $DIR_OF_HASI{$dir} : $EMPTY_STR;
}

1;


__END__

   The following are from skedvars and will be incorporated shortly

   my %specdaynames =
        ( "SD" => "School days only" , 
          "SH" => "School holidays only" ,
          "TT" => "Tuesdays and Thursdays only" ,
          "TF" => "Tuesdays and Fridays only" ,
          "WF" => "Wednesdays and Fridays only" ,
	  "MZ" => "Mondays, Wednesdays, and Fridays only" ,
        );

   my %bound = 
        ( EB => 'Eastbound' ,
          SB => 'Southbound' ,
          WB => 'Westbound' ,
          NB => 'Northbound' ,
          CW => 'Clockwise' ,
          CC => 'Counterclockwise' ,
        );

   my %adjectivedaynames = 
        ( WD => "Weekday" ,
          WE => "Weekend" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   my %longerdaynames = 
        ( WD => "Monday through Friday" ,
          WE => "Sat., Sun. and Holidays" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
          WU => "Weekdays and Sundays",
        );

   my %longdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun and Holidays" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   my %shortdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun, Hol" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sun & Hol" ,
        );


   my %longdirnames = 
        ( E => "east" ,
          N => "north" ,
          S => "south" ,
          W => "west" ,
          SW => "southwest" ,
          SE => "southeast" ,
          'NE' => "northeast" ,
          NW => "northwest" ,
        );

   my %dayhash = 
        ( DA => 50 ,
          WD => 40 ,
          WE => 30 ,
          SA => 20 ,
          SU => 10 ,
        );

   my %dirhash = 
        ( WB => 60 ,
          SB => 50 ,
          EB => 40 ,
          NB => 30 ,
          CC => 20 ,
          CW => 10 ,
        );

   my %daydirhash = 
        ( 
         CW_DA => 110 ,
         CC_DA => 120 ,
         NB_DA => 130 ,
         EB_DA => 140 ,
         SB_DA => 150 ,
         WB_DA => 160 ,
         CW_WD => 210 ,
         CC_WD => 220 ,
         NB_WD => 230 ,
         EB_WD => 240 ,
         SB_WD => 250 ,
         WB_WD => 260 ,
         CW_WE => 310 ,
         CC_WE => 320 ,
         NB_WE => 330 ,
         EB_WE => 340 ,
         SB_WE => 350 ,
         WB_WE => 360 ,
         
         CW_WU => 361 ,
         CC_WU => 362 ,
         NB_WU => 363 ,
         EB_WU => 364 ,
         SB_WU => 365 ,
         WB_WU => 366 ,
         
         CW_SA => 410 ,
         CC_SA => 420 ,
         NB_SA => 430 ,
         EB_SA => 440 ,
         SB_SA => 450 ,
         WB_SA => 460 ,
         CW_SU => 510 ,
         CC_SU => 520 ,
         NB_SU => 530 ,
         EB_SU => 540 ,
         SB_SU => 550 ,
         WB_SU => 560 ,
        );





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

Const::Fast

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
