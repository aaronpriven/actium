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
sub usedrow ($) ;
sub build_usedrows ($$@) ;
sub build_outsched (@) ;
sub build_outsched_notes_and_times ($$$$$) ;
sub headdest ($$) ;
sub headdays ($$) ;
sub headnum() ;
sub note_definitions ($) ;
sub build_usedhash($$) ;
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
          SU => "Sundays" ,
        )

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

sub usedrow ($) {

   our @usedrows;
   return $usedrows[$_[0]];

}

sub build_usedrows ($$@) {
   
   our (%fullsched, @usedrows);
   my ($day_dir, $tp, @routes) = @_;
   my ($lasttpnum, %routes);

   @usedrows = ();

   foreach (@routes) {
      $routes{$_}=1;
   }
   # provides an easy "is an element" lookup

FSROW: 
   for (my $fsrow = 0; $fsrow < scalar @{$fullsched{$day_dir}{"TIMES"}[$tp]};  
            $fsrow++) {

      # $fsrow is the row in %fullsched

      next FSROW unless $routes{$fullsched{$day_dir}{"ROUTES"}[$fsrow]};
      # if this route isn't on the list of routes to use, skip this row
      # (so if we're printing out a 40 schedule, the 43 won't show up)

      $_ =  $fullsched{$day_dir}{"TIMES"}[$tp][$fsrow];
      # $_ is the time for this row

      next FSROW unless $_;
      # if there's no time, skip it

TPS: 
      for ( my $thistp = (scalar @{$fullsched{$day_dir}{"TP"}} -1 ); 
                $thistp >= 0;  $thistp-- ) {

          $lasttpnum = $thistp;
          last TPS if $fullsched{$day_dir}{"TIMES"}[$thistp][$fsrow];
      }

      $fullsched{$day_dir}{"LASTTP"}[$fsrow] = 
                $fullsched{$day_dir}{"TP"}[$lasttpnum];

      # save the lasttp abbrev for when we figure out where the destination is

      next FSROW if $lasttpnum eq $tp;
      # Skip this time if it's the last one in the row.
      # We don't want to tell people when buses leave from this point
      # if they go no further from here

      # ok, now we know this time should be included

      $usedrows[$fsrow] = 1;

   }

   build_usedhash ($day_dir, $tp);

}

sub build_usedhash($$) {

   our (%fullsched, %used, %notes);
   my ($day_dir, $tp) = @_;
   %used = ();

   local ($_);

   for (my $fsrow = 0; $fsrow < scalar @{$fullsched{$day_dir}{"TIMES"}[$tp]};  
         $fsrow++) {

       next unless usedrow($fsrow);
       # skip it if it's not used

       $_ = $fullsched{$day_dir}{"NOTES"}[$fsrow];
       $_ = "BLANK" unless $_;
       $used{"NOTES"}{$_}++;

       # I'm pretty sure it won't matter if we don't turn "" to "BLANK"
       # but I'm not sure enough.

       $_ = $fullsched{$day_dir}{"SPEC DAYS"}[$fsrow];
       $_ = "BLANK" unless $_;
       $used{"SPEC DAYS"}{$_}++;

       $used{"ROUTES"}{$fullsched{$day_dir}{"ROUTES"}[$fsrow]}++;

       # ROUTES will never be blank.

   }

   foreach (keys %{$used{"ROUTES"}}) {
 
      $notes{$_} = "Route $_";

   }

}

# -----------------------------------------------------------------
# ---- BUILD_OUTSCHED
# -----------------------------------------------------------------

