#!perl

# pubinflib.pl

# Library of perl routines used in AC's Public Information Systems
# programs

use strict;

# -----------------------------------------------------------------
# ---- BYROUTES SORT ROUTINE
# -----------------------------------------------------------------

sub byroutes ($$) {

   my ($aa, $bb) = (uc($_[0]) , uc($_[1]));
 
   my $anum = ( $aa lt "A" );
   my $bnum = ( $bb lt "A" );
   # So, $anum is true if $aa is a number, etc.
   # admittedly this is not the most sophisticated routine to discover
   # whether they are numbers

   unless ($anum == $bnum) {
           return -1 if $anum;
           return 1;
   }

   #  If they're not both numbers or both letters,
   #  return -1 if $a is a number (and $b is not), otherwise
   #  return 1 (since $b must be a number and $a is not)
   
   #  letters come after numbers in our lists.

   return ($aa cmp $bb) unless ($anum);
   # return a string comparison unless they're both numeric
   # (of course, $anum == $bnum or it would have returned already)

   my @a = split (/(?<=\d)(?=\D)/ , $aa, 2);
   my @b = split (/(?<=\d)(?=\D)/ , $bb, 2);

   # splits on the boundary (zero-width) between
   # a digit on the left and a non-digit on the right.
   # so it splits 72L into 72 and L, whereas it leaves
   # 72, O, and OX1 as one entry each.

   return (   ($a[0] <=> $b[0]) || ($a[1] cmp $b[1]) )
   # they are both numbers, so return a numeric comparison
   # on the first component, unless they're the same, 
   # in which case return a string comparison on the second component.

}

# -----------------------------------------------------------------
# ---- INITIALIZING ROUTINES
# -----------------------------------------------------------------

=pod


this doesn't work for some reason

sub BOXSTYLES () {

# added WS_MINIMIZEBOX to -style
# subtracted WS_EX_CONTEXTHELP, WS_EX_DLGMODALFRAME from -exstyle
    ( 
      -style => (WS_BORDER | DS_MODALFRAME | WS_POPUP | 
             WS_MINIMIZEBOX | WS_CAPTION | WS_SYSMENU) ,
      -exstyle => (WS_EX_WINDOWEDGE | 
                  WS_EX_CONTROLPARENT),
       -top => 30 ,
       -left => 30 ,
    );

}

=cut

sub init_vars () {

   open VARS , "vars.txt" or die "Can't open vars.txt";

   our $effectivedate = scalar (<VARS>);

   chomp $effectivedate;

   close VARS;

   our %privatetps = ( 58 => ["AIRP RECV"]);
   our %privatetproutes;
   $privatetproutes{$_} = 1 foreach (keys %privatetps);
   # that's gonna have to be a file someday

   our %longerdaynames = 
        ( WD => "Monday through Friday" ,
          WE => "Sat., Sun. and Holidays" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
        );

   our %longdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun and Hol" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sun and Hol" ,
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

# the following hashes are used for sorting

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
          CW => 20 ,
          CC => 10 ,
        );

   our %daydirhash = 
        ( 
         CC_DA => 110 ,
         CW_DA => 120 ,
         NB_DA => 130 ,
         WB_DA => 140 ,
         SB_DA => 150 ,
         EB_DA => 160 ,
         CC_WD => 210 ,
         CW_WD => 220 ,
         NB_WD => 230 ,
         WB_WD => 240 ,
         SB_WD => 250 ,
         EB_WD => 260 ,
         CC_WE => 310 ,
         CW_WE => 320 ,
         NB_WE => 330 ,
         WB_WE => 340 ,
         SB_WE => 350 ,
         EB_WE => 360 ,
         CC_SA => 410 ,
         CW_SA => 420 ,
         NB_SA => 430 ,
         WB_SA => 440 ,
         SB_SA => 450 ,
         EB_SA => 460 ,
         CC_SU => 510 ,
         CW_SU => 520 ,
         NB_SU => 530 ,
         WB_SU => 540 ,
         SB_SU => 550 ,
         EB_SU => 560 ,
        );
}

sub read_index {

open INDEX , "<acsched.ndx" or die "Can't open index file.\n";

   local ($/) = "---\n";

   my (%index);
   my @day_dirs;
   my @thisdir;
   my $day_dir;
   my @timepoints;
   my $line;
   my $tp;

   while (<INDEX>) {

      chomp;
      @day_dirs = split("\n");
      $line = shift @day_dirs;
  
      foreach (@day_dirs) {
         # this $_ is local to the loop

         @thisdir = split("\t");
         $day_dir = shift @thisdir;
         @{$index{$line}{$day_dir}{"ROUTES"}} = split(/_/, shift @thisdir);

         foreach (@thisdir) {
            # another local $_

            @timepoints = split(/_/);

#            $tp = tpxref($timepoints[0], 1);
            $tp = $timepoints[0];
#            # cross-referencing - 1 means always do it

            push @{$index{$line}{$day_dir}{"TP"}} , $tp;
            push @{$index{$line}{$day_dir}{"TIMEPOINTS"}} , $timepoints[1];
         }

      }

   }
   return %index;

}

sub build_tphash () {

   open TPHASH, "<tps.txt" or die "Can't open timepoints.txt";

   our %tpxrefs = ();
   our %tphash;

#   my ($key, $given, $mod, $city, $xref, $alwaysxref);

   while (<TPHASH>) {

      next if /^\s*#/;
      next unless /\t/;
      chomp;

      my ($key, @list) = split ("\t"); 

      strip_quotes_and_spaces ($key);
      strip_quotes_and_spaces (@list);

      foreach my $field ( qw(Given Mod City Xref AlwaysXref) ) {

         $tpxrefs{$key}{$field} = shift @list;
      }

      $tphash{$key} = $tpxrefs{$key}{Mod};

   }

}

sub strip_quotes_and_spaces {

   foreach (@_) {
      $_ = substr($_, 1, length ($_) -2)
         if ($_ =~ /^"/) and ($_ =~ /"$/);
      s/^\s+//;
      s/\s+$//;

   }

}

sub tpxref {

    my ($thistp, $toxref) = @_;

    our %tpxrefs;

    if ($tpxrefs{$thistp}{Xref} and 
       ($toxref or $tpxrefs{$thistp}{AlwaysXref}) ) {
       # should xref

#       while ($alltphash{$thistp}{Xref}) {
           $thistp = $tpxrefs{$thistp}{Xref};
#       }

       # once this is done, $thistp isn't the original $thistp anymore,
       # but is the cross-referenced $thistp.

       # The while loop would allow multiple levels of cross-referencing,
       # but would make infinite loops likely (if two timepoints each 
       # reference the other).

    }

   return $thistp;

}

