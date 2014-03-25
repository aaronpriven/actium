#!/ActivePerl/bin/perl
# vimcolor: #000030

# makepoints
#
# This program generates the point schedules associated with 
# particular signs.

# OLDTODO - 
# 1) Change "headnum" routine so that if two adjacent numbers have
# the same color, the slash between them uses that color (instead of
# grey80) - DONE -- but somehow undone when other things done -- redo
# 7) Add a "noteonly" database
# 8) deal with two-level templates
# 10) Make sure beginning NL on each sign is gone
# 11) Use Set::Intspan to allow ranges of numbers

# DONE or irrelevant
# 2) Change the default number of columns to be derived from the "SignType"
# database, and add the number of added columns triggered by "usedcount" to it
# 4) (not strictly makepoints) Change the "Signtype" value list in signs.fp5
# to be derived from the signtype database  - # DONE


use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

my $IDPOINTFOLDER = 'indesign_points';

use Data::Dumper;

use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);
use IDTags;
use Skedfile qw(Skedread merge_columns);
use Skedvars;
use Skedtps qw(tphash tpxref);
use Actium::Sorting::Line (qw(sortbyline byline));

use Actium::Options (qw<option add_option init_options>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::O::Folders::Signup;

init_options();

my $signupdir = Actium::O::Folders::Signup->new();
chdir $signupdir->path();
my $signup = $signupdir->signup;

printq <<"EOF";
makepoints - This is the makepoints program. It creates point schedules
from the data exported from the FileMaker databases.

EOF

# open and load files
open LOG , ">>makepoints-log.txt";
print LOG "makepoints started " . localtime(time) . "\n";


printq "Using signup $signup\n\n" ;

printq <<"EOF" ;
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@signs, @stops, @lines, @signtypes, @skedspec, @projects);
our (%signs, %stops, %lines, %signtypes, %skedspec, %projects);

our ($schooldayflag, $anysecondflag,$addminsflag);

printq "Timepoints and timepoint names... " ;
my $vals = Skedtps::initialize;
printq "$vals timepoints.\nSignTypes... " ;

FPread_simple ("SignTypes.csv" , \@signtypes, \%signtypes, 'SignType');
printq scalar(@signtypes) , " records.\nProjects... " ;
FPread_simple ("Projects.csv" , \@projects, \%projects, 'Project');
printq scalar(@projects) , " records.\nSigns... " ;
FPread_simple ("Signs.csv" , \@signs, \%signs, 'SignID');
printq scalar(@signs) , " records.\nSkedspec... " ;
FPread ("SkedSpec.csv" , \@skedspec, \%skedspec, 'SignID' , 1, 0);
# ignores repeating fields, but works with non-unique SignIDs
# BUG - rest of program will break if there are *not* non-unique SignIDs.
# Not a problem in real life, but may break simple test runs.
printq scalar(@skedspec) , " records.\nLines... " ;
FPread_simple ("Lines.csv" , \@lines, \%lines, 'Line');
printq scalar(@lines) , " records.\nStops (be patient, please)... " ;
FPread_simple ("Stops.csv" , \@stops , \%stops , 'stop_id_1');
printq scalar(@stops) , " records.\nLoaded.\n\n" ;

open DATE , "<effectivedate.txt" 
      or die "Can't open effectivedate.txt for input";

our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;
$effdate =~ s/\r//g;
my $nbsp = IDTags::nbsp;
$effdate =~ s/ /$nbsp/g;

# main loop

printq "Now processing point schedules for sign number:\n" ;

my $displaycolumns = 0;


my @signstodo;

if (@ARGV) {
   @signstodo = @ARGV;
} else {
   @signstodo = keys %signs;
}

SIGN:
foreach my $signid (sort {$a <=> $b} @signstodo) {

   next SIGN unless lc($signs{$signid}{Active}) ne "no" 
          and exists $skedspec{$signid};
   # skip inactive signs and those without skedspecs

   # this sign added to deal with k2id.pl
   next SIGN if lc($signs{$signid}{UseOldMakepoints}) eq 'no';
   
   unless (option('quiet')) {
      print "$signid ";
      $displaycolumns += length($signid) + 1;
      if ($displaycolumns > 70) {
         $displaycolumns = 0;
         print "\n";
      }
   }

   $schooldayflag = 0;
   $anysecondflag = 0;
   $addminsflag = 0;
   
   my @points = ();
   
   SCHEDULE:
   foreach my $skedspec (@{$skedspec{$signid}} ){
      next SCHEDULE if $skedspec->{FullOrPoint} eq 'Full';
      my $point = build_point($skedspec); 
      push @points, $point if ref($point);
      # returns a hashref to the point sked, unless build_sked returns
      # an error value (a scalar)
   }

   output_points(\@points , $signid) if scalar (@points);
   # output the point sched unless there are no points
   # (which would be the case if there are only full schedules here)

}

printq "\n\n" ;

close LOG;

####### END OF MAIN PROGRAM