sub build_outsched (@) {

   our (@outsched , %fullsched, %notes, %longdaynames);

   @outsched = ();
   %notes = ();

   local ($_);

   my ($column, $daycode, $lasttp, $line, $day_dir, $day, $tp, 
       @routes );

   $column = 0;

   foreach my $pickedtp (@_) {
   # loop around each timepoint (irrespective of order; we'll get that later)

      ($line, $day_dir, $tp, @routes) = split ("\t" , $pickedtp);

      read_fullsched($line);
      # now we have the data

      note_definitions($day_dir);
      # read all note definitions into %notes
 
      build_usedrows($day_dir, $tp, @routes);
      # Now we know that usedrow(x) is 1 if the xth row is a valid one,
      # an 0 if it should be skipped. 

      # also puts route numbers into %notes

      @{$outsched[$column]{"HEADNUM"}} = headnum();
      # get the header number(s)

      ($daycode, $outsched[$column]{"HEADDAYS"}) = 
           headdays ($day_dir, $tp);
      # get the header day text ("Mon thru Fri", etc.) 

      ($lasttp, $outsched[$column]{"HEADDEST"}) = headdest ($day_dir, $tp);
      # get the header destination text ("To University and San Pablo")
      # $lasttp is the timepoint short string ("UNIV S.P.")
      # also puts the various non-default last tps into %notes
      
      build_outsched_notes_and_times
              ($column, $day_dir, $tp, $lasttp, $daycode);

      # also builds $outsched[column]{NOTES}

      $outsched[$column]{"TP"}=
         $fullsched{$day_dir}{"TP"}[$tp];

      $outsched[$column]{"LASTTP"}=
         $lasttp;

      # save the current timepoint and last timepoint

   } continue {

      print "\n---\n" , join("." , @{$outsched[$column]{"HEADNUM"}});
      print "\t" , $outsched[$column]{"HEADDAYS"};
      print "\t" , $lasttp;
      print "\t" , $outsched[$column]{"HEADDEST"};

      $column++;
       
   }

# now we have our $outsched, only it's not in order.  

print "\n\n";

} 

sub build_outsched_notes_and_times($$$$$) {

   my ($column, $day_dir, $tp, $lasttp, $daycode) = @_;

   my @notes;

   local ($_);

   our (%fullsched, @outsched, %used) ;

   for (my $fsrow = 0; $fsrow < scalar @{$fullsched{$day_dir}{"TIMES"}[$tp]};  
            $fsrow++) {

      next unless usedrow($fsrow);

      push @{$outsched[$column]{"TIMES"}},
            $fullsched{$day_dir}{"TIMES"}[$tp][$fsrow];
      # save the TIMES

      # from here, we save the notes.

      @notes = ();

      $_ = $fullsched{$day_dir}{"NOTES"}[$fsrow];
      push @notes, $_ if $_;

      $_ = $fullsched{$day_dir}{"LASTTP"}[$fsrow];
      push @notes, $_ unless 
            $_ eq $lasttp;
      # add the last timepoint for this row to @notes unless
      # this is the same as the default for the column

      $_ = $fullsched{$day_dir}{"ROUTES"}[$fsrow];
      push @notes, $_ unless $_ eq $outsched[$column]{"HEADNUM"}[0];

      # unless this is the same as the first number in HEADNUM,
      # push this route to @notes

      $_ = $fullsched{$day_dir}{"SPEC DAYS"}[$fsrow];
      push @notes, $_ if ( $_ and $_ ne $daycode) ;
      # add the special days, if it's there, and it's different
      # from the day code

      push @{$outsched[$column]{"NOTES"}} , [ @notes ] ;
      # so now $outsched[$column]{"NOTES"}[thisrow] is a reference
      # to a copy of the array in @notes

   }
}

=pod

If at some point we want to make this the most common route,
rather than the first route, we will have to change the line above,

      push @notes, $_ unless $_ eq $outsched[$column]{"HEADNUM"}[0];

but we will also want to change HEADNUM so it selects the most common
route as well (instead of just sorting alphanumerically by route), or 
possibly create a new part of %outsched so that the most common route is 
given in the header.

The problem is that the columnar format doesn't really fit things
like the 72/73 southbound from El Cerrito, where it can and should 
be treated like one big line.  I've chosen to treat that as though the
73 was a version of the 72.

There aren't really very many of these, so maybe it won't matter. 
Although there are lots of multiroute lines, nearly all of them should
be separate columns: 90/92, even things like the K/KH and S/SA/SB.
Only a few, like the 72/73, are exceptions. I'm assuming we can just
ignore those few exceptions... we'll see how it goes.

=cut



