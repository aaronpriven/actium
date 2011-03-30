# Skedvars.pm

# This contains various literal data used in the Skeds programs.
# This just has the data which you call directly 
# (e.g., %Skedvars::longerdaynames), there's no real reason to turn this
# into functions.

# That was written long, long ago, before I had a clue about that.
# which makes this:

# Legacy stage 1

# soon to be deleted and incorporated into Actium::DaysDirections

package Skedvars;

use strict;
our (@ISA ,@EXPORT_OK ,$VERSION);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(%longerdaynames %longdaynames %longdirnames
                %dayhash        %dirhash      %daydirhash
                %adjectivedaynames %bound %specdaynames
                %shortdaynames
               );

   our %specdaynames =
        ( "SD" => "School days only" , 
          "SH" => "School holidays only" ,
          "TT" => "Tuesdays and Thursdays only" ,
          "TF" => "Tuesdays and Fridays only" ,
          "WF" => "Wednesdays and Fridays only" ,
	  "MZ" => "Mondays, Wednesdays, and Fridays only" ,
        );

   our %bound = 
        ( EB => 'Eastbound' ,
          SB => 'Southbound' ,
          WB => 'Westbound' ,
          NB => 'Northbound' ,
          CW => 'Clockwise' ,
          CC => 'Counterclockwise' ,
        );

   our %adjectivedaynames = 
        ( WD => "Weekday" ,
          WE => "Weekend" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   our %longerdaynames = 
        ( WD => "Monday through Friday" ,
          WE => "Sat., Sun. and Holidays" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
          WU => "Weekdays and Sundays",
        );

   our %longdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun and Holidays" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   our %shortdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun, Hol" ,
          DA => "Every day" ,
          SA => "Saturdays" ,
          SU => "Sun & Hol" ,
        );


   our %longdirnames = 
        ( E => "east" ,
          N => "north" ,
          S => "south" ,
          W => "west" ,
          SW => "southwest" ,
          SE => "southeast" ,
          'NE' => "northeast" ,
          NW => "northwest" ,
        );

   our %dayhash = 
        ( DA => 50 ,
          WD => 40 ,
          WE => 30 ,
          SA => 20 ,
          SU => 10 ,
        );

   our %dirhash = 
        ( WB => 60 ,
          SB => 50 ,
          EB => 40 ,
          NB => 30 ,
          CC => 20 ,
          CW => 10 ,
        );

   our %daydirhash = 
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