sub build_point {

   my $skedspec = shift;

   my $point = Skedread("skeds/" . $skedspec->{'SkedID'} . ".txt");
   # now $point includes all the data in the full schedule
   # This includes 
   # DAY, DIR, SKEDNAME, LINEGROUP (scalars)
   # TP, NOTEDEFS, NOTES, SPECDAYS, and ROUTES (arrays)
   # TIMES (array of arrays)

   merge_columns ($point);
   # this merges consecutive columns that have identical timepoint names.
   # it gives you only departure times, not arrival times.


   foreach (keys %$skedspec) {
      $point->{$_} = $skedspec->{$_};
   }

   # now $point includes all the data in Skedspec, too! 

   # I now consider this a serious BUG (or design flaw) since it means
   # schedules and Skedspec cannot contain the same field names

   # This includes Timetable, Lines, Timepoint, NoteOnly, ExactTP,
   # SecondTimepoint, UseSecondTimepoint, BlankTimepoint, BlankorNonBlank,
   # AmPm, FullOrPoint, SkedID, SignID, SkedSpecSerial, TPXref,
   # BlankTPXref, SecondTPXref, Day, Dir, TPXrefName, Timepoint_NoEquals,
   # BlankTP_NoEquals, SecondTP_NoEquals

   # Some of these will be blank because they are calculated fields not
   # stored

   {
   my $noteonly = lc(substr ($point->{NoteOnly} , 0 , 1) );
   $noteonly = "" unless $noteonly =~ /^l|n|s|r|a|b|c$/;
   $point->{NO} = $noteonly;
   }
   # so point->{NO} is a flag, if this is note only. $point->{NoteOnly} is
   # a string corresponding to a particular note. This will need to change
   # if there are more notes.

   {
   my $i=0;
   $point->{TPNUM}{$_} = $i++ foreach @{$point->{TP}};
   } # calculates timepoint column numbers

   unless ( exists $point->{TPNUM}{$point->{Timepoint}} ) {
     my $warning = $point->{SignID} . 
        ": No such point as " . $point->{Timepoint} . " in " . 
        $point->{SKEDNAME} . "\n";
     print LOG $warning;
     warn "\n" . $warning;
     return -1;
   } else {
      $point->{TPNUM2USE} = $point->{TPNUM}{$point->{Timepoint}} ;
   }

   $point->{DOSECOND} = 0;
   if ( lc($point->{UseSecondTimepoint}) eq "yes" ) {
      $point->{S_TPNUM2USE} = $point->{TPNUM}{$point->{SecondTimepoint}};
      unless ($point->{S_TPNUM2USE} == $point->{TPNUM2USE}) {
         $point->{DOSECOND} = 1;
         $anysecondflag = 1;
      }
   }

   $point->{ROUTES2USE} = [ (split "\n" , $point->{Lines}) ];

   $point->{NOTEKEYS} = note_definitions($point);
   # now all the routes and note keys are in the hash 
   # %{$point->{NOTEKEYS}}
   
   build_used($point);  

   # Now we know that usedrow(x) is 1 if the xth row is a valid one,
   # an 0 if it should be skipped. 

   # We also just built $point->{USED}..., which are 
   # the frequency of routes, notes, and special days used

   # and we also just built $point->{LASTTP}


   $point->{M_TPXREF} = tpxref($point->{M_TIMEPOINT} );

   $point->{HEADNUM} = [sortbyline @{$point->{ROUTES2USE}}];
   # in the old windows version, there was a long routine that
   # combined things like 51/51A into a single number (51). 
   # I decided not to do that anymore
   
   ( $point->{DAY2USE} , $point->{HEADDAYS} ) = 
       headdays ($point);
   # get the header day text ("Mon thru Fri", etc.) 

   ($point->{LASTTP2USE} , $point->{HEADDEST}) = headdest ($point);
   # get the header destination text ("To University and San Pablo")
   # $...{LASTTP2USE} is the timepoint short string ("UNIV S.P.")
   # also puts the various non-default last tps into {NOTEKEYS}

   return $point;

}

sub note_definitions ($) {

   my $point = shift;

   my %notekeys = %Skedvars::specdaynames;

   foreach (@{$point->{"NOTEDEFS"}}) {
      my ($key, $notedef) = split(/:/);
      #$notedef =~ s/ only//i;
      $notekeys{$key} = $notedef;
   }
   # Now all the note definitions from here are in
   # the notekeys hash

   $notekeys{$_} = "Line $_" foreach ($point->{ROUTES2USE}) ;
   # that puts the routes in Notekeys too

   return \%notekeys;

} 

