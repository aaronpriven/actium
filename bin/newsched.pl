#!/usr/bin/perl5

&process_command_line;

chdir $directory;

&assemble_lists;

foreach $thisline (@lines) {

   &makedata ($thisline)

}


sub process_command_line {

###########################################################
##### PROCESS COMMAND LINE 
###########################################################


if (@ARGV) {
   $directory = $ARGV[0];
} else {

   print <<EOF;
newsched - Prepare schedule information from files from Transitinfo.

Syntax:

     newsched.pl directory

Where "directory" contains the .scd files received from transitinfo.
EOF
die;

}

# That means that you need to specify a directory in the command line.

}

###########################################################
##### ASSEMBLE LISTS OF FILES AND LINES
###########################################################

sub assemble_lists {

@scdfiles = sort <*.scd>

# so @scdfiles has all the files in it, sorted

$prev = "";
@lines = ();

foreach $dummyvar (@scdfiles) {

   $_ = $dummyvar

   # one has to use the $dummyvar and then the assignment, 
   # otherwise the next two statements modify the @scdfiles array,
   # which is not what we want.
 
   s/^AC_//;
   s/_.*//;
   next if $_ eq "56";

# THIS IS SPECIAL. LINE 56 IS BROKEN BECAUSE THERE ARE TWO SEPARATE SCHEDULES FOR LINE 56
#  (THE LATE NIGHT SCHEDULE AND THE REGULAR SCHEDULE). IF THIS CHANGES, THE ABOVE CODE
#  SHOULD BE REMOVED.

   push @lines, $_ unless $prev eq $_;

}

# So now @lines contains all the lines.

}



sub makedata {

my $line = @_[0];

@thesefiles = grep (/^AC_$line/, @scdfiles) ;

# So now @thesefiles contains a list of files on this line.

##### INPUT AND PARSE DATA ######

foreach $thisfile (@thesefiles) {


   open IN, "<" . $thisfile; 
   # open the schedule URL

   undef @schedrows;

   &get_schedule_info;


   &get_timepoint_info;


   close (IN);
   # close the schedule


   &parse_schedule;

}

&merge_weekends;

&output_schedule;


sub output_schedule {



if ($cgiflag) {

   $tempfile = "STDOUT";
   print $tempfile "Content-type: text/tab-separated-values; name=\"$linenum.txt\"\n";
   print $tempfile "Content-Disposition: attachment; filename=\"$linenum.txt\"\n\n";



} else {
 
   mkdir $directory, 0777 unless -d $directory;
   open TEMPFILE , ">$directory/$linenum.txt";
   $tempfile = TEMPFILE;
   print "Writing line $linenum to file $directory/$linenum.txt.\n";

}

foreach $schedname (keys %fullsched) {

   print $tempfile $schedname , "\n";
   print $tempfile "Notes\tLine number\t" , join ("\t"  , @{$fullsched{$schedname}{"TIMEPOINTS"}} ) , "\n"; 
   print $tempfile "NOTE\tRTE NUM\t" , join ("\t"  , @{$fullsched{$schedname}{"TP"}} ) , "\n"; 

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

      print $tempfile $fullsched{$schedname}{"NOTES"}[$i] , "\t" ;
      print $tempfile $fullsched{$schedname}{"LINES"}[$i] , "\t" ;

      foreach (@{$fullsched{$schedname}{TIMES}}) {
          print $tempfile $_ -> [$i] , "\t";

      }

     # ok. $_ becomes the *reference* to the first, second, etc. list of times.  

      print $tempfile "\n";

   }

   print $tempfile "---\n";

}

close $tempfile;

}


#sub bysecondword {

#   my ($null, $aword, $bword);
#   ($null, $aword) = split (/\s+/ , $a) ;
#   ($null, $bword) = split (/\s+/ , $b) ;
   
#   $aword cmp $bword;

#}