sub get_directory () {

die "No directory given in command line.\n" unless (@ARGV);

return $ARGV[0];

}


sub get_lines () {

   my (@lines);

   my @slsfiles;
   @slsfiles = <skeds/*.sls>;

   s#^sls/## foreach @slsfiles;

   unless (scalar(@slsfiles)) {
      die "Can't find any .sls files.";
   }

   map { s/.sls$//i;}  @slsfiles;
   map { s(^skeds/)()i;}  @slsfiles;

   my $longestline = 0;
   foreach (@slsfiles) {
      $longestline = length($_) if length($_) > $longestline;
   }

   @lines = (sort byroutes @slsfiles );

   return $longestline, @lines;

}

# -----------------------------------------------------------------
# ---- READ DATA FROM DISK ROUTINE
# -----------------------------------------------------------------

sub read_fullsched ($$;$) {

   our (%fullsched);

   %fullsched = ();

   my $line = shift;

   my $toxref = shift;

   my $ext = shift;

   $ext = ".sls" unless $ext;

   my (@wholesched, @thesetimes);
   my ($wholesched , $day_dir, $row, $note, $route, $spec_days , $tp) ;

   local ($_);
   local ($/) = "\n---\n";

   open IN , "skeds/$line" . $ext or die "Can't open file skeds/$line" . $ext;

   until (eof(IN)) {

      $wholesched = <IN>;

      chomp($wholesched);
         
      @wholesched = (split ("\n", $wholesched));

      s/\s+$// foreach @wholesched;
            
      $day_dir = shift (@wholesched);

      @{$fullsched{$day_dir}{"NOTEDEFS"}} = split (/\t/ , shift (@wholesched)) ;

      shift @{$fullsched{$day_dir}{"NOTEDEFS"}};
      # gets rid of "Note Definitions"

      @{$fullsched{$day_dir}{"TIMEPOINTS"}} = split (/\t/, shift @wholesched);
      @{$fullsched{$day_dir}{"TP"}} =  split (/\t/, shift @wholesched);

      unless ($toxref == 2) {

         foreach my $thistp (@{ $fullsched{$day_dir}{"TP"} }) {
            $thistp = tpxref( $thistp, $toxref);
         }
         # this is the bit that does the cross-referencing. It is skipped
         # if it is 2, obviously

      }

      splice ( @{$fullsched{$day_dir}{"TP"}} , 0, 3);
      splice ( @{$fullsched{$day_dir}{"TIMEPOINTS"}} , 0, 3);

      # that gets rid of the "SPEC DAYS" , "RTE NUM" and "NOTE" entries, 
      # and their equivalents in TIMEPOINTS

      $row = 0;
      foreach (@wholesched) {
         
         ($spec_days, $note, $route, @thesetimes ) = split (/\t/);
                           
         $tp = 0;
         foreach my $thistime (@thesetimes) {
             $fullsched{$day_dir}{"TIMES"}[$tp][$row] = $thistime;
             $tp++;
         }

         $fullsched{$day_dir}{"NOTES"}[$row] = $note if $note;
         
         $fullsched{$day_dir}{"ROUTES"}[$row] = $route if $route;

         $fullsched{$day_dir}{"SPEC DAYS"}[$row] = $spec_days if $spec_days;
         
         $row++;
         
      }

   }

   close (IN);

}

# -----------------------------------------------------------------
# ---- USEDROWS
# -----------------------------------------------------------------

sub usedrow ($$) {

   our @outsched;
   my ($column, $row) = @_;
   return vec ($outsched[$column]{"USEDROWS"} , $row, 1);

   # This cannot be an lvalue subroutine, more's the pity

}

sub build_used ($) {
   
   our (@outsched);
   my ($column) = $_[0];
   my ($lasttpnum, %routes);

   my $tpnum = $outsched[$column]{'TPNUM2USE'};
   my %used = ();
   local ($_);

   undef $outsched[$column]{"USEDROWS"};

   foreach (@{$outsched[$column]{"ROUTES2USE"}}) {
      $routes{$_}=1;
   }
   # provides an easy "is an element" lookup

#print "\n[column: $column][tpnum: $tpnum]";

ROW: 
   for (my $row = 0; $row < scalar @{$outsched[$column]{"TIMES"}[$tpnum]};
            $row++) {

      next ROW unless $routes{$outsched[$column]{"ROUTES"}[$row]};
      # if this route isn't on the list of routes to use, skip this row
      # (so if we're printing out a 40 schedule, the 43 won't show up)

      next ROW unless  $outsched[$column]{"TIMES"}[$tpnum][$row];
      # if there's no time for this row, skip it

   TPS: 
      for ( my $thistpnum = (scalar @{$outsched[$column]{"TP"}} -1 ); 
                $thistpnum >= 0;  $thistpnum-- ) {

          $lasttpnum = $thistpnum;
          last TPS if $outsched[$column]{"TIMES"}[$thistpnum][$row];
      }

      $outsched[$column]{"LASTTP"}[$row] = 
                $outsched[$column]{"TP"}[$lasttpnum];

      # save the lasttp abbrev for when we figure out where the destination is

      next ROW if $lasttpnum eq $tpnum;
      # Skip this time if it's the last one in the row.
      # We don't want to tell people when buses leave from this point
      # if they go no further from here

      # ok, now we know this time should be included

      vec ($outsched[$column]{"USEDROWS"} , $row, 1) = 1;

      # and that's saved in $outsched[$column]{"USEDROWS"}, which is
      # more easily accessed by the subroutine usedrows($column, $row)

      # OK, now we're going to go and build a new set of used variables.
      # These are the *frequency* of the NOTES, SPEC DAYS, and ROUTES
      # thingies in the used rows.

      $_ = $outsched[$column]{"NOTES"}[$row];
      $_ = "BLANK" unless $_;
      $used{"NOTES"}{$_}++;

      # I'm pretty sure it won't matter if we don't turn "" to "BLANK"
      # but I'm not sure enough.

      $_ = $outsched[$column]{"SPEC DAYS"}[$row];
      $_ = "BLANK" unless $_;
      $used{"SPEC DAYS"}{$_}++;

      $used{"ROUTES"}{$outsched[$column]{"ROUTES"}[$row]}++;

      # ROUTES will never be blank.

   }

   $outsched[$column]{"USED"} = { %used };

}

# -----------------------------------------------------------------
# ---- BUILD_OUTSCHED
# -----------------------------------------------------------------

sub build_outsched (@) {

   our (@outsched , %fullsched, %longdaynames);

   @outsched = ();

   local ($_);

   my ($column, $daycode, $lasttp, $line, $day_dir, $day, $tp, 
       @routes );

   $column = 0;

   foreach my $pickedtp (@_) {
   # loop around each timepoint (irrespective of order; we'll get that later)

      ($line, $day_dir, $tp, @routes) = split ("\t" , $pickedtp);

      ($outsched[$column]{"DIR"} , $outsched[$column]{"DAY"}) =
          split (/_/ , $day_dir, 2);

      read_fullsched($line, 1);
      # now we have the data. The 1 says to always use the cross-reference

      $outsched[$column] = $fullsched{$day_dir};
      # remember, that's a *reference*. Same reference, same thing.
      # So, now $outsched[column] points to the same hash that 
      # $fullsched{$day_dir} used to point to.  We no longer need to refer
      # to $fullsched at all. In fact,

      %fullsched = ();

      # that's probably not necessary, but it wipes out all the 
      # now-unreferenced material (the other ($day_dir)s...) and thus saves
      # memory.

      ($outsched[$column]{"DIR"} , $outsched[$column]{"DAY"}) =
          split (/_/ , $day_dir, 2);

      # add DAY and DIR to $outsched

      $outsched[$column]{"TPNUM2USE"} = $tp;
      $outsched[$column]{"ROUTES2USE"} = [ @routes ];

      # So now, $tp (which is the NUMBER of the timepoint)
      # and the used routes are stored in $outsched[$column]. It should
      # no longer be necessary to pass those explicitly, since they are
      # associated with the column.
     
      note_definitions($column);
      # read all note definitions into $outsched[$column]{NOTEKEYS}
 
      build_used($column);
      # Now we know that usedrow(x) is 1 if the xth row is a valid one,
      # an 0 if it should be skipped. 

      # We also just built $outsched[$column]{USED}..., which are 
      # the frequency of routes, notes, and special days used

      # and we also just built $outsched[$column]{LASTTP}

      @{$outsched[$column]{"HEADNUM"}} = headnum($column);
      # get the header number(s)

      ($outsched[$column]{"DAY2USE"}, 
       $outsched[$column]{"HEADDAYS"}) = 
           headdays ($column);
      # get the header day text ("Mon thru Fri", etc.) 

      ($outsched[$column]{"LASTTP2USE"} ,
         $outsched[$column]{"HEADDEST"}) = 
           headdest ($column);

      # get the header destination text ("To University and San Pablo")
      # ${LASTTP2USE} is the timepoint short string ("UNIV S.P.")
      # also puts the various non-default last tps into {NOTEKEYS}

      $outsched[$column]{"TP2USE"}=
         $outsched[$column]{"TP"}[$outsched[$column]{"TPNUM2USE"}];

      # save the current timepoint and last timepoint

   } continue {

      $column++;
       
   }

# now we have our $outsched, only it's not in order.  

} 

sub headdest ($) {

   our @outsched;
   our %tphash;
   # my ($day_dir, $tp, $headnum) = @_;
   my $column = $_[0];
   my $headnum = $outsched[$column]{HEADNUM}[0];
   my ($lasttp, $lasttpnum);
   my (%lasttpfreq) = ();
   my $tp = $outsched[$column]{"TPNUM2USE"};

   for (my $row = 0; $row < scalar @{$outsched[$column]{"TIMES"}[$tp]};  
            $row++) {
      next unless usedrow($column, $row) and
            $outsched[$column]{"ROUTES"}[$row] eq $headnum;

      # skip it, unless this timepoint is used and the current 
      # route is the same as in $headnum

      $lasttpfreq{$outsched[$column]{"LASTTP"}[$row]}++;
 
   }

   # so now %lasttpfreq holds the frequency of the last timepoints
   # (for the HEADNUM route).

   $lasttp = 
       (sort { $lasttpfreq{$b} <=> $lasttpfreq{$a} } 
        keys %lasttpfreq)[0];

   # so $lasttp is the most common last timepoint

   # print "{" , keys %lasttpfreq , "}\n\n";

   foreach (keys %lasttpfreq) {
      $outsched[$column]{"NOTEKEYS"}{$_} = $tphash {$_};
   }

   return $lasttp, $tphash{$lasttp};

}

sub headdays ($) {

   my $column = $_[0];

   our (@outsched, %longdaynames, $schooldayflag );
   
   my @used = keys %{$outsched[$column]{USED}{"SPEC DAYS"}};
   # now we have the lists of used special days in %used

   my $daycode = $outsched[$column]{"DAY"};
   my $daystring;

   if (scalar( @used ) == 1) {
   # if there's only one day present,

      if ($used[0] eq "BLANK") {
         # and it's blank, use the standard day routine

         $daystring = $longdaynames{$daycode};

      } else {
         # if only one day, but it's not blank, use that.

         $daystring = $outsched[$column]{"NOTEKEYS"}{$used[0]};
         $daycode = $used[0];
	 $schooldayflag = $daycode if $daycode eq "SD";

      }

   } else {

      # more than one kind of day, so use the standard.
      $daystring = $longdaynames{$daycode};

   }

   return $daycode , $daystring;

}

sub headnum ($) {

   my $column = $_[0];
   our (@outsched);
   return sort byroutes (@{$outsched[$column]{"ROUTES2USE"}})

   # The following code merges things like "51" and 
   # "51A" into "51". But I have decided I would just as soon it not do that.
   # So I have told it not to. Hah.


#   # decides which route number to use at the top.
#
#   # my @routes = @_;
#
#   my $column = $_[0];
#
#   my (@temp, %routes, @headnum) =();
#
#   our (@outsched);
#
#   local($_);
#
#   foreach (sort byroutes @{$outsched[$column]{"ROUTES2USE"}}) {
#        @temp = split (/(?<=\d)(?=\D)/);
#        $temp[1] = "BLANK" unless $temp[1];
#        push @{$routes{$temp[0]}} , $temp[1];
#   }
#   # so now the hash %routes has keys which are the numeric parts,
#   # and values which are a reference to a list of the letter parts.
#   # i.e., for the 51, %routes will be (  51 => [ "BLANK" , "A" ] )
#   # note that the "sort byroutes" means that the final array will be
#   # sorted
#
#   foreach (keys %routes) {
#
#      my $number = $_;
#
#      $number .= $routes{$_}[0] 
#             if scalar (@{$routes{$_}}) == 1 and $routes{$_}[0] ne "BLANK";
#      # if there's only one letter part, and it isn't "BLANK", add it to 
#      # $temp
#
#      push @headnum, $number;
#   }
#   
#   return sort byroutes @headnum;


}



sub note_definitions ($) {

   my $column = $_[0];
   our (@outsched);

   foreach (@{$outsched[$column]{"NOTEDEFS"}}) {
      my ($key, $notedef) = split(/:/);
      $notedef =~ s/ only//i;
      $outsched[$column]{"NOTEKEYS"}{$key} = $notedef;
   }
   # Now all the note definitions from here are in
   # the hash %{$outsched[$column]{NOTEKEYS}}

   foreach (@{$outsched[$column]{"ROUTES2USE"}}) {
 
      $outsched[$column]{"NOTEKEYS"}{$_} = "Line $_";

   }
} 

sub get_output_filename () {

   return "output_test.txt";

}


sub getcolor($) {

   local $_ = $_[0];

   return "Local" if /^\d\d?$/;
   # return "Local" if it's one or two digits

   return "Transbay" if $_ ge "A";
   # return "Transbay" if it's a letter

   # That's nearly all of them, here are some exceptions

   return "EBExpress" if /\dX/;
   return "EBLimited" if /\dL/;

   my $firstchar = substr($_,0,1);

   if (/^\d\d\d/) {
      return "School" if $firstchar eq  "6";
      return "LocalLtdHours" if $firstchar eq  "3";
   }

   return "Local";

}

sub get_head_timepoints($) {

   # returns the default timepoint *across* columns.
   # the argument can either be "LASTTP2USE", in which case
   # it returns the last end timepoint, or "TP2USE", in which case
   # it returns the last timepoint for the columns shown.

   our @outsched;
   my $refersto = $_[0];
   my %tpfreq = ();
   my %tpcols = ();

   local ($_);

   for ( my $column = ( $#outsched); 
            $column >= 0;  $column-- ) {

      $_ = $outsched[$column]{$refersto};
      $tpfreq{$_}++;
      $tpcols{$_} = $column;
   }

   return (sort {
           $tpfreq{$b} <=> $tpfreq{$a} or
           $tpcols{$a} <=> $tpcols{$b}
           } keys %tpfreq)[0];
   # get the keys of %tpfreq (which are the timepoint abbrevations), 
   # sort them descending by value, and 
   # return the first (highest) one.  If two or more are the same, 
   # picks the first one in order by column.

}
 
sub output_outsched ($$$) {

   our (@outsched, %dirhash, %dayhash, %tphash, $schooldayflag);
   $schooldayflag="";
   my ($head, $thismark, @thesemarks, %routes,
       $route, $lasttp, $temp, $tpnum,
       $ampm, $defaultheadtp, @markdefs, %usedmarks);

   my ($stopcode, $stopdescription, $stops) = @_;

   my $printnotes = $stops->{'PrintNotes'};

   local ($_);

   my $markcounter = 0;

   @markdefs = ();

#   open OUT, ">" . get_output_filename();

   mkdir "out" or die 'Can\'t make directory "out"'  unless -d "out";

   my $filename = $stopcode . "-" . $stops->{SignType} . "-" . 
                        scalar (@outsched) . ".txt";

   open OUT, ">out/$filename";

   @outsched = sort 
       {
        byroutes ($a->{"HEADNUM"}[0], $b->{"HEADNUM"}[0]) or 
        $dirhash{$b->{"DIR"}} <=> $dirhash{$a->{"DIR"}} or
        $dayhash{$b->{"DAY"}} <=> $dayhash{$a->{"DAY"}}
       } @outsched;


   $defaultheadtp = get_head_timepoints ("TP2USE");

   foreach my $column (@outsched) {


      foreach (@{$column->{"ROUTES2USE"}}) {
         $routes{$_}=1;
      }

      $head = join ("/" , @{$column->{"HEADNUM"}});
      
      # the gobbeldygook in the print statements are the quark tags
      print OUT '@Column head:';                                   # style


      print OUT 
            '<*d(' , length($head) +1 , ',2)><z10><b1>';  # drop cap
	                                                 # at smaller size

#      print OUT 
#            '*d(' , length($head) +1 , ',2)'                 # drop cap
#            if length($head) <= 3;   # but only if the length is short

      print OUT 
            '<c"' , getcolor($column->{"HEADNUM"}[0]) , '">';   # color

      # at some point, we may want to do some other kind of formatting if
      # there are two or more head numbers.

      print OUT "$head " , '<b$><z$>';

      print OUT $column->{"HEADDAYS"} , " to " ,
                $column->{"HEADDEST"};

      @thesemarks = ();

      # add note to indicate that times refer to the first route
      # given (of one or more) if there are two or more headnums
 
      $_ = $column->{"HEADNUM"}[0];

      if ( scalar ( @{$column->{"HEADNUM"}}) > 1) {

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
      # if not the same as the current timepoint

      $_ = $column->{"TP2USE"};

      if ($defaultheadtp ne $_) {
      # if the default end timepoint for the schedule as a whole 
      # isn't the same as the default end timepoint for this column only,
      # we need a head note.

         if ($usedmarks{"TP2USE:$_"}) {
            $thismark = $usedmarks{"TP2USE:$_"};
         } else {
            $thismark = ++$markcounter;
            $usedmarks{"TP2USE:$_"} = $thismark;
            $temp = $tphash{$_};
            $temp =~ s/\.$//;
            $markdefs[$thismark] = 
               "Departure times are given for $temp. " .
               "Buses may arrive somewhat later at this location.";
         }
 
         push @thesemarks, $thismark;

      }

      print OUT "<V>" , join (", ", sort {$a <=> $b} @thesemarks), "<V>" 
           if scalar (@thesemarks);
      #<V> is "superior" type

      print OUT "<\\c>";                                     # next column

      my $prev = "z";

      $tpnum = $column->{"TPNUM2USE"};
      
      for (my $row = 0; 
            $row < scalar @{$column->{"TIMES"}[$tpnum]};
            $row++) {

         next unless vec ($column->{"USEDROWS"} , $row, 1);

         local ($_) = $column->{"TIMES"}[$tpnum][$row];

         print OUT "\n" unless $prev eq "z";

         $ampm = chop; 
         # removes last char from the time, and sets $ampm to be that char

         if ($ampm ne $prev) {
             print OUT ($ampm eq 'a' ? '@amtimes:' : '@pmtimes:' );
             $prev = $ampm;
         }
         # if $ampm not the same as the last one, print the appropriate
         # style sheet spec, and set the previous to be this one

         substr($_, -2, 0) = ":";

         print OUT "\t$_";

         # time notes

         @thesemarks = ();

         # I am ignoring the bicycle note.

         $_ = $column->{"SPEC DAYS"}[$row];

         if ($_ and ($_ ne $column->{"DAY2USE"})) {
         # if the special day mark for this row isn't blank, and it 
         # isn't the same as the special days for the whole column,
         # we need a note.

            if ($usedmarks{$_}) {
               $thismark = $usedmarks{$_};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{"$_"} = $thismark;
               $temp = $column->{"NOTEKEYS"}{$_};
               $temp =~ s/Days/days/;
               $temp =~ s/Holidays/holidays/;
               $markdefs[$thismark] = "$temp only.";
            }
 
            push @thesemarks, $thismark;

         }
         
         # routes and timepoint
	 #

         $_ = $column->{"ROUTES"}[$row];

         undef $route;
         undef $lasttp;
         $route = $_ if $_ ne $column->{"HEADNUM"}[0];
         # route is nothing if it's the same as the first headnum,
         # otherwise it's the route from the row

         $_ = $column->{"LASTTP"}[$row]; 
         $lasttp = $_ if $_ ne $column->{"LASTTP2USE"};

         # $_ is $route plus $lasttp, with a colon in the middle if 
         # both are valid

         if ($route or $lasttp) {
            # if there's a different route or last timepoint,

            $_ = "$route:$lasttp";
 
            if ($usedmarks{$_}) {
               $thismark = $usedmarks{$_};
            } else {
               $thismark = ++$markcounter;
               $usedmarks{$_} = $thismark;

               if ($route) {
                   $temp = "Line $route";
                   $temp .= ", to " .
                           $tphash{$lasttp} if $lasttp;

               } else {
                  $temp = "To $tphash{$lasttp}";
               }

               $temp =~ s/\.$//;
               
               $markdefs[$thismark] = "$temp.";
            }

         push @thesemarks, $thismark;

         }

         print OUT "<V>" , join (", " , sort {$a <=> $b} @thesemarks), "<V>" 
             if scalar (@thesemarks);

      } # end of row

    print OUT '<\c>';  # next column marker

    } # end of column

    if (scalar(@outsched) < 7 ) {
       print OUT '<\c>' x (2 * ( 7 - scalar(@outsched)) );
       # if there are less than seven columns, print extra column
       # markers for the blank ones
    }

    print OUT '@noteheaders:Light Face = a.m.<\n><B>Bold Face = p.m.<B>';
    print OUT "\n";
    print OUT '@noteheaders:<b>Unless otherwise specified, departure times are given for ';
    $_ = $tphash{$defaultheadtp};
    s/\&/and/;
    s/\.$//;
    print OUT "$_. Buses may arrive somewhat later at this location.<b>\n";

    print OUT "!--$schooldayflag--!";

#   SCHOOLDAYS
    if ($schooldayflag or $usedmarks{SD}) {

       print OUT "Trips that run school days only may not operate every day and will occasionally operate at times other than those shown. Supplementary service is available to all riders at regular fares.\n";

    }

    if (scalar @markdefs) {

       print OUT '@notedefs:';

       for (my $i = 1; $i < scalar (@markdefs); $i++) {

          print OUT "$i. " , $markdefs[$i] , "\n";

       }

    }


    print OUT '<\c>@bottomnotes:' , $stopdescription , ". ";

    print OUT "[$printnotes] " if $printnotes;

    my ($mday, $mon, $year) = (localtime(time))[3..5];

#    $mon = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)[$mon];
    $mon = qw(Jan. Feb. March April May June July Aug. Sept. Oct. Nov. Dec.)[$mon];


    $year += 1900; # Y2K compliant

    our $effectivedate;

    my $effdate = $effectivedate;

    my $prepdate = "$mon $mday, $year";

# new date routines


#    my $prepdate = "$mday-$mon-$year";
 
#    $prepdate =~ s'-'<\!->'g;
#    $effdate =~ s'-'<\!->'g;

    # change dates to non-breaking hyphens
    # vim syntax checker doesn't like s''' but it's correct nonetheless

    print OUT "Prepared: $prepdate. Service effective: $effdate." ;
#    print OUT "\n";

    close OUT;

}

sub get_scheds_for_line {

  our @scdfiles;

  my $line = $_[0];

  return grep ( /^AC_${line}_/ , @scdfiles);

}

### ASSEMBLE_LINE_AND_FILE_LISTS

sub assemble_line_and_file_lists {

our @lines;
our @scdfiles = sort <scd/*.scd>;

s#scd/## foreach @scdfiles;

local ($_);

unless (scalar(@scdfiles)) {
   die "Can't find any .scd files.";
}

# so @scdfiles has all the files in it, sorted

my %lines = ();

foreach my $dummyvar (@scdfiles) {

   $_ = $dummyvar;

   # one has to use the $dummyvar and then the assignment, 
   # otherwise the next two statements modify the @scdfiles array,
   # which is not what we want.
 
   s/^AC_//;
   s/_.*//;

   next if $_ eq "56";

   # THIS IS SPECIAL. LINE 56 IS BROKEN BECAUSE THERE ARE TWO SEPARATE 
   # SCHEDULES FOR LINE 56
   # (THE LATE NIGHT SCHEDULE AND THE REGULAR SCHEDULE). IF THIS 
   # CHANGES, THE ABOVE CODE SHOULD BE REMOVED.
   # In the meantime, we'll have to do line 56 by hand.

   # (I am changing this to make 56 some separate schedules that 
   # are not processed by this program).

   $lines{"$_"} = 1;

}