sub build_used {
   
   my $point = shift;

   my (%routes, $doblank, $blanktpnum, $dosecond , $usedrowcount , $s_tpnum);

   my $tpnum = $point->{TPNUM2USE};

   # is there a second timepoint as well as the first?

   $dosecond = 0;
   if ($point->{DOSECOND}) {
      $dosecond = 1; # it's easier to have a flag than to keep using "exists"
      $s_tpnum = $point->{S_TPNUM2USE};
   }

   # the following implements the "blank or nonblank" thing

   $doblank = 0; 
   if ( lc($point->{BlankorNonBlank}) eq "blank" ) {
      $doblank = -1; 
   } elsif ( lc($point->{BlankorNonBlank}) eq "nonblank" ) {
      $doblank = 1;
   }

   if ($doblank and exists ( $point->{TPNUM}{$point->{BlankTimepoint}} ) ) {
      # if the user specified that we're to look for blank timepoints,
      # and there is a valid timepoint number for that entry
      $blanktpnum = ($point->{TPNUM}{$point->{BlankTimepoint}} ) ;
      # $blanktpnum is the one we're looking at.
      $doblank = 0 if $blanktpnum == $tpnum;
      # but don't do it if the blanktp is the same as this timepoint,
      # since that makes no sense.
   } else {
      $doblank = 0;
      # otherwise, the user specified an invalid "blank" timepoint, and
      # thus we just pretend the user didn't ask for us to look at it.
   }

   my %used = ();

   local ($_);

   $point->{USEDROWS} = undef; # must initialize it for vec

   $routes{$_}=1 foreach (@{$point->{"ROUTES2USE"}}) ;

   # provides an easy "is an element" lookup

ROW: 
   for (my $row = 0; $row < scalar @{$point->{"ROUTES"}};
            $row++) {

      next ROW unless $routes{$point->{ROUTES}[$row]};
      # if this route isn't on the list of routes to use, skip this row
      # (so if we're printing out a 40 schedule, the 43 won't show up)

      my $thistpnum = $tpnum;
      if ($dosecond) {
         next ROW unless $point->{TIMES}[$tpnum][$row] or 
                         $point->{TIMES}[$s_tpnum][$row];
         $thistpnum = $s_tpnum unless $point->{TIMES}[$tpnum][$row];
      } else {
         next ROW unless $point->{TIMES}[$tpnum][$row];
      }
      # if there's no time for this row, skip it
      # now "$thistpnum" is the time we will actually use, whether it is
      # the main timepoint or the second timepoint
      # uses the first tpnum if both have times

      # the following implements the "am or pm" thing
      if ($point->{AmPm} =~ /a/i ) {
         next ROW unless $point->{TIMES}[$thistpnum][$row] =~ /a$/;
      } elsif ($point->{AmPm} =~ /p/i ) {
         next ROW unless $point->{TIMES}[$thistpnum][$row] =~ /p$/;
      }

      if ($doblank == 1)  { # not blank
         next ROW unless $point->{TIMES}[$blanktpnum][$row];
      } elsif ($doblank == -1) { # blank
         next ROW     if $point->{TIMES}[$blanktpnum][$row];
      }

      my $lasttpnum;
      TPS: 
      for ( my $i = ((scalar @{$point->{TP}}) -1 ); 
                $i >= 0;  $i-- ) {

          $lasttpnum = $i;
          last TPS if $point->{TIMES}[$i][$row];
      }
      # so $lasttpnum = the number of the last timepoint for which
      # there is a time

      $point->{LASTTP}[$row] = 
                $point->{TP}[$lasttpnum];

      # save the lasttp abbrev for when we figure out where the destination is

      next ROW if $lasttpnum == $thistpnum;
      # Skip this time if it's the last one in the row.
      # We don't want to tell people when buses leave from this point
      # if they go no further from here

      # ok, now we know this time should be included in the printed output

      vec ($point->{"USEDROWS"} , $row, 1) = 1;

      $usedrowcount++;

      # and that's saved in $point->{"USEDROWS"}, which is
      # more easily accessed by the subroutine usedrow($point, $row)

      # OK, now we're going to go and build a new set of used variables.
      # These are the *frequency* of the NOTES, SPECDAYS, and ROUTES
      # thingies in the used rows.

      $_ = $point->{NOTES}[$row];
      $_ = "BLANK" unless $_;
      $used{NOTES}{$_}++;

      # I'm pretty sure it won't matter if we don't turn "" to "BLANK"
      # but I'm not sure enough.

      $_ = $point->{SPECDAYS}[$row];
      $_ = "BLANK" unless $_;
      $used{SPECDAYS}{$_}++;

      $used{ROUTES}{$point->{ROUTES}[$row]}++;
      # ROUTES will never be blank.

      if ($dosecond) {
         if ($thistpnum == $tpnum) {
            $used{TP}{Timepoint}++;
         } else {
            $used{TP}{SecondTimepoint}++;
         }
      }
      # this is whether the main timepoint or the second timepoint 
      # is more frequent

   }

   # save USED array in $point
   $point->{USED} = \%used;
   $point->{USEDROWCOUNT} = $usedrowcount;

   if ($dosecond) {
      if ($used{TP}{Timepoint} >= $used{TP}{SecondTimepoint}) {
         # if the first timepoint is more common than the second one,
         $point->{FIRSTISMAIN} = 1;
         $point->{L_EXACT}     = $point->{ExactSecondTP};
         $point->{L_TIMEPOINT} = $point->{SecondTimepoint};
         $point->{L_TPNUM2USE} = $point->{S_TPNUM2USE};
         $point->{M_EXACT}     = $point->{ExactTP};
         $point->{M_TIMEPOINT} = $point->{Timepoint};
         $point->{M_TPNUM2USE} = $point->{TPNUM2USE};
         # "M" means "Main". "L" means "Lesser."
      } else {
         $point->{FIRSTISMAIN} = 0;
         $point->{L_EXACT}     = $point->{ExactTP};
         $point->{L_TIMEPOINT} = $point->{Timepoint};
         $point->{L_TPNUM2USE} = $point->{TPNUM2USE};
         $point->{M_EXACT}     = $point->{ExactSecondTP};
         $point->{M_TIMEPOINT} = $point->{SecondTimepoint};
         $point->{M_TPNUM2USE} = $point->{S_TPNUM2USE};
      }
   } else {
         $point->{FIRSTISMAIN} = 1;
         $point->{M_TIMEPOINT} = $point->{Timepoint};
         $point->{M_TPNUM2USE} = $point->{TPNUM2USE};
         $point->{M_EXACT} = $point->{ExactTP};
   }
   # if we combine two timepoints, and the second one is more frequent than
   # the first, make $point->{MAINTP} "S_" -- this is a prefix used later.
   # Otherwise, make it nothing.


   # put the most common route for each column in $point->{MAINROUTE}
   $point->{MAINROUTE} = 
      ( sort { $used{ROUTES}{$b} <=> $used{ROUTES}{$a} } 
             keys %{$used{ROUTES}})[0];

   return $point; # although we don't actually use the returned value

}

sub usedrow {
   my ($point, $row) = @_;
   return vec ($point->{"USEDROWS"} , $row, 1);
}