sub merge_weekends {

@scheds = sort grep (/(Sun|Satur)day/ , (keys %fullsched) ) ; 
   
return unless @scheds;

DAY: foreach $day (0,2) {

   foreach ( qw(TP LINES TIMES TIMEPOINTS NOTES) ) {

      next DAY if scalar @{$fullsched{$scheds[$day]}{$_}} 
         != scalar @{$fullsched{$scheds[$day+1]}{$_}}
      
   }
   
   # if the number of timepoints or rows are different, skip it
   
   foreach ( qw(TIMEPOINTS NOTES LINES TP)) {
   


      next DAY 
         if join ("" , @{$fullsched{$scheds[$day]}{$_}}) 
            ne join ("" , @{$fullsched{$scheds[$day+1]}{$_}}) ;
   }
   
   # if the text of any of the data is different skip it
   
   for ($_ =0; $_ < scalar @{$fullsched{$scheds[$day]}{"TIMES"}[0]}  ;  $_++) {
   
      next DAY
         if join ("" , @{$fullsched{$scheds[$day]}{"TIMES"}[$_]})
            ne join ("" , @{$fullsched{$scheds[$day+1]}{"TIMES"}[$_]})

   }

   # if any of the times are different, skip it.
   

   # At this point, we know they're identical. References make it pretty easy.
   
   $newschedname = $scheds[$day];
   
   $newschedname =~ s/(Sun|Satur)day/Weekend/;
   
   $fullsched{$newschedname} = $fullsched{$scheds[$day]};
   
   # remember, that's a reference. Same reference, same thing.
   
   delete $fullsched{$scheds[$day]};
   delete $fullsched{$scheds[$day+1]};
   



   # so now, the original two days are gone, but the first day is still stored
   # in $fullsched{$newschedname}  (which is going to be "[something]bound Weekend Schedule")
   
}

}



sub get_schedule_info {

   do {
      $_ = <IN>;
   } until /<pre>/i;
   # read but do nothing with all the front matter until we get to the <pre>, 
   # which is the section with the actual schedule in it

   ### Get the schedule info ####
   
   $_ = <IN>;
   # read the first line

   until (m@timepoints@) {

   # keep reading data until the "key to timepoints" is reached

      if (/<hr>/)
   
      # hr signals a block of repeated timepoint info, which we don't
      # need

      {
          $_ = <IN>;
          $_ = <IN>;
          next;
      }
      # read but do nothing with the repeated timepoint info

      chomp;

      push @schedrows, $_ if ($_ and not /only/i);
      # add it to the array, unless it's blank or is "School Days Only"
      # or "School Holidays Only" 

      $_ = <IN>;

   }

   # @schedrows now has all the raw schedule information in it.

}


sub get_timepoint_info {

   $_ = <IN>;
   # read the next line (the one after "Key to timepoints")

   until (m@</pre>@i) {
   # keep reading data until the end of the pre section
   
      chomp;
      $_ = substr ($_, 11);
      push @{$fullsched{$schedname}{"TIMEPOINTS"}}, $_;
      $_ = <IN>;

   }

   # {TIMEPOINTS} is now the list of timepoints

}

sub parse_schedule {

@toplines = splice (@schedrows, 0, 2) ;

# remove top timepoint info from @schedrows and put into @toplines


### get notes

$noteflag = 0;
$firstlinecode = substr($toplines[0],0,3);

if ($firstlinecode eq "   ") {
   $noteflag = 1;
   # there are notes 
   
   foreach (@schedrows) {
       push @{$fullsched{$schedname}{"NOTES"}}, substr($_,0,3);
       $_ = substr($_,3);
   }
   # that takes the note out of @schedrows and puts it in {NOTES} instead.

   foreach (@toplines) {
       $_ = substr($_,3)
   }

   # gets rid of the extra space in the top lines

}

$firstlinecode = substr($toplines[0],1,3);
# get the first line again, to check for lines

### get lines

$linesflag = 0;

if ($firstlinecode eq "RTE") {

   $linesflag = 1;

   foreach (@schedrows) {
       push @{$fullsched{$schedname}{"LINES"}}, substr($_,0,5);
       $_ = substr($_,5);
   }

   foreach (@toplines) {
       $_ = substr($_,5)
   }
   # gets rid of the "RTE / NUM" bit
   
   # in an amazingly similar manner to the last one, that takes the line out of
   # @schedrows and puts it in {LINES} instead.


}


### clean up notes and lines

foreach $ref ( $fullsched{$schedname}{"LINES"}, $fullsched{$schedname}{"NOTES"}  ) {
   
   grep ( s/\s//g , @$ref);
   # eliminate spaces

}

### get {TP} information from @toplines

# note: the {TP} is the short, four-character timepoint info. {TIMEPOINTS} is the long, verbal one.

grep ( s/\s+$// , @toplines);
# eliminate extra spaces

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
# I strongly suspect that I will not in fact need this, but 
# this way I have it in case I change my mind.


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