# So now keys %lines contains all the lines.

#@lines = sort { $a <=> $b or $a cmp $b} keys %lines;

# that wonderful sort says "sort numerically, but if they're the same
#  numerically, use alphabetical sort."
# Unfortunately, it ends up with the numbers last instead of first.
#  sigh.

@lines = sort byroutes keys %lines;

return \@lines, \@scdfiles;

}


sub output_tphash {

   our %tphash;
   open TPHASH , ">timepoints.txt" or die "Can't open timepoints.txt";

   my ($key, $value);
   while (($key,$value) = each %tphash) {
       print TPHASH "$key\t$value\n";
   }

   close TPHASH;
}

sub get_timepoint_info ($) {

   our %fullsched;
   local ($_);

   my $schedname = $_[0];

   @{$fullsched{$schedname}{"TIMEPOINTS"}} = ();

   while (<IN>) {
   # keep reading data until the end of the file
   
      chomp;
      my $tp = substr ($_, 0, 9);
      $_ = substr ($_, 11);
      push @{$fullsched{$schedname}{"TIMEPOINTS"}}, ($_ or $tp);

   } 

   # {TIMEPOINTS} is now the list of timepoints

}

no strict;

################################################################
### HAVE NOT CHECKED THE FOLLOWING ROUTINES FOR STOMPING ON OTHERS'
### VARIABLES. WATCH OUT.
################################################################

