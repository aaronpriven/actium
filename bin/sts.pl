#!perl

# sts.pl - Single Timepoint Schedules

# first command-line argument is to be the directory where the files
# are stored

# -----------------------------------------------------------------
# ---- MAIN
# -----------------------------------------------------------------

use strict;

# use warnings;

sub init_vars () ;
sub get_directory () ;
sub get_lines () ;
sub pick_timepoints () ;
sub pick_list ($@) ;
sub display_lines () ;
sub pick_line () ;
sub read_fullsched ($) ;
sub usedrow ($$) ;
sub build_used ($) ;
sub build_outsched (@) ;
sub headdest ($) ;
sub headdays ($) ;
sub headnum($) ;
sub note_definitions ($) ;
sub build_tphash();
sub output_outsched();

use strict;

require 'byroutes.pl';

init_vars();

chdir get_directory() or die "Can't change to specified directory.\n";

build_tphash();

get_lines();

my @pickedtps = pick_timepoints();

build_outsched(@pickedtps);

output_outsched();

# -----------------------------------------------------------------
# ---- INITIALIZING ROUTINES
# -----------------------------------------------------------------

sub init_vars () {

   our %longdaynames = 
        ( WD => "Mon thru Fri" ,
          WE => "Sat, Sun and Holidays" ,
          DA => "Daily" ,
          SA => "Saturdays" ,
          SU => "Sundays and Holidays" ,
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
}

sub build_tphash () {

   open TPHASH, "<timepoints.txt" or die "Can't open timepoints.txt";

   read_tphash();

   close TPHASH;

   return unless -e "tpoverride.txt";

   open TPHASH, "<tpoverride.txt" or die "Can't open tpoverride.txt";

   read_tphash();

   close TPHASH;

}


sub read_tphash () {

our %tphash;

my ($key, $value);

   while (<TPHASH>) {

      next if /^\s*#/;
      next unless /\t/;
      chomp;
      ($key, $value) = split("\t");
      $tphash{$key} = $value;
   }

}

sub get_directory () {

die "No directory given in command line.\n" unless (@ARGV);

return $ARGV[0];

}


sub get_lines () {

   our ($longestline, @lines);

   my @slsfiles;
   @slsfiles = <*.sls>;

   unless (scalar(@slsfiles)) {
      die "Can't find any .sls files.";
   }

   map { s/.sls$//i;}  @slsfiles;

   $longestline = 0;
   foreach (@slsfiles) {
      $longestline = length($_) if length($_) > $longestline;
   }

   @lines = (sort byroutes @slsfiles );

}


# -----------------------------------------------------------------
# ---- PART OF pick_timepoints
# -----------------------------------------------------------------

sub pick_timepoints () {

   our (%fullsched);

   my (%routehash, @pickedtps);
   my ($yorn, $line, $day_dir, @routes, $tp, $timepoint);

   PICKEDTP: while (1) {

      $line = pick_line();

      read_fullsched($line);

      $day_dir = pick_list("Pick a day and direction." , sort keys %fullsched);

      %routehash = ();

      foreach ( @{$fullsched{$day_dir}{"ROUTES"}} ) {
          $routehash{$_} = 1;
      } 

      @routes = sort byroutes (keys %routehash);

      # @routes = pick_multiple_list (@routes); 

      # I haven't written the pick_multiple_list routine... and I may not
      # until I get one free with MacPerl

      ($timepoint, $tp) = pick_list (
              "Pick a timepoint." , @{$fullsched{$day_dir}{"TIMEPOINTS"}});

      push @pickedtps,  join( "\t" , $line, $day_dir, $tp, @routes);


     
      do {

         print "Do another (y/n)? ";
         $yorn = substr(uc(<STDIN>),0,1);
         last PICKEDTP if $yorn eq "N";

      } until $yorn eq "Y";

   }

   return @pickedtps;

}




sub pick_list ($@) {

# Someday this will be replaced with a call to the MacPerl
# list picker... but not yet.

   local ($_);

   my $i;

   my $prompt = shift @_;

   print "-" x 79 , "\n$prompt\n\n";

    $i=0;

    foreach (@_) {

      $i++;

      print " " if $i < 10;
      print $i , ". " , $_ , "\n";
   }


   print "Enter number: ";

   while (1) {
      $_ = int <STDIN>;

      chomp;
      exit if lc($_) eq "quit";

      last if ( $_ > 0 or $_ <= scalar(@_)) ;
      print "Not a valid response. Try again.\nEnter number: ";
   }

   $_--;

   # users count starting at one, but arrays are zero-based

   return $_[$_] unless wantarray;

   # return the value unless in list context.

   return ($_[$_] , $_);

   # if in list context, return value and also the index of the value.

}

sub display_lines () {


   our ($longestline, @lines);

   my ($i, $j, $lineformat, $cols, $rows, $entry);

   $lineformat = "%-" . (3 + $longestline) . "s";

   $cols = int ( 80 / (3+$longestline) );

   $rows = int ((scalar @lines) / $cols) ;
   # number of rows

   $rows++ if ((scalar @lines) % $cols) ;
   # add a row if there's a remainder

   for ($i = 0 ; $i < $rows ; $i++ )  {
      for ($j = 0; $j < $cols ; $j++ )  {

          $entry = ($j*$rows) + $i;
          next if $entry > $#lines ;
          printf $lineformat , $lines[$entry];

      }
      print "\n";
   }

}

sub pick_line () {

   our (@lines);

   local ($_);

   my ($input, @matches);

   print "\n" , "-" x 79 ,
         "\nHere are all the lines (except line 56; you must do that one by hand).\n" ,
         "Pick the one you want.\n\n";

   display_lines();

   INPUT: while (1) {

      print "Enter line: ";
      $input = uc(<STDIN>);

      chomp ($input);;
      exit if $input eq "QUIT";

      redo INPUT if $input eq "";

      foreach $_ (@lines) {
         last INPUT if $_ eq $input;
      }

      @matches = grep /$input/ , @lines;

      next INPUT unless scalar(@matches);

      if (scalar (@matches) == 1)  {
         $input = $matches[0];
         last INPUT;
      }

      $input = pick_list (
      "Your entry matched the following. Please pick one:",
                        @matches);

      last INPUT;

   } continue {

      print $input, " is not a valid response. Try again.\n";

   }

   return $input;

}


# -----------------------------------------------------------------
# ---- READ DATA FROM DISK ROUTINE
# -----------------------------------------------------------------

sub read_fullsched ($) {


   our (%fullsched);

   %fullsched = ();

   my $line = $_[0];

   my (@wholesched, @thesetimes);
   my ($wholesched , $day_dir, $row, $note, $route, $spec_days , $tp) ;

   local ($_);
   local ($/) = "\n---\n";

   open IN , "$line.sls";

   until (eof(IN)) {

      $wholesched = <IN>;

      chomp($wholesched);
         
      @wholesched = (split ("\n", $wholesched));
            
      $day_dir = shift (@wholesched);

      @{$fullsched{$day_dir}{"NOTEDEFS"}} = split (/\t/ , shift (@wholesched)) ;

      shift @{$fullsched{$day_dir}{"NOTEDEFS"}};
      # gets rid of "Note Definitions"

      @{$fullsched{$day_dir}{"TIMEPOINTS"}} = split (/\t/, shift @wholesched);
      @{$fullsched{$day_dir}{"TP"}} =  split (/\t/, shift @wholesched);

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

      read_fullsched($line);
      # now we have the data

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

      print "\n---\n" , join("-" , @{$outsched[$column]{"HEADNUM"}});
      print "\t" , $outsched[$column]{"HEADDAYS"};
      print "\t" , $outsched[$column]{"TP2USE"};
      print "\t" , $outsched[$column]{"LASTTP2USE"};
      print "\t" , $outsched[$column]{"HEADDEST"};

      $column++;
       
   }

# now we have our $outsched, only it's not in order.  

print "\n\n";

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

   our (@outsched, %longdaynames);
   
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
      }

   } else {

      # more than one kind of day, so use the standard.
      $daystring = $longdaynames{$daycode};

   }

   return $daycode , $daystring;

}

