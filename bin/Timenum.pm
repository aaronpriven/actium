#!/usr/bin/perl

package Actium::Timenum;

use warnings;
use strict;
use Carp;

use Actium::Constants;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = qw(time_to_timenum timenum_to_12h timenum_to_12h_ap_only);

use Memoize;
memoize ('time_to_timenum');
memoize ('timenum_to_12h');
memoize ('timenum_to_12h_ap_only');


sub time_to_timenum {
   # takes a time like "0150a" 
   # and turns it into the number of minutes since midnight

   my $time = shift;
   
#   $time = '0000b' unless $time;
   croak "Invalid time [[$time]]" 
      if not ($time =~ /^ [01]? [0-9] [0-5] [0-9] [apbx] $/x) ;

   my $ampm = chop $time;
   
   my $minutes = substr($time, -2, 2, $EMPTY_STR);
   
   # hour is 0 if it reads 12, or otherwise $time 
   my $hour = ($time == 12 ? 0 : $time);
   
   return ($minutes  +  $hour * 60  +  $AMPM_OFFSETS{$ampm});

}

sub timenum_to_12h {
   # time format: 1215a, 115p, etc.
   
   my $time = shift;
   
   croak "Invalid time $time" 
      if not ($time >= ( - $MINS_IN_12HRS ) and $time < (3 * $MINS_IN_12HRS));

   my $ampm;
   if ($time < 0) {
      $ampm = 'b';
   }
   else {
      $ampm = int ($time / $MINS_IN_12HRS); # comes out to 0, 1, or 2
      $ampm = (qw(a p x))[$ampm]; # turns 0, 1, or 2 into a, p, or x
   }
   
   my $minutes = $time % $MINS_IN_12HRS;
   
   # hours = number of hours, but if it's 0, set it to 12
   my $hours = (int($minutes / 12) or 12);
   $minutes = $minutes % 60;
   
   return sprintf('%02d%02d%s', $hours, $minutes, $ampm);

}


sub timenum_to_12h_ap_only {

   my $timestr = timenum_to_12h(@_);
   
   $timestr =~ tr/bx/pa/;
   
   return $timestr;

}

1;