sub headdest ($$) {

   my ($day_dir, $tp) = @_;
   my ($lasttp, $lasttpnum);
   my (%lasttpfreq) = ();
   our (%fullsched, %tphash, %notes);

   for (my $fsrow = 0; $fsrow < scalar @{$fullsched{$day_dir}{"TIMES"}[$tp]};  
            $fsrow++) {
      next unless usedrow($fsrow);
      $lasttpfreq{$fullsched{$day_dir}{"LASTTP"}[$fsrow]}++;
      # print "\t$fsrow:" , $fullsched{$day_dir}{"LASTTP"}[$fsrow];
 
   }

  #   $lasttpnum = 
   $lasttp = 
       (sort { $lasttpfreq{$b} <=> $lasttpfreq{$a} } 
        keys %lasttpfreq)[0];

   print "{" , keys %lasttpfreq , "}\n\n";

   # $headdest = $fullsched{$day_dir}{"TIMEPOINTS"}[$lasttpnum];
   # print "[$lasttpnum]";

   # $lasttp = $fullsched{$day_dir}{"TP"}[$lasttpnum];

   foreach (keys %lasttpfreq) {
      $notes{"TP"} = $tphash {"TP"};
   }


   return $lasttp, $tphash{$lasttp};

}

sub headdays ($$) {

   my ($day_dir, $tp) = @_;

   our %used;
   
   my @used = keys %{$used{"SPEC DAYS"}};
   # now we have the lists of used special days in %used

   our (%notes, %longdaynames);

   my $daycode = (split (/_/ , $day_dir))[1];
   my $daystring;

   if (scalar( @used ) == 1) {
   # if there's only one day present,

      if ($used[0] eq "BLANK") {
         # and it's blank, use the standard day routine

         $daystring = $longdaynames{$daycode};

      } else {
         # if only one day, but it's not blank, use that.

         $daystring = $notes{$used[0]};
         $daycode = $used[0];
      }

   } else {

      # more than one kind of day, so use the standard.
      $daystring = $longdaynames{$daycode};

   }

   return $daycode , $daystring;

}

sub headnum() {

   # decides which route number to use at the top.

   # my @routes = @_;
   my (@temp, $temp, %routes, @headnum) =();

   our (%used);
   my @routes = keys %{$used{"ROUTES"}};

   local($_);

   foreach (@routes) {
        @temp = split (/(?<=\d)(?=\D)/);
        $temp[1] = "BLANK" unless $temp[1];
        push @{$routes{$temp[0]}} , $temp[1];
   }
   # so now the hash %routes has keys which are the numeric parts,
   # and values which are a reference to a list of the letter parts.
   # i.e., for the 51, %routes will be (  51 => [ "BLANK" , "A" ] )

   foreach (keys %routes) {

      $temp = $_;
      # $temp is the number

      $temp .= $routes{$_}[0] 
             if scalar (@{$routes{$_}}) == 1 and $routes{$_}[0] ne "BLANK";
      # if there's only one letter part, and it isn't "BLANK", add it to 
      # $temp

      push @headnum, $temp;
   }
   
   return sort byroutes @headnum;

}

sub note_definitions ($) {

      my $day_dir = $_[0];
      our (%fullsched, %notes);

      foreach (@{$fullsched{$day_dir}{"NOTEDEFS"}}) {
         my ($note, $notedef) = split(/:/);
         $notedef =~ s/ only//i;
         $notes{$note} = $notedef;
      }
      # Now all the note definitions from here are are %notes

} 

sub output_outsched () {

our @outsched;

   print "HEADNUM\t";
   foreach (@{$outsched[0]{"HEADNUM"}}) { print; }
    
   foreach ( qw(HEADDAYS HEADDEST TP LASTTP) ) {
      print "$_\t" , $outsched[0]{$_} , "\n";
   } 

   for (my $i = 0; $i < scalar(@{$outsched[0]{"TIMES"}}) ; $i++) {

      print $outsched[0]{"TIMES"}[$i] , "\t";
      foreach (@{$outsched[0]{"NOTES"}[$i]}) { print"[$_]" if $_; }
      print "\n";

   }
   
}