sub get_schedule_info {

   ### Get the schedule info ####

   my @toplines = ();
   
   local $_ = <IN>; 
   # blank line at the top of the file is thrown away

   $toplines[0] = <IN> ;
   $toplines[1] = <IN> ;
   chomp (@toplines);
   # toplines gets the first two lines

   $_ = <IN>;

   until (m@timepoints@) {

      # keep reading data until the "key to timepoints" is reached

      chomp;

      next unless $_;
      next if /RTE/;
      next if /NUM/;

      # go to the next one if it's blank, or if it has RTE or NUM in it,
      # which means it must be a line with repeated timepoint info, which
      # we do not need.

      if (substr($_, 3, 1) eq "-") {

          $note = substr($_,0, 2);

          $note =~ s/\s+//g;
          # strip spaces from $note

          $notedef = substr($_, 5);

          push @{$fullsched{$schedname}{"NOTEDEFS"}}, "$note:$notedef";
          next;

      }

      # If it's got a hyphen in the fourth position, that means we think
      # it's a note definition, and so we add it to {"NOTEDEFS"}
 
      push @schedrows, $_;
 
      # otherwise, we add it to the array.

      } continue {

         # this bit is what happens after the "next" in the lines above.

         $_ = <IN>;
         # load another line.

      }

   # @schedrows now has all the raw schedule information in it.
   # @toplines now has the raw timepoint information in it.
   # %fullsched{$schedname}{"NOTEDEFS"} now has all the note definitions.

   return @toplines;

}