sub headnum ($) {

   # decides which route number to use at the top.

   # my @routes = @_;

   my $column = $_[0];

   my (@temp, %routes, @headnum) =();

   our (@outsched);

   local($_);

   foreach (sort byroutes @{$outsched[$column]{"ROUTES2USE"}}) {
        @temp = split (/(?<=\d)(?=\D)/);
        $temp[1] = "BLANK" unless $temp[1];
        push @{$routes{$temp[0]}} , $temp[1];
   }
   # so now the hash %routes has keys which are the numeric parts,
   # and values which are a reference to a list of the letter parts.
   # i.e., for the 51, %routes will be (  51 => [ "BLANK" , "A" ] )
   # note that the "sort byroutes" means that the final array will be
   # sorted

   foreach (keys %routes) {

      my $number = $_;

      $number .= $routes{$_}[0] 
             if scalar (@{$routes{$_}}) == 1 and $routes{$_}[0] ne "BLANK";
      # if there's only one letter part, and it isn't "BLANK", add it to 
      # $temp

      push @headnum, $number;
   }
   
   return sort byroutes @headnum;

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
 
      $outsched[$column]{"NOTEKEYS"}{$_} = "Route $_";

   }
} 

sub get_output_filename () {

   return "output_test.txt";

}


sub getcolor($) {

   local $_ = $_[0];

   return "Local" if /^\d\d?/;
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
 
sub output_outsched () {

   our (@outsched, %dirhash, %dayhash, %tphash);
   my ($head, $thismark, @thesemarks, %routes,
       $route, $lasttp, $temp, $tpnum,
       $ampm, $defaultheadtp, @markdefs, %usedmarks);
   local ($_);

   my $markcounter = 0;

   @markdefs = ();

   open OUT, ">" . get_output_filename();

   @outsched = sort 
       {
        byroutes ($a->{"HEADNUM"}[0], $b->{"HEADNUM"}[0]) or 
        $dayhash{$b->{"DAY"}} <=> $dayhash{$a->{"DAY"}} or
        $dirhash{$b->{"DIR"}} <=> $dayhash{$a->{"DIR"}}
       } @outsched;


   $defaultheadtp = get_head_timepoints ("TP2USE");

   foreach my $column (@outsched) {


      foreach (@{$column->{"ROUTES2USE"}}) {
         $routes{$_}=1;
      }

      $head = join ("-" , @{$column->{"HEADNUM"}});
      
      # the gobbeldygook in the print statements are the quark tags
      print OUT
            '@Column head:',                                   # style
            '<*d(' , length($head) +1 , ',2)' ,                # drop cap
            'c"' , getcolor($column->{"HEADNUM"}[0]) , '">';   # color

      # at some point, we may want to do some other kind of formatting if
      # there are two or more head numbers.

      print OUT "$head ";

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
              "are for Route $_.";
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
               "Buses will arrive somewhat later at this location.";
         }
 
         push @thesemarks, $thismark;

      }

      print OUT "<V>" , join (", ", sort {$a <=> $b} @thesemarks), "<V>" 
           if scalar (@thesemarks);

      #<V> is "superior" type

      print OUT "<\\c>";                                     # next column

      print OUT '@times:' ;                                    # style

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
             print OUT ($ampm eq 'a' ? '@amtimes:' : '@pm_times:' );
             $prev = $ampm;
         }
         # if $ampm not the same as the last one, print the appropriate
         # style sheet spec, and set the previous to be this one

         substr($_, -2, 0) = ":";

         print OUT "$_";

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
                   $temp = "Route $route";
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

    print OUT '@noteheaders:Light Face = a.m.<\n><b>Bold Face = p.m.<b>';
    print OUT "\n";
    print OUT '@noteheaders:<b>Unless otherwise specified, departure times are given for ';
    $_ = $tphash{$defaultheadtp};
    s/\&/and/;
    s/\.$//;
    print OUT "$_. Buses will arrive somewhat later at this location.<b>\n";

    if (scalar @markdefs) {

       print OUT '@notedefs:';

       for (my $i = 1; $i < scalar (@markdefs); $i++) {

          print OUT "$i. " , $markdefs[$i] , "\n";

       }

    }

    close OUT;

}
