#!/usr/bin/perl5

# newsignup.pl part of AC's Single Timepoint Schedule program

# It creates the index files and data files used each time
# a Single Timepoint Schedule is created.

# To run this program, take the .scd files from Transitinfo and 
# put them in a directory. On a command-line system, run 
# the program with the directory name as the first entry in the 
# command line (such as "newsignup.pl /schedule/scd")

# Note that this assumes that the files are in the native text form
# (for DOS/Windows/NT, that is, the line ends are CR/LF). 

require 'pubinflib.pl';

# someday I'm going to have to learn how to write modules

chdir &get_directory or die "Can't change to specified directory.\n";

# so we cd to the appropriate directory

my ($temp1, $temp2) = &assemble_line_and_file_lists;

@lines = @$temp1;
@scdfiles = @$temp2;

&prepare_index_for_writing;

# now @lines is a list of lines, and @scdfiles is a list of scdfiles

foreach my $linenum (@lines) {

   print "$linenum ";

   undef %fullsched;
   # reset the full schedule variable before the loop.

   foreach my $schedfile (&get_scheds_for_line ($linenum)) {
      
      undef @schedrows;
      # reset the various other arrays before the loop.

      open IN, "<scd/$schedfile" or die "Can't open file scd/$schedfile.\n"; 

      $schedname = $schedfile;
      $schedname =~ s/^AC_${linenum}_//;
      $schedname =~ s/.scd$//;

#      print $schedname , " ";

      @toplines = &get_schedule_info;

      # now @toplines is set to the first two lines,
      # %fullsched{$schedname}{NOTEDEFS} is set to the note definitions,
      # and @schedrows has all the rest of the schedule lines.
      # The timepoint info hasn't been read yet.

      &get_timepoint_info($schedname);

      close (IN);
      # close the schedule

      &parse_schedule;

      &add_tps_to_tphash;

   }   


   &merge_days ("SA" , "SU" , "WE");
   &merge_days ("WD" , "WE" , "DA");

   # if we are likely to have any other possible mergers,
   # -- e.g. weekday and Saturday schedules being the same, but different
   # from Sunday -- we can add those. But I think that's unlikely.

   &output_schedule ("$linenum.acs");

   &merge_columns;

   &output_schedule ("$linenum.sls");

   &output_index ($linenum);

}

&close_index;

&output_tphash;

print "\n";

