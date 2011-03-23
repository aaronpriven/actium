#!/usr/bin/perl

@ARGV = qw(-s sp09) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2stoptimes - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin);

use Carp;
#use Fatal qw(open close);
use Storable();

use Actium::FPMerge (qw(FPread FPread_simple));

use Actium::Timenum (qw(time_to_timenum timenum_to_12h timenum_to_12h_ap_only) );

use Actium (qw(option ensuredir avldata key jt));

use Actium::Constants;

# don't buffer terminal output
$| = 1;

my $intro = 'avl2stoptimes -- produces list of times for each stop.';

my $helptext = <<'EOF';
avl2stoptimes reads the data written by readavl and turns it 
into files that contain each stop and what the times for that stop are.
Try "perldoc avl2stoptimes" for more information.
EOF

Actium::initialize ( $helptext , $intro);

# retrieve data

ensuredir('skeds');

my %times_of;

my (@stops, %stops);

print "Stops (be patient, please)... " unless option qw{quiet};
FPread_simple ("Stops.csv" , \@stops , \%stops , 'stop_id_1');
print scalar(@stops) , " records.\nLoaded.\n\n" unless option qw{quiet};

{ # scoping
# the reason to do this is to release the %avldata structure, so Affrus
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = avldata();

make_stop_times($avldata_r);

}

open my $fh , '>' ,  "/Users/apriven/Desktop/solarstops.txt" or die $!;

#my $count = 0;
for my $stopid (sort keys %times_of) {
   my @times = @{$times_of{$stopid}};
   @times = sort { time_to_timenum($a) <=> time_to_timenum($b) } @times;
   my $count = 0;
   for my $time (@times) {
      my $tn = time_to_timenum($time);
      $count++ if ( $tn < 360 or $tn > 1140);
   }
   
   my $first = $times[0];
   my $last = $times[-1];
   my $on = $stops{$stopid}{OnF} || '';
   my $at = $stops{$stopid}{AtF} || '';
   my $stnum = $stops{$stopid}{StNum} || '';
   my $site = $stops{$stopid}{SiteF}  || '';
   my $direction = $stops{$stopid}{DirectionF} || '';


   print ".";

   my $result = jt ( $stopid , $on, $at, $stnum, $site, $direction, 
        $first , $last, time_to_timenum($first) , time_to_timenum($last) , $count , "\n");
   print $fh ($result );
   
   #exit if $count++ > 10;
   
}

print "\n\nEnd.\n";


############# end of main program #######################

sub make_stop_times {

   my %avldata = %{+shift};

   # separate trips out by which line and direction they're in
   TRIP:
   while ( my ($trip_number, $trip_of_r) = each %{$avldata{TRP}} ) {
      my %tripinfo_of = %{$trip_of_r};
      next TRIP unless $tripinfo_of{IsPublic};
      
      my $pattern  = $tripinfo_of{Pattern};
      my $line     = $tripinfo_of{RouteForStatistics};
      my $patkey   = key ($line, $pattern);
 
      TIMEIDX:
      foreach my $timeidx (0 .. $#{$tripinfo_of{PTS}}) {
         my $stopid = $avldata{PAT}{$patkey}{TPS}[$timeidx]{StopIdentifier};

         my $time = $tripinfo_of{PTS}[$timeidx];
         $time =~ s/^0//;
         
         push @{$times_of{$stopid}} , $time;
         
      }
      
   }

}


   

=head1 NAME

avl2stoptimes - Get lists of stop times from the avl stored data.

=head1 DESCRIPTION

avl2stoptimes reads the data written by readavl and turns it 
into files that contain each stop and what the times for that stop are.

=head1 AUTHOR

Aaron Priven

=cut