sub parse_schedule {

### get notes and routes

   foreach (@schedrows) {
       push @{$fullsched{$schedname}{"SPECDAYS"}}, substr($_,0,2);
       push @{$fullsched{$schedname}{"NOTES"}}, substr($_,2,1);
       push @{$fullsched{$schedname}{"ROUTES"}}, substr($_,3,5);
       $_ = substr($_,8);
   }
   # that takes the notes and routes out of @schedrows and puts it 
   # the appropriate part of %fullsched instead.

   foreach (@toplines) {
       $_ = substr($_,8)
   }
   # That takes the blank space, and "RTE / NUM', out of @toplines


### clean up notes and lines

foreach $ref ( $fullsched{$schedname}{"ROUTES"},    
               $fullsched{$schedname}{"NOTES"} ,
               $fullsched{$schedname}{"SPECDAYS"} ) {
   
   grep ( s/\s//g , @$ref);
   # eliminate spaces
}

### get {TP} information from @toplines

# note: the {TP} is the short, four-character timepoint info. 
# {TIMEPOINTS} is the long, verbal one.

grep ( s/\s+$// , @toplines);
# eliminate trailing spaces

$numpoints =  1 + int ( length($toplines[0]) / 6 );
# There are 6 characters per timepoint: a blank space in front (actually this is
# used for two-digit times like 10:00), four characters for the point, and a space
# in back. 

# Since we've stripped the final spaces, we know that it will actually be one short
# of the real number, so that's why the 1+ is added.


$unpacktemplate = "A6" x $numpoints;
# that gives the template for the unpacking. There are $numpoints points, and six characters
# to each one.  The capital A means to strip spaces and nulls from the result.

@{$fullsched{$schedname}{"TP"}} = unpack ($unpacktemplate, $toplines[0])  ;
@tp2 =  unpack ($unpacktemplate, $toplines[1])  ;

foreach (@{$fullsched{$schedname}{"TP"}}) {

   $_ .= shift (@tp2); 
   s/^\s+//;

}

# So now the data structure in %fullsched has the TP info.


### parse the times

foreach $thisrow (@schedrows) {

   $count = 0;

   foreach (unpack ($unpacktemplate, $thisrow)) {

      s/^\s+//;
      push @{$fullsched{$schedname}{"TIMES"}[$count]}, $_;
      $count++;

   }

}

# That should take all the times and push them to the list in the %fullsched data
#   structure.

}

sub output_schedule {

my $file = $_[0];

mkdir "skeds" or die 'Can\'t make directory "skeds"'  unless -d "skeds";

open TEMPFILE , ">skeds/$file" or die "Can't open file $file.\n";

# print "Writing line $linenum to file $file.\n";

foreach $schedname (sort keys %fullsched) {

   print TEMPFILE $schedname , "\n";
   print TEMPFILE "Note Definitions:\t" , join ("\t", @{$fullsched{$schedname}{"NOTEDEFS"}} ) , "\n"; 
   print TEMPFILE "Special Days\tNotes\tRoute\t" , join ("\t"  , @{$fullsched{$schedname}{"TIMEPOINTS"}} ) , "\n"; 
   print TEMPFILE "SPEC DAYS\tNOTE\tRTE NUM\t" , join ("\t"  , @{$fullsched{$schedname}{"TP"}} ) , "\n"; 

   # get the maximum number of rows
   
   
   $maxrows = 0;
   foreach (@{$fullsched{$schedname}{"TIMES"}}) {
   
   # so $_ will be the reference to the first list of times, then the ref to second list of times...
   
       $rowsforthispoint = scalar (@$_);
       
       # $_ is the reference to the list of times. @$_ is the list of times itself. scalar (@$_) is the
       #     number of elements in the list of times. Whew!
       
       $maxrows = $rowsforthispoint if $rowsforthispoint > $maxrows;
       
   }


   for ($i=0; $i < $maxrows ;  $i++) {

      print TEMPFILE $fullsched{$schedname}{"SPECDAYS"}[$i] , "\t" ;
      print TEMPFILE $fullsched{$schedname}{"NOTES"}[$i] , "\t" ;
      print TEMPFILE $fullsched{$schedname}{"ROUTES"}[$i] , "\t" ;

      foreach (@{$fullsched{$schedname}{TIMES}}) {
          print TEMPFILE $_ -> [$i] , "\t";

      }

     # ok. $_ becomes the *reference* to the first, second, etc. list of times.  

      print TEMPFILE "\n";

   }

   print TEMPFILE "---\n";

}

close TEMPFILE;

}

sub merge_days {

my ($firstday, $secondday, $mergeday) = @_;

my $count = 0;

# for example, (SA, SU, WE) or (WD, WE, DA)

my (@firstscheds, @secondscheds);

@firstscheds = sort grep (/$firstday/ , (keys %fullsched) ) ; 
@secondscheds = sort grep (/$secondday/ , (keys %fullsched) ) ; 

# so all the ones with the first day are in @firstscheds,
# and all the ones with the second day are in @secondscheds.
# These are sorted so that the order of the directions are the same
# (that is, we're comparing westbound Saturday to westbound Sunday,
# not westbound Saturday to eastbound Sunday)

return -1 unless (scalar(@firstscheds) and scalar(@secondscheds));
return -2 unless (scalar(@firstscheds) == scalar(@secondscheds));

# if there aren't any days in common, return -1
# if there are, but the number isn't the same, return -2
# the latter should probably never be the case -- it would mean that
# there is an additional day in one direction. That would be weird.

# I don't know that I'll actually use the return values.

DAY: foreach $day (0 .. scalar(@firstscheds)) {

   foreach ( qw(TP ROUTES SPECDAYS TIMES TIMEPOINTS NOTES NOTEDEFS) ) {

      next DAY if scalar @{$fullsched{$firstscheds[$day]}{$_}} 
         != scalar @{$fullsched{$secondscheds[$day]}{$_}}
      
   }
   
   # if the number of timepoints or rows, etc., are different, skip it
   
   foreach ( qw(TP ROUTES SPECDAYS TIMEPOINTS NOTES NOTEDEFS )) {
   
      next DAY 
         if join ("" , @{$fullsched{$firstscheds[$day]}{$_}}) 
            ne join ("" , @{$fullsched{$secondscheds[$day]}{$_}}) ;
   }
   
   # if the text of any of the data is different skip it
   
   for ($_ =0; $_ < scalar @{$fullsched{$scheds[$day]}{"TIMES"}[0]}  ;  $_++) {
   
      next DAY
         if join ("" , @{$fullsched{$scheds[$day]}{"TIMES"}[$_]})
            ne join ("" , @{$fullsched{$scheds[$day+1]}{"TIMES"}[$_]})

   }

   # if any of the times are different, skip it.
   

   # At this point, we know they're identical. References make it pretty easy.
   
   $newschedname = $firstscheds[$day];
   
   $newschedname =~ s/$firstday/$mergeday/;
   
   $fullsched{$newschedname} = $fullsched{$firstscheds[$day]};
   
   # remember, that's a reference. Same reference, same thing.
   
   delete $fullsched{$firstscheds[$day]};
   delete $fullsched{$secondscheds[$day]};
   
   # so now, the original two days are gone, but the first day is still stored
   # in $fullsched{$newschedname}  
   
   $count++;
}

return $count;

# returns the number of merged schedules. I don't see that it actually matters.

}

sub merge_columns {

   my ($prevtp, $tp);

   ### Delete blank columns, and merge columns with the same timepoint (i.e., 
   ### where a point says "arrives 10:30, leaves 10:35" just use the latter)
   
   foreach my $schedname (keys %fullsched) {

      my ($prevtp, $tp);
      undef $prevtp;
      $tp = 0;
      
      TIMEPOINT: while  ( $tp < ( scalar @{$fullsched{$schedname}{"TP"}}) ) {
      
         unless (join ("", @{$fullsched{$schedname}{"TIMES"}[$tp]})) {
            
            splice (@{$fullsched{$schedname}{"TIMES"}}, $tp, 1);
            splice (@{$fullsched{$schedname}{"TP"}}, $tp, 1);
            splice (@{$fullsched{$schedname}{"TIMEPOINTS"}}, $tp, 1);
            next TIMEPOINT;
         }
         # that gets rid of the blank ones. Now we merge ones
         
         unless ($fullsched{$schedname}{TP}[$tp] eq $prevtp) {
             $prevtp = $fullsched{$schedname}{TP}[$tp];
             $tp++;
             next TIMEPOINT;
         }

         # unless they're the same timepoint, increment the counter
         # and go to the next one

         # so if it gets past that, we have duplicate columns

         splice (@{$fullsched{$schedname}{"TP"}}, $tp, 1);
         splice (@{$fullsched{$schedname}{"TIMEPOINTS"}}, $tp, 1);
         # that gets rid of the extra TP and TIMEPOINTS
         
         for ($row =0; $row < scalar @{$fullsched{$schedname}{"TIMES"}[$tp]}  ;  $row++) {
         
            $fullsched{$schedname}{"TIMES"}[$tp - 1][$row]  
               = $fullsched{$schedname}{"TIMES"}[$tp][$row] 
                   if $fullsched{$schedname}{"TIMES"}[$tp][$row];
                
         }
         # that takes all the values in the second column and puts them in the first column

         splice (@{$fullsched{$schedname}{"TIMES"}}, $tp, 1);
         # gets rid of extra TIMES array, now duplicated in the previous one
   
      }
   
   }
   
}

sub prepare_index_for_writing {

open INDEX , ">acsched.ndx" or die "Can't open index file.\n";

}

sub close_index {

close INDEX;

}

sub output_index ($) {

 my $linenum = $_[0];

 print INDEX "$linenum\n";

 my %routes;

 foreach $schedname (keys %fullsched) {

   %routes = ();

   print INDEX "$schedname\t";
   foreach (@{$fullsched{$schedname}{"ROUTES"}}) {
      $routes{$_}++;
   }

   print INDEX join("_" , sort byroutes (keys %routes)) ;

   for ($i=0; $i < scalar (@{$fullsched{$schedname}{"TP"}});  $i++) {

      print INDEX "\t" , $fullsched{$schedname}{"TP"}[$i];
      print INDEX "_" , $fullsched{$schedname}{"TIMEPOINTS"}[$i];
      # I was going to use \x1E, ascii US, Unit Separator
      # but changed my mind
      # I wanted to use something other than tab

   }

   print INDEX "\n";

 }

 print INDEX "---\n";

}

sub add_tps_to_tphash {

   for (my $i=0; $i < scalar (@{$fullsched{$schedname}{"TP"}});  $i++) {

      $tphash{$fullsched{$schedname}{"TP"}[$i]} = 
            $fullsched{$schedname}{"TIMEPOINTS"}[$i];

   }

}

=pod

this was stopslib.pl
library of routines associated with the stops file

The stops file is a tab-delimited ascii file. The field names
form the first line, followed by a set of stops, one line per stop, each
with a field.

The routines will accept and spit back any field.  They know about the 
following fields and will add them if they are not present in the 
original file:

   StopID
   City
   Neighborhood
   On
   At
   StNum
   NearFar
   Direction
   Condition
   SignType

The format in memory for this is under the hash %stops. The format is

$stops{stopid}{field} = the value of that field.

=cut

use constant NL => "\n";
use constant TAB => "\t";

use strict;

sub readstops ($) {

   my (@values, %isakey, @keys, %hash, %stops);
   my $filename = $_[0];
   local ($_);

   open  STOPFILE, $filename or die "Can't open stops file for reading";

   $_ = <STOPFILE>;
   chomp;
   @keys = split (/\t/);
   %stops = ();

   while (<STOPFILE>) {
      chomp;

      @values = split (/\t/);
      %hash = ();

      foreach (@keys) {
         $hash{$_} = shift @values;
         $hash{$_} = substr($hash{$_}, 1, length ($hash{$_}) -2)
              if ($hash{$_} =~ /^"/) and ($hash{$_} =~ /"$/);

         # removes bracketing quote marks, which are put there for mysterious
         # reasons by Excel sometimes

      }

      $stops{$hash{"StopID"}} = { %hash };

      # yes, $stops{$stopid}{"StopID"} will always be the same as
      # $stopid itself, on a valid record.
      
   }

   $isakey{$_} = 1 foreach (@keys);

   foreach (qw( StopID City Neighborhood On At
               StNum NearFar Direction Condition )) {

      push @keys, $_ unless $isakey{$_};   

   }

   close STOPFILE;

   return ( \@keys, \%stops );

}

sub writestops ($\@\%) {

   my $filename = shift;
   my @keys = @{ +shift } ;
   my %stops = %{ +shift } ;
   my @values;

   unless (rename $filename , "$filename.bak") {
      warn qq(Can't rename old stops file "$filename"; saving as "TEMPSTOP");
      $filename = 'TEMPSTOP';
   }
 
   open STOPS , ">$filename" or die "Can't open stops file for writing";

   print STOPS join ( TAB , @keys) , NL ;

   while (my $stopid = each %stops) {

      @values = ();

      foreach (@keys) {
          push @values , $stops{$stopid}{$_};
      }

      print STOPS join ( TAB , @values) , NL;
      
   }

   close STOPS;

}


sub stopdescription ($$$) {

   my ($stopid, $stopref,$stopdata) = @_;

   our %longdirnames;
   
   my $description = "";
   my $direction = $stopref->{'Direction'}; 
   $direction = $longdirnames{$direction} if $longdirnames{$direction};

   $description .= "$stopref->{'StNum'} " 
          if $stopref->{'StNum'};
   $description .= $stopref->{'On'};
   $description .= " at $stopref->{'At'}" 
          if $stopref->{'At'};
   $description .= ", " . $stopref->{'City'} . ", going $direction (#$stopid)";
   
   $description .= ' *' unless $stopdata;

   return $description;

}

sub get_stopid_from_description {

  my $description = shift;

  my $leftparenpos = rindex ($description, '(');
  my $rightparenpos = rindex ($description, ')');

  $description = 
     substr ($description, $leftparenpos+1, 
             $rightparenpos - $leftparenpos - 1);

  $description =~ s/#//;

  return $description;

}

sub stopdesclist (\%\%) {

   my %stops = %{+shift};
   my %stopdata = %{+shift};
   my @retlist;

   foreach (sort 
           {  
             $stops{$a}{"On"} cmp $stops{$b}{"On"} or 
             $stops{$a}{"At"} cmp $stops{$b}{"At"} or
             $stops{$a}{"StNum"} <=> $stops{$b}{"StNum"} or
             $stops{$a}{"Direction"} cmp $stops{$b}{"Direction"} 
           } 
         keys %stops) 
   {
      push @retlist, stopdescription($_,$stops{$_},$stopdata{$_});
   }

return @retlist;

}

=pod

this was stopdatalib.pl
Routines for dealing with stop data

stopdata is in the hash %stopdata. Format is:

%stopdata{$stopid}[0..x]{LINE} = the line
                        {DAY_DIR} = the day and direction
                        {DAY} = the day (same as above, only easier)
                        {DIR} = the direction (same as above, only easier)
                        {TPNUM} = the number of the appropriate timepoint
                        {ROUTES}[0..x] = each route used here

=cut

use strict;


sub readstopdata ($) {

   my $filename = shift;
   my ($stopid, @pickedtps, %stopdata, @items, $count);

   open STOPDATA, $filename or die "Can't open stop data file for reading";

   local ($/) = "\n---\n";

   local ($_);

   while ($_ = <STOPDATA>) {

      chomp;
      ($stopid, @pickedtps) = split (/\n/);

      next unless $stopid;

      $stopid =~ s/\t.*//;

      # throw away everything after the first tab (if anything)

      $count = 0;
      foreach (@pickedtps) {
         
         @items = split (/\t/);
         $stopdata{$stopid}[$count]{"LINE"} = shift @items;
         my $daydir = shift @items;
         $stopdata{$stopid}[$count]{"DAY_DIR"} = $daydir;
         my ($dir, $day) = split (/_/ , $daydir);
         $stopdata{$stopid}[$count]{"DAY"} = $day;
         $stopdata{$stopid}[$count]{"DIR"} = $dir;
         $stopdata{$stopid}[$count]{"TPNUM"} = shift @items;
         $stopdata{$stopid}[$count]{"ROUTES"} = [ @items ];

         $count++;
      }

      @{$stopdata{$stopid}} = sort bystopdatasort @{$stopdata{$stopid}};

   }

   close STOPDATA;

   return %stopdata;

}

sub bystopdatasort  {
           our (%dayhash, %dirhash);
           return byroutes ($a->{"LINE"} , $b->{"LINE"}) or 
           $dayhash{$b->{"DAY"}} <=> $dayhash{$a->{"DAY"}} or
           $dirhash{$b->{"DIR"}} <=> $dirhash{$a->{"DIR"}}
}

sub writestopdata () {

   our %stops;
   my $filename = shift;
   my %stopdata = @_;

   unless (rename $filename , "$filename.bak") {
      warn qq(Can't rename old stop data file "$filename"; saving as "TEMPSD");
      $filename = 'TEMPSD';
   }
 
   open STOPDATA , ">$filename" 
       or die "Can't open stop data file $filename for writing";

   foreach my $stopid (sort {$a <=> $b} keys %stopdata) {
   # there's no particular reason to sort it, actually.

      next unless $stopid;

      print STOPDATA $stopid , TAB, 
          stopdescription ($stopid, $stops{$stopid}, 1), NL;

      foreach (@{$stopdata{$stopid}}) {

         print STOPDATA $_->{"LINE"} , TAB;
         print STOPDATA $_->{"DAY_DIR"} , TAB;
         print STOPDATA $_->{"TPNUM"} , TAB;
         print STOPDATA join ( TAB , @{$_->{"ROUTES"}}) , NL;
 
      }

   print STOPDATA "---\n";

   }

   close STOPDATA;

}

1;