sub headdays {

   my $point = shift;

   my @used = keys %{$point->{USED}{SPECDAYS}};
   # now we have the used special days in @used

   my $daycode = $point->{"DAY"};
   my $daystring;

   if (scalar( @used ) == 1) {
   # if there's only one day present,

      if ($used[0] eq "BLANK") {
         # and it's blank, use the standard day text

         $daystring = $Skedvars::longdaynames{$daycode};

      } else {
         # if only one day, but it's not blank, use that.

         $daystring = $point->{NOTEKEYS}{$used[0]};
         $daycode = $used[0];
	 $schooldayflag = 1 
             if $daycode eq 'SD' and 
             not $point->{NO};
         # make sure it prints the thing about school trips running oddly,
         # unless we have a whole-column-replaced-by-a-note thing,
         # in which case we have no times so no point in printing it.

      }

   } else {

      # more than one kind of day, so use the standard.
      $daystring = $Skedvars::longdaynames{$daycode};

   }

#   return $daycode , $daystring , $schooldayflag;
   return $daycode , $daystring ;

}


sub headdest {

   my $lasttp;
   my $point = shift;

   if ($point->{NO} eq "l") {

      $lasttp = $point->{LASTTP}[0];
      # not sure this is right -- should be the last timepoint
      # of the first row


   } else {

   my (%lasttpfreq) = ();

   for (my $row = 0; 
            $row < scalar @{$point->{ROUTES}};
            $row++) {
      next unless usedrow($point, $row) and
            $point->{ROUTES}[$row] eq $point->{MAINROUTE};

      # skip it, unless this timepoint is used and the current 
      # route is the same as in $mainroute
      $lasttpfreq{$point->{LASTTP}[$row]}++;
   }

   # so now %lasttpfreq holds the frequency of the last timepoints
   # (for the most frequent route).

   $lasttp = 
       (sort { $lasttpfreq{$b} <=> $lasttpfreq{$a} } 
        keys %lasttpfreq)[0];

   # so $lasttp is the most common last timepoint

   foreach (keys %lasttpfreq) {
      $point->{NOTEKEYS}{$_} = tphash($_);
   }

   }

   my $hashlookuptp = $lasttp;
   $hashlookuptp =~ s/=[0-9]*//;
   
   return $lasttp, (tphash($hashlookuptp) or $hashlookuptp);

}


