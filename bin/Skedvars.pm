# Skedvars.pm
# vimcolor: #DDFFDD

# This contains various literal data used in the Skeds programs.
# This just has the data which you call directly 
# (e.g., %Skedvars::longerdaynames), there's no real reason to turn this
# into functions.

package Skedvars;

use strict;
our (@ISA ,@EXPORT_OK ,$VERSION);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(%longerdaynames %longdaynames %longdirnames
                %dayhash        %dirhash      %daydirhash
                %adjectivedaynames %bound %specdaynames
               );

   our %specdaynames =
        ( "SD" => "School Days Only" , 
          "SH" => "School Holidays Only" ,
          "TT" => "Tuesdays and Thursdays Only" ,
          "TF" => "Tuesdays and Fridays Only" ,
          "WF" => "Wednesdays and Fridays Only" ,
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
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   our %longdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun and Holidays" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
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
        ( EB => 60 ,
          SB => 50 ,
          WB => 40 ,
          NB => 30 ,
          CC => 20 ,
          CW => 10 ,
        );

   our %daydirhash = 
        ( 
         CW_DA => 110 ,
         CC_DA => 120 ,
         NB_DA => 130 ,
         WB_DA => 140 ,
         SB_DA => 150 ,
         EB_DA => 160 ,
         CW_WD => 210 ,
         CC_WD => 220 ,
         NB_WD => 230 ,
         WB_WD => 240 ,
         SB_WD => 250 ,
         EB_WD => 260 ,
         CW_WE => 310 ,
         CC_WE => 320 ,
         NB_WE => 330 ,
         WB_WE => 340 ,
         SB_WE => 350 ,
         EB_WE => 360 ,
         CW_SA => 410 ,
         CC_SA => 420 ,
         NB_SA => 430 ,
         WB_SA => 440 ,
         SB_SA => 450 ,
         EB_SA => 460 ,
         CW_SU => 510 ,
         CC_SU => 520 ,
         NB_SU => 530 ,
         WB_SU => 540 ,
         SB_SU => 550 ,
         EB_SU => 560 ,
        );

