#!/usr/bin/perl5

# newsignup.pl part of AC's Single Timepoint Schedule program

# It creates the index files and data files used each time
# a Single Timepoint Schedule is created.

# Actually, I don't think I'll use the index file after all, 
# or for that matter the non-slim schedule files, but
# it hurts nothing to keep producing it.

# To run this program, take the .scd files from Transitinfo and 
# put them in a directory. On a command-line system, run 
# the program with the directory name as the first entry in the 
# command line (such as "newsignup.pl /schedule/scd")

# Note that this assumes that the files are in the native text form
# (for DOS/Windows/NT, that is, the line ends are CR/LF). 

require 'byroutes.pl';

# someday I'm going to have to learn how to write modules

chdir &get_directory or die "Can't change to specified directory.\n";

# so we cd to the appropriate directory
# The &get_directory routine is currently OS-specific, or at least,
# depends on the presence of a command line.

&assemble_line_and_file_lists;

&prepare_index_for_writing;

# now @lines is a list of lines, and @scdfiles is a list of scdfiles

foreach $linenum (@lines) {

   print "$linenum ";

   undef %fullsched;
   # reset the full schedule variable before the loop.

   foreach $schedfile (&get_scheds_for_line ($linenum)) {
      
      undef @toplines;
      undef @schedrows;
      # reset the various other arrays before the loop.

      open IN, "<$schedfile" or die "Can't open file $schedfile.\n"; 

      $schedname = $schedfile;
      $schedname =~ s/^AC_${linenum}_//;
      $schedname =~ s/.scd$//;

#      print $schedname , " ";

      &get_schedule_info;

      # now @toplines is set to the first two lines,
      # %fullsched{$schedname}{NOTEDEFS} is set to the note definitions,
      # and @schedrows has all the rest of the schedule lines.

      &get_timepoint_info;

      close (IN);
      # close the schedule

      &parse_schedule;

   }   


   &merge_days ("SA" , "SU" , "WE");
   &merge_days ("WD" , "WE" , "DA");

   # if we are likely to have any other possible mergers,
   # -- e.g. weekday and Saturday schedules being the same, but different
   # from Sunday -- we can add those. But I think that's unlikely.

   &output_schedule ("$linenum.acs");

   &merge_columns;

   &output_schedule ("$linenum.sls");

   &output_index;

}

&close_index;

print "\n";


# -----------------------------------------------------------------
# ---- END OF MAIN
# -----------------------------------------------------------------


sub get_scheds_for_line {

  my $line = $_[0];

  return grep ( /^AC_${line}_/ , @scdfiles);

}

### GET_DIRECTORY

sub get_directory {

die "No directory given in command line.\n" unless (@ARGV);

return $ARGV[0];

}


### ASSEMBLE_LINE_AND_FILE_LISTS

sub assemble_line_and_file_lists {

@scdfiles = sort <*.scd>;

unless (scalar(@scdfiles)) {
   die "Can't find any .scd files.";
}

# so @scdfiles has all the files in it, sorted

my %lines = ();

foreach $dummyvar (@scdfiles) {

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

   $lines{"$_"} = 1;

}

# So now keys %lines contains all the lines.

#@lines = sort { $a <=> $b or $a cmp $b} keys %lines;

# that wonderful sort says "sort numerically, but if they're the same
#  numerically, use alphabetical sort."
# Unfortunately, it ends up with the numbers last instead of first.
#  sigh.

@lines = sort byroutes keys %lines;

}




sub get_schedule_info {

   ### Get the schedule info ####
   
   $_ = <IN>; 
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

}

sub get_timepoint_info {

   while (<IN>) {
   # keep reading data until the end of the file
   
      chomp;
      $_ = substr ($_, 11);
      push @{$fullsched{$schedname}{"TIMEPOINTS"}}, $_ if $_;

   } 

   # {TIMEPOINTS} is now the list of timepoints

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

open TEMPFILE , ">$file" or die "Can't open file $file.\n";

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

sub output_index {

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