sub output_points {

   my @points = @{+shift};
   my $signid = shift;
   
   our ($schooldayflag, $addminsflag);

   my ($head, $thismark, @thesemarks, 
       $route, $lasttp, $temp, 
       $ampm, @markdefs, %usedmarks, $lengthinlines);

   local ($_);

#   # set up "new column after x lines" thing
#   if ($signtypes{$signs{$signid}{SignType}}{TallColumnLines}) {
#      $lengthinlines = $signtypes{$signs{$signid}{SignType}}{TallColumnLines};
#   } else {
#      $lengthinlines = 0;
#   }

   #print "<$lengthinlines> ";

   my $markcounter = 0;

   @markdefs = ();

   mkdir $IDPOINTFOLDER or die "Can't make directory '$IDPOINTFOLDER'" 
                  unless -d $IDPOINTFOLDER;

   open OUT, ">$IDPOINTFOLDER/$signid.txt";

   print OUT IDTags::start;
   # print OUT IDTags::parastyle("Normal");


   @points = sort 
       {
        return 1 if $a->{"HEADNUM"}[0] eq "82" and $b->{"HEADNUM"}[0] eq "82L";
        return -1 if $b->{"HEADNUM"}[0] eq "82" and $a->{"HEADNUM"}[0] eq "82L";
        return 1 if $a->{"HEADNUM"}[0] eq "82" and $b->{"HEADNUM"}[0] eq "801";
        return -1 if $b->{"HEADNUM"}[0] eq "82" and $a->{"HEADNUM"}[0] eq "801";
        return 1 if $a->{"HEADNUM"}[0] eq "82L" and $b->{"HEADNUM"}[0] eq "801";
        return -1 if $b->{"HEADNUM"}[0] eq "82L" and $a->{"HEADNUM"}[0] eq "801";
        # reverse 801, 82L, 82 since usually this is what we have to end up doing by hand
        byline ($a->{"HEADNUM"}[0], $b->{"HEADNUM"}[0]) or 
        $Skedvars::dirhash{$b->{"DIR"}} <=> $Skedvars::dirhash{$a->{"DIR"}} or
        $Skedvars::dayhash{$b->{"DAY"}} <=> $Skedvars::dayhash{$a->{"DAY"}}
       } @points;

   my ($defaultheadtp, $defaultheadtpexact, $justoneheadtp) 
       = get_head_timepoints (\@points);


   my $pointtext = "";

   my $columncount = 0;
   
   my $has_ab;

   foreach my $point (@points) {

      $columncount++;

      # set up "new column after x lines" thing
      my $tallcols = $signtypes{$signs{$signid}{SignType}}{TallColumnLines};
      my $usedrowcount = $point->{USEDROWCOUNT};

      if ($tallcols and ($point->{USEDROWCOUNT} > $tallcols) ) {
         my $numcols = int ($usedrowcount / $tallcols ) + 1;
         $lengthinlines = int ($usedrowcount / $numcols);
         $lengthinlines++ if $usedrowcount % $numcols;

      } else {
         $lengthinlines = 0;
         # no line limit
      }

      my $noteonly = $point->{NO};

      # Numbers (without names)

      my @headnums = @{$point->{"HEADNUM"}};
      my $lengthheadnums = length(join("/" , @headnums));

      if ($#headnums == 0) { # if there's only one head number 
                            # (i.e., last one is #0),

         $pointtext .= IDTags::parastyle("dropcaphead") . IDTags::dropcapchars($lengthheadnums+1);
         $pointtext .= IDTags::color(getcolor($headnums[0]) , $headnums[0] . " ");

      } else { # multiple head numbers....

         $pointtext .= IDTags::parastyle("dropcapheadmany") . IDTags::dropcapchars($lengthheadnums+1);

         my @headcolors;
         foreach (0 .. $#headnums) {
            $headcolors[$_] = getcolor($headnums[$_]);
         }
 
         foreach (0 .. $#headnums) {
            unless ($_ == 0) {
               my $sepcolor;
               if ($headcolors[$_] eq $headcolors[$_-1]) {
                  $sepcolor = $headcolors[$_];
               } else {
                  $sepcolor = 'Grey80';
               }
               $pointtext .= IDTags::color($sepcolor, "/");
            }
            $pointtext .= IDTags::color($headcolors[$_],$headnums[$_]);
         }
         $pointtext .= " ";
      }
  
      # end of numbers
      # beginning of days & destinations
      
      my $headdays = $point->{HEADDAYS};
      if ($point->{DIR} eq 'A' or $point->{DIR} eq 'B') {
         $headdays .= '.' ;
         $has_ab = 1;
      }

      $pointtext .= IDTags::bold($headdays);

      unless ($point-{'NO'} eq "l") { # unless it's a "last stop" note,

         # add destination
         if ($point->{DestinationNote} ) {
           $pointtext .= " to " .  $point->{HEADDEST} . " " 
               . notrailingperiod ($point->{DestinationNote}) . ".";
         } elsif ($point->{DIR} eq "CW") {
            $pointtext .= " to " .  $point->{HEADDEST} . " (Clockwise loop).";
         } elsif ($point->{DIR} eq "A") {
            $pointtext .= " <0x201C>A Loop<0x201D> to " 
               .  notrailingperiod($point->{HEADDEST}) . ".";
         } elsif ($point->{DIR} eq "B") {
            $pointtext .= " <0x201C>B Loop<0x201D> to " 
               .  notrailingperiod($point->{HEADDEST}) . ".";
         } elsif ($point->{DIR} eq "CC") {
            $pointtext .= " to " .  $point->{HEADDEST} . " (Counterclockwise loop).";
         } else {
            my $headdest = $point->{HEADDEST};
            $headdest =~ s/\.$//;
            $pointtext .= " to " . notrailingperiod($point->{HEADDEST}) . ".";
         }
       
         # add timepoint
       
         if ($point->{AddMins} == 0 and (not $noteonly) ) {
            # if there are no added minutes here, 
            # and there is no "noteonly",
         
            my $headtp;
            if (lc($point->{M_EXACT}) eq "yes") {
               $headtp = "here";
            } else {
               $headtp = tphash($point->{M_TPXREF});
            }

            $pointtext .= " Leaves $headtp at:"
         
         }
         
      }  

      @thesemarks = ();

      # add note to indicate that times refer to the first route
      # given (of one or more) if there are two or more headnums
 
      $_ = $point->{MAINROUTE};

      if ( (not $noteonly) and scalar ( @{$point->{HEADNUM}}) > 1) {

        if ($usedmarks{"HEADNUM:$_"}) {
           $thismark = $usedmarks{"HEADNUM:$_"};
        } else {
           $thismark = ++$markcounter;
           $usedmarks{"HEADNUM:$_"} = $thismark;
           $markdefs[$thismark] = 
              "Unless indicated otherwise, times in this column " .
              "are for Line $_.";
        }

        push @thesemarks, $thismark;

      } 

      # add note to indicate that times refer to the proper timepoint
      # if not the same as the current timepoint. But not if this is a
      # "note only" column or there are approximate times

=comment

# Old put-the-head-timepoint-in-the-footnote bit

      $_ = $point->{M_TPXREF};

      if ( $point->{AddMins} == 0 and 
           not ($noteonly) and 
           $defaultheadtp ne $_) {
      # if the default end timepoint for the schedule as a whole 
      # isn't the same as the default end timepoint for this column only,
      # we need a head note. 
      # But not if the whole column is a note only, or if it's estimated times

         if ($usedmarks{"Timepoint:$_"}) {
            $thismark = $usedmarks{"Timepoint:$_"};
         } else {
            $thismark = ++$markcounter;
            $usedmarks{"Timepoint:$_"} = $thismark;
            my $temp = notrailingperiod(tphash($_));
#            print "<<$_:$temp>> ";
            $markdefs[$thismark] = 
               "Departure times are given for $temp." ;
            $markdefs[$thismark] .=
               " Buses may arrive somewhat later at this location."
               unless lc($point->{M_EXACT}) eq "yes";
         }
 
 
         push @thesemarks, $thismark;

      }

=cut

      $pointtext .= IDTags::superscript (
                join (",", sort {$a <=> $b} @thesemarks) )
           if scalar (@thesemarks);

      $pointtext .= IDTags::boxbreak; # next box

      if ($noteonly) {

         $pointtext .= IDTags::parastyle('noteonly');

         if ($noteonly eq "l" ) {
         # Last stop

         $pointtext .= 'Last Stop';

         } elsif ($noteonly eq "s" ) {
         # School note

            if ($usedmarks{"Noteonly:s"}) {
               $thismark = $usedmarks{"Noteonly:s"};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{"Noteonly:s"} = $thismark;
               $temp = tphash($_);
               $markdefs[$thismark] = 
                "Lines that operate school days only operate at times that " . 
                "may vary from day to day. Call 511 or visit www.actransit.org for more ". 
                "information. Supplementary service is available to " .
                "everyone at regular fares.";
            }
 
            $pointtext .= "See\rNote $thismark";

=for
         } elsif ($noteonly eq 'a' or $noteonly eq 'b') {

            if ($usedmarks{"Noteonly:a"}) {
               $thismark = $usedmarks{"Noteonly:a"};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{"Noteonly:a"} = $thismark;
               $temp = tphash($_);
               $markdefs[$thismark] = 'Line 82L operates every 10 minutes between 6:00 a.m. and 7:00 p.m. weekdays, and every 15 minutes between 9:00 a.m. and 5:00 p.m. weekends. Buses are dispatched from the ends of the line and then proceed without set time points along the route.';

            }

            $pointtext .= "See\rNote $thismark";
 
=cut
         } elsif ($noteonly eq "a" ) {
         # 1R7day note

            $pointtext .= 'Buses arrive about every 12 minutes weekdays, 15 minutes weekends '
            . IDTags::emdash .
                      IDTags::softreturn . 
                      'See information elsewhere on this sign.';
            # that is an emdash - it should carry through. It's
            # potentially a crossplatform issue though.

         } elsif ($noteonly eq "b" ) {
         # 1R5day note

            $pointtext .= 'Buses arrive about every 12 minutes ' . IDTags::emdash .
                      IDTags::softreturn . 
                      'See information elsewhere on this sign.';
            # that is an emdash - it should carry through. It's
            # potentially a crossplatform issue though.

         } elsif ($noteonly eq "c" ) {
         # 1R5&7 note

            $pointtext .= 'Buses arrive about every 12 minutes weekdays, and 15 minutes weekends. (Weekend service to downtown Oakland only.) ' .
                      IDTags::softreturn . 
                      'See information elsewhere on this sign.';


         } elsif ($noteonly eq "r" ) {
         # Rapid note

            $pointtext .= 'Buses arrive about every 12 minutes ' . IDTags::emdash .
                      IDTags::softreturn . 
                      'See information elsewhere on this sign.';
            # that is an emdash - it should carry through. It's
            # potentially a crossplatform issue though.

         } elsif ($noteonly eq "n" ) {
         # No Locals note
            $pointtext .= 'No local riders';
         }

         $pointtext .= IDTags::boxbreak;  # next point marker
         next; # next point. Skip per-row routine below.

      }

      if ($point->{AddMins} >0 ) {
         $addminsflag = 1;

         $pointtext .= IDTags::parastyle('noteonly');
         $pointtext .= "Approx<0x00AD>imate times only. See note.\r\r";

      }

      my $prev = "z";
      my $usedcount = 0;

      for (my $row = 0; 
            $row < scalar @{$point->{ROUTES}};
            $row++) 
      {

         next unless vec ($point->{USEDROWS} , $row, 1);

         $usedcount++;
         if ($lengthinlines and $usedcount > $lengthinlines) {
            $pointtext .= IDTags::boxbreak() ;
            $pointtext .= IDTags::parastyle('amtimes' , IDTags::boxbreak()) ;
            $columncount++;
            $prev = "z";
            $usedcount=1;
         }

         local ($_) = $point->{"TIMES"}[$point->{TPNUM2USE}][$row];

         # find out if this one is main or lesser
         my $lesser = 0;
         if ($point->{DOSECOND}) { 
            $lesser = 1 if ($_ xor $point->{FIRSTISMAIN} );
            # so, if the first timepoint has a time but the first one
            # isn't main, or the first timepoint has no time and
            # the first one is main, then this row is lesser, not main.
            # Whew.
            $_ = $_ || $point->{"TIMES"}[$point->{S_TPNUM2USE}][$row];
         }

         $pointtext .= "\r" unless $prev eq "z";

         $ampm = chop; 
         # removes last char from the time, and sets $ampm to be that char

         # AddMins routine is here

         if ($point->{AddMins} > 0 ) {

            my $mins = substr($_,-2,2,""); # now $_ is hours
            $mins += $point->{AddMins}; # coercing mins to number
            while ($mins >= 60) { # roll over minutes
               $mins -= 60;

               # and change the hour too
               if ($_ eq "12") {
                   $_ = "1";
               } elsif ($_ eq "11") {
                   $ampm = ($ampm eq "a" ? "p" : "a");
                   $_ = "12";
               } else {
                   $_ = $_ + 1; # coercion to number
               }
            }
            $_ .= sprintf("%02d" , $mins);
            
         }

         if ($ampm ne $prev) {
             $pointtext .= IDTags::parastyle (
                       $ampm eq 'a' ?  'amtimes'  : 'pmtimes' );
             #print OUT ($ampm eq 'a' ? '@amtimes:' : '@pmtimes:' );
             $prev = $ampm;
             $_ .= $ampm;
             # if you want to add the "a" or "p back, uncomment the line above
             # -- which I have now done -- and make next line -2
             substr($_, -3, 0) = ":"; # add a colon. 
         } else {
             substr($_, -2, 0) = ":"; # add a colon
         }
         # if $ampm not the same as the last one, print the appropriate
         # style sheet spec, and set the previous to be this one

         my $time = $_;

         # next bit: footnotes on the time

         @thesemarks = ();

         $_ = $point->{SPECDAYS}[$row];

         if ($_ and ($_ ne $point->{"DAY2USE"})) {
         # if the special day mark for this row isn't blank, and it 
         # isn't the same as the special days for the whole column,
         # we need a note.

            if ($usedmarks{$_}) {
               $thismark = $usedmarks{$_};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{"$_"} = $thismark;
               $temp = $point->{NOTEKEYS}{$_};
               $temp =~ s/Days/days/;
               $temp =~ s/Holidays/holidays/;
               $markdefs[$thismark] = "$temp.";
            }
 
            push @thesemarks, $thismark;

         }
         
         # routes, last timepoint

         $_ = $point->{"ROUTES"}[$row];

         undef $route;
         undef $lasttp;
         $route = $_ if $_ ne $point->{MAINROUTE};
         # route is nothing if it's the same as the most common route,
         # otherwise it's the route from the row

         $_ = $point->{LASTTP}[$row]; 
         $lasttp = $_ if $_ ne $point->{"LASTTP2USE"};

         # $_ is $route plus $lasttp, with a colon in the middle if 
         # both are valid


         if ($route or $lasttp or $lesser) {
            # if there's a different route or last timepoint,

            my $ltimepoint = $point->{L_TIMEPOINT};
            $ltimepoint =~ s/=[0-9]*//;

            $_ = "$route:$lasttp:$ltimepoint";

#          print "<<$point->{SkedID} $_>> ";

            my $hashlasttp = $lasttp;
            $hashlasttp =~ s/=\d+$//;
 
            if ($usedmarks{$_}) {
               $thismark = $usedmarks{$_};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{$_} = $thismark;

               $markdefs[$thismark] = "";

               if ($route or $lasttp) {
                  if ($route) {
                      $temp = "Line $route";
                      $temp .= ", to " .
                              tphash($hashlasttp) if $lasttp;
   
                  } else {
                     $temp = "To " . tphash($hashlasttp);
                  }
   
                  $temp =~ s/\.$//;
               
                  $markdefs[$thismark] = "$temp.";
               }

               if ($lesser) {

                  $temp = tphash(tpxref($point->{L_TIMEPOINT}));

                  $temp =~ s/\.$//;


                  $markdefs[$thismark] .= " " if $markdefs[$thismark];
                  $markdefs[$thismark] .= 
                     "Departure time is given for $temp." ;
                  $markdefs[$thismark] .=
                     " Buses may arrive somewhat later at this location."
                     unless lc($point->{L_EXACT}) eq "yes";
               }

            }

            push @thesemarks, $thismark;

         }

         if (scalar (@thesemarks)) {

            my $footnotes = join ("," , sort {$a <=> $b} @thesemarks);

            $time = "\t$time" if ((length($time) + length($footnotes)) < 8);

            $time .= IDTags::superscript ( $footnotes) ;

         } else {
           $time = "\t$time";
         }

         $time = IDTags::color("Rapid Red", $time) if $point->{AddMins};

         $pointtext .= $time;

      } # end of row

      $pointtext .= IDTags::boxbreak ;  # next point marker

    } # end of point

    my $maxcolumns = $signtypes{$signs{$signid}{SignType}}{TallColumnNum};
    #print "[[" , $signs{$signid}{SignType} , "/" , $maxcolumns , "]] ";
    if ($columncount < $maxcolumns) { 
       my $break = IDTags::parastyle('amtimes' , IDTags::boxbreak());
       print OUT ($break x (2 * ( $maxcolumns - $columncount) ));
       # if there are less than the right # of columns, print extra column
       # markers for the blank ones
    }

    print OUT $pointtext;

    # END OF POINTS - START OF SIDE NOTES

    # TODO - change to allow for both tall & short columns

    print OUT IDTags::parastyle('sideeffective');
    
    my $uniqueid = $signs{$signid}{UNIQUEID};
    
    my $phoneid = $stops{$uniqueid}{PhoneID};
    
    # EFFECTIVE DATE and colors
    my $color;
    if ($effdate =~ /Dec|Jan|Feb/) {
       $color = "H101-Purple"; # if it looks crummy change it to H3-Blue
    } elsif ($effdate =~ /Mar|Apr|May/) {
       $color = "New AC Green";
    } elsif ($effdate =~ /Jun|Jul/) {
       $color = "Black";
    } else { # Aug, Sept, Oct, Nov
       $color = "Rapid Red";
    }
    
    #print OUT IDTags::color($color , "Stop ID: $phoneid\rEffective: $effdate");
    print OUT IDTags::color($color , "Effective: $effdate");
    print OUT "\r" , IDTags::parastyle('sidenotes');
    print OUT 'Light Face = a.m.' , IDTags::softreturn;
    print OUT IDTags::bold ('Bold Face = p.m.') , "\r"; 

    print OUT IDTags::color ("Rapid Red" , "Times shown in red are only approximations. Buses may come somewhat earlier or later than the time shown.\r") 
          if $addminsflag;
          
          
   if ($has_ab) {
    
   print OUT  
       'Lines that have <0x201C>A Loop<0x201D> and <0x201C>B Loop<0x201D> travel in a circle, beginning '
     , 'and ending at the same point. The A Loop operates in the clockwise '
     , 'direction. The B Loop operates in the counterclockwise direction. '
     , 'Look for <0x201C>A<0x201D> or <0x201C>B<0x201D> at the right end of the headsign on the bus. '
     , "\r"; 
    
   }

=comment
# Old put-the-default-timepoint-above-the-notes bit

    if ( not ($anysecondflag) and $justoneheadtp ) { 
       print OUT 'Departure times are given for ';
    } else {
       print OUT 'Unless otherwise specified, departure times are given for ';
    }
    $_ = tphash($defaultheadtp);
    s/\&/and/;
    s/\.$//;
    print OUT "$_.";
    print OUT " Buses may arrive somewhat later at this location."
                unless $defaultheadtpexact eq "Yes";

    print OUT "\r";
=cut


    # TODO - add side note from db and Note600s text

    my $sidenote = $signs{$signid}{Sidenote};

    if ($sidenote and ($sidenote !~ /^\s+$/)) {
   
       $sidenote =~ s/\n/\r/g;
       $sidenote =~ s/\r+/\r/g;
       $sidenote =~ s/\r+$//;
       $sidenote =~ s/\0+$//;
       print OUT IDTags::bold ($signs{$signid}{Sidenote}) , "\r" ;

    }

    if (scalar @markdefs) {

       # print OUT '@notedefs:'; # no style needed now

       for (my $i = 1; $i < scalar (@markdefs); $i++) {
          print OUT "$i. " , $markdefs[$i] , "\r";
       }

    }

    my $thisproject = $signs{$signid}{Project};
    if ($projects{$thisproject}{'ProjectNote'}) {
       print OUT $projects{$thisproject}{'ProjectNote'} , "\r";
    }


    if ($signs{$signid}{Note600s} =~ /^[Yy]/ ) {
       print OUT "This stop may also be served by supplementary lines (Lines 600" .
       IDTags::endash . 
       "699), which operate school days only, at times that may vary from day to day. Call 511 or visit www.actransit.org for more information. This service is available to everyone at regular fares.\r";
    }


#   SCHOOLDAYS
    if ($schooldayflag or $usedmarks{SD}) {

       print OUT "Trips that run school days only may not operate every day and will occasionally operate at times other than those shown. Supplementary service is available to everyone at regular fares.\r";

    }


    print OUT "See something wrong with this sign, or any other AC Transit sign? Let us know! Leave a comment at www.actransit.org/feedback or call 511 and say 'AC Transit'. Thanks!\r" if lc($signtypes{$signs{$signid}{SignType}}{GenerateWrongText}) eq "yes";
    
    
    
    print OUT IDTags::parastyle('depttimeside'), 'Call ',
      IDTags::bold('511'), ' and say ', IDTags::bold('"Departure Times"'),
      " for live bus predictions\r", ;
      
    # print OUT IDTags::parastyle('stopid'),
    #"STOP ID\r", IDTags::parastyle('stopidnumber'),
    #$phoneid;

    print OUT IDTags::boxbreak , IDTags::parastyle('bottomnotes');
    print OUT signdescription($signid) , ". ";

    print OUT "[$signs{$signid}{DescripNotes}] " if $signs{$signid}{DescripNotes};

    my ($mday, $mon, $year) = (localtime(time))[3..5];

#    $mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
    $mon = qw(Jan. Feb. March April May June July Aug. Sept. Oct. Nov. Dec.)[$mon];

    $year += 1900; # Y2K compliant

    my $prepdate = "$mon $mday, $year";

    #print OUT "Prepared: $prepdate. Service effective: $effdate." ;
    print OUT "Prepared: $prepdate." ;
#    print OUT "\r";

    close OUT;

}

sub get_head_timepoints {

   # returns the default timepoint *across* columns.

   my @points = @{+shift};
   my %tpfreq = ();
   my %tpcols = ();
   my %exact = ();

   local ($_);

   for ( my $column = ( $#points); 
            $column >= 0;  $column-- ) {

      $_ = $points[$column]{M_TPXREF};
      $tpfreq{$_}++;
      $tpcols{$_} = $column;
      $exact{$_}  = $points[$column]{M_EXACT};
   }


   my $thistp = (sort {
           $tpfreq{$b} <=> $tpfreq{$a} or
           $tpcols{$a} <=> $tpcols{$b}
           } keys %tpfreq)[0] ;

   # get the keys of %tpfreq (which are the timepoint abbrevations), 
   # sort them descending by value, and 
   # return the first (highest) one.  If two or more are the same, 
   # picks the first one in order by column.

   my $justoneheadtp = 0;
   $justoneheadtp = 1 if scalar(%tpfreq) == 1;

   return ($thistp, $exact{$thistp} , $justoneheadtp)

}

sub signdescription {

   my ($signid) = shift;

   my $uniqueid = $signs{$signid}{UNIQUEID};

   if ($uniqueid) {
 
      my $thisstop = $stops{$uniqueid}; # this is a reference
   
      my ($on, $at) = ($thisstop->{OnF} , $thisstop->{AtF} ) ;
   
      foreach ($on , $at) {
   
         s/Av\.?$/Ave./;
         s/Wy\.?$/Way/;
         s/Path\.$/Path/;
         s/Park\.$/Park/;
         s/Ln\.$/Lane/;
         s/Lp\.$/Loop/;
         s/Macarthur/MacArthur/;
         s/Broadway\.$/Broadway/;

      }
      
      my $phoneid = $thisstop->{PhoneID};

      my $description = "";

      my $direction = $thisstop->{DirectionF}; 
      $direction = $Skedvars::longdirnames{$direction} 
           if $Skedvars::longdirnames{$direction};

      $description .= "$thisstop->{StNumF} " 
             if $thisstop->{StNumF};
      $description .= $on;
      $description .= " at $at" if $at ; 
      $description .= 
              ", " . $thisstop->{CityF};
      $description .= 
              ", going $direction"
              if $direction;

      $description .= " (#$signid; stop #$phoneid";
   
      $description .= "; shelter site #" . $signs{$signid}{ShelterNum} 
              if $signs{$signid}{ShelterNum};

      $description .= ")";
 
      return $description;

   } 

   # if no uniqueid,

   return $signs{$signid}{NonStopLocation} . ", " . 
          $signs{$signid}{NonStopCity} . ". (#$signid)";

}

sub getname {


   my $num = shift;
   our %lines;
   return ($lines{$num}{Name});

}


sub getcolor {

   #local $_ = $_[0];

   our %lines;
   return ($lines{$_[0]}{Color} or "Grey80");

   # now it assumes that everything worth thinking about has a color in
   # the Lines database. Those that don't (e.g., schools) get Grey80.

   # old code for old map colors
   #return "Local" if /^\d\d?$/;
   # return "Local" if it's one or two digits

   #return "Transbay" if $_ ge "A";
   # return "Transbay" if it's a letter

   # That's nearly all of them, here are some exceptions

   #return "EBExpress" if /\dX/;
   #return "EBLimited" if /\dL/;

   #my $firstchar = substr($_,0,1);

   #if (/^\d\d\d/) {
   #   return "School" if $firstchar eq  "6";
   #   return "LocalLtdHours" if $firstchar eq  "3";
   #}
   #return "Local";

}

sub notrailingperiod {
   local ($_) = shift;
   s/\.$//;
   return $_;
}
