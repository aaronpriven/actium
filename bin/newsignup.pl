#!/usr/bin/perl
# vimcolor: #001800

# newsignup.pl 

# This program changes the difficult-to-deal-with files from
# Transitinfo and changes them to easier-to-deal-with TSV files.

use strict;

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skedfile qw(Skedwrite);
use Myopts;
use Skeddir;
use Byroutes 'byroutes';

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

our (%options);    # command line options
our (%privatetps); # lists of private timepoints
my  (@index);      # data for the index

push @index, "SkedID\tTimetable\tLines\tDay\tDir\tTP9s";

Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

$| = 1;

print "newsignup - create a new signup directory\n\n" unless $options{quiet};

my $signup;
$signup = (Skeddir::change (\%options))[2];
print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

do "privatetimepoints.rc"
  or warn "Can't load $signup/privatetimepoints.rc";

# this loads the list of private timepoints

######################################################################
# ask about effective date
######################################################################

print "Enter an effective date for this signup, please.\n";

$_ = <STDIN> ;
until ($_) {
   print "No blank entries, please.\n";
   $_ = <STDIN> ;
}

print "Thanks!\n\n";

open OUT , ">effectivedate.txt" 
    or die "Can't open effectivedate.txt for output";
print OUT $_ ;
close OUT;


######################################################################
# set up per-file loop
######################################################################

my @skeds = glob ("scd/AC_[A-Za-z0-9]*.scd");

foreach (@skeds) {s#^scd/AC_## ; s#.scd$##; } 
# so @skeds now has "line_day_dir" for each schedule
# this will break if the filenames change

my @linegroups = @skeds;
{
   my (%seen) = ();
   @linegroups = sort byroutes (grep { s/_.*// ; ! $seen{$_}++ } @linegroups);
} # so @linegroups is now a list of lines

######################################################################
# loop over each line group
######################################################################

foreach my $linegroup (@linegroups) {

   my %alldata = ();

   next if $linegroup eq "56";
   # our dear friends in planning have seriously broken the 56.

   print "$linegroup " unless $options{quiet};

   my @theseskeds = grep /^${linegroup}_/ ,  @skeds;
   foreach my $thissked (@theseskeds) {

      # print "[$thissked] ";
   
      my (undef , $day, $dir) = split(/_/ , $thissked);
   
      my $dataref = read_scdfile($thissked);

      $dataref->{DAY} = $day;
      $dataref->{DIR} = $dir;
      $dataref->{LINEGROUP} = $linegroup;
      $dataref->{SKEDNAME} = $thissked;
   
      # now the data is populated
   
      remove_private_timepoints($dataref);

      remove_blank_columns($dataref);
   
      # if we are likely to have any other possible mergers,
      # -- e.g. weekday and Saturday schedules being the same, but different
      # from Sunday -- we can add those. But I think that's unlikely.

      $alldata{$thissked} = $dataref;

   }

   merge_days (\%alldata, "SA" , "SU" , "WE");
   merge_days (\%alldata, "WD" , "WE" , "DA");

   foreach my $dataref (values %alldata) {
      Skedwrite ($dataref, "-a.txt");
      merge_columns ($dataref);
      Skedwrite ($dataref, "-s.txt");
      push @index, skedidx_line ($dataref);
   }
}

print "\n" unless $options{quiet};

open IDX, ">Skedidx.txt" or die "Can't open $signup/skedidx.txt";
print IDX join("\n" , @index) , "\n" ;
close IDX;

print <<"EOF" unless $options{quiet};

Index $signup/Skedidx.txt written.
Remember to import it into a clone of the FileMaker database "Skedidx.fp5"
or else the databases won't work properly.
EOF

######################################################################
#### end of main, and
#### start of subroutines internal to newsignup
######################################################################

sub read_scdfile {

   # this routine reads all the data in the .scd file and puts it
   # in the %data structure.

   # $data{ROUTES}[$row]    - routes listed in row
   # $data{NOTES}[$row]     - notes listed for row
   # $data{SPECDAYS}[$row]  - special days listed for row
   #                           e.g., "SD" school days, "TF" for Tues/Fri
   # $data{TIMES}[$column][$row] - times in column and row

   my %data = ();
   my $scdfile = "scd/AC_$_[0].scd";

   open IN, "<$scdfile" 
      or die "Can't open file $scdfile\n"; 

   local $_ = <IN>; 
   # blank line at the top of the file is thrown away

   ####### two top lines #######

   my @toplines = (scalar (<IN>), scalar(<IN>) );

   foreach (@toplines) {
      chomp;
      $_ = substr($_,8);
      s/\s+$//;
   }
   # eliminate leading and trailing spaces

   my $numpoints =  1 + int ( length($toplines[0]) / 6 );
   # There are 6 characters per timepoint: a blank space in front
   # (actually this is used for two-digit times like 10:00), four
   # characters for the point, and a space in back.

   # Since we've stripped the final spaces, we know that it will actually
   # be one short of the real number, so that's why the 1+ is added.

   my $unpacktemplate = "A6" x $numpoints;
   # that gives the template for the unpacking. There are $numpoints
   # points, and six characters to each one.  The capital A means to
   # strip spaces and nulls from the result. We use this template later
   # to unpack the times, also.

   @{$data{"TP"}} = 
      unpack ($unpacktemplate, $toplines[0])  ;
   my @tp2 =  unpack ($unpacktemplate, $toplines[1])  ;

   {
   my %seen = ();
   foreach (@{$data{"TP"}}) {
      $_ .= shift (@tp2); 
      s/^\s+//;
      $_ .= "=" . $seen{$_} if $seen{$_}++;
   }
   }
   # now $data{TP} is populated
   # If there's a duplicate timepoint, it has a "=" and number appended to it

   $data{NOTEDEFS} = [];
   # initialize this to an empty array, since otherwise
   # things that expect it to be there break

   ####### main body of schedule #######

   ROW:
   until (($_ = <IN>) =~ /timepoints/) {
      # keep reading data until the "key to timepoints" is reached
      chomp;
      next unless $_;
      next if /RTE/;
      next if /NUM/;
      # go to the next one if it's blank, or if it has RTE or NUM in it,
      # which means it must be a line with repeated timepoint info, which
      # we do not need.

      ## it's a note definition
      if (substr($_, 3, 1) eq "-") {
          my $note = substr($_,0, 2);
          $note =~ s/\s+//g;
          # strip spaces from $note
          my $notedef = substr($_, 5);
          push @{$data{"NOTEDEFS"}}, "$note:$notedef";
          next ROW;
         # If it's got a hyphen in the fourth position, that means we think
         # it's a note definition, and so we add it to {"NOTEDEFS"}
      }

      # it's a regular line with times in it

      # deal with days, notes, routes
      push @{$data{"SPECDAYS"}}, substr($_,0,2);
      push @{$data{"NOTES"}},    substr($_,2,1);
      push @{$data{"ROUTES"}},   substr($_,3,5);
      $_ = substr($_,8);

      # now $_ contains just times

      my $column = 0;
      foreach my $tp (unpack ($unpacktemplate, $_)) {
         $tp =~ s/^\s+//;
         push @{$data{"TIMES"}[$column]}, $tp;
         $column++;
      }

      # now the times are in %data for this line
   }

   ###### clean up schedule and return ######

   s/\s//g foreach (@{$data{ROUTES}} , @{$data{NOTES}} , @{$data{SPECDAYS}});
   # eliminate all spaces from ROUTES, NOTES, and SPECDAYS

   # %data is now populated

   close (IN);

   return \%data;

}

sub remove_private_timepoints {

   my $dataref = shift;

   our (%privatetps);

   my (%theseprivatetps);

   $theseprivatetps{$_} = 1 foreach (@{$privatetps{$dataref->{LINEGROUP}}});

   my $tp = 0;
   while ( $tp < ( scalar @{$dataref->{"TP"}}) ) {
      if ($theseprivatetps{$dataref->{"TP"}[$tp]}) {
         splice (@{$dataref->{"TIMES"}}, $tp, 1);
         splice (@{$dataref->{"TP"}}, $tp, 1);
         splice (@{$dataref->{"TIMEPOINTS"}}, $tp, 1);
         next;
      }
      $tp++;
   }

}


sub remove_blank_columns {

   my $dataref = shift;

   my $tp = 0;
   while ( $tp < ( scalar @{$dataref->{"TP"}}) ) {
      # loop around each timepoint
      unless (join ("", @{$dataref->{"TIMES"}[$tp]})) {
         # unless there is some data in the TIMES for this column,
         splice (@{$dataref->{"TIMES"}}, $tp, 1);
         splice (@{$dataref->{"TP"}}, $tp, 1);
         # delete this column
         next;
      }
   $tp++;
   }

}

sub merge_days {

   my ($alldataref, $firstday, $secondday, $mergeday) = @_;
   # the last three are, for example, (SA, SU, WE) or (WD, WE, DA)
   
   my $count = 0;
   
   my (@firstscheds, @secondscheds);
   
   @firstscheds = sort grep (/$firstday/ , (keys %$alldataref) ) ; 
   @secondscheds = sort grep (/$secondday/ , (keys %$alldataref) ) ; 
   
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
   
   DAY: foreach my $day (0 .. (scalar(@firstscheds - 1))) {
   
      foreach ( qw(TP ROUTES SPECDAYS TIMES NOTES NOTEDEFS) ) {
   
         next DAY if scalar @{$alldataref->{$firstscheds[$day]}{$_}} 
                  != scalar @{$alldataref->{$secondscheds[$day]}{$_}}  ;

      }
      # if the number of timepoints or rows, etc., are different, skip it
      
      foreach ( qw(TP ROUTES SPECDAYS NOTES NOTEDEFS )) {
      
         next DAY 
            if join ("" , @{$alldataref->{$firstscheds[$day]}{$_}})      ne
               join ("" , @{$alldataref->{$secondscheds[$day]}{$_}}) ;
      }
      # if the text of any of the data (other than TIMES) is different skip it

      for (my $column = 0; 
           $column < scalar @{$alldataref->{$firstscheds[$day]}{"TIMES"}} ;  
           $column++) {
         next DAY
           if join ("" , @{$alldataref->{$firstscheds[$day]}{TIMES}[$column]}) ne
              join ("" , @{$alldataref->{$secondscheds[$day]}{TIMES}[$column]});
      }

      # if any of the times are different, skip it.
   
      # At this point, we know they're identical.
      # References make it pretty easy.
      
      my $newschedname = $firstscheds[$day];
      
      $newschedname =~ s/$firstday/$mergeday/;
      
      $alldataref->{$newschedname} = $alldataref->{$firstscheds[$day]};
      $alldataref->{$newschedname}{DAY} = $mergeday;
      $alldataref->{$newschedname}{SKEDNAME} = $newschedname;
      
      # remember, that's a reference. Same reference, same thing.
      
      delete $alldataref->{$firstscheds[$day]};
      delete $alldataref->{$secondscheds[$day]};
      
      # so now, the original two days are gone, 
      # but the first day is still stored in $alldataref->{$newschedname}  
      
      $count++;
   }
   
   return $count;
   
   # returns the number of merged schedules. 
   # I don't see that it actually matters.
   
}


sub merge_columns {

   my $dataref = shift;
 
   ### Merge adjacent columns with the same timepoint (i.e., 
   ### where a point says "arrives 10:30, leaves 10:35" just use the latter)

   my $prevtp = "";
   my $tp = 0;
   
   TIMEPOINT: while ( $tp < ( scalar @{$dataref->{"TP"}}) ) {
   
      unless ($dataref->{TP}[$tp] eq $prevtp) {
          $prevtp = $dataref->{TP}[$tp];
          $tp++;
          next TIMEPOINT;
      }

      # unless they're the same timepoint, increment the counter
      # and go to the next one

      # so if it gets past that, we have duplicate columns

      splice (@{$dataref->{"TP"}}, $tp, 1);
      splice (@{$dataref->{"TIMEPOINTS"}}, $tp, 1);
      # that gets rid of the extra TP and TIMEPOINTS
      
      for (my $row =0; $row < scalar @{$dataref->{"TIMES"}[$tp]}  ;  $row++) {
      
         $dataref->{"TIMES"}[$tp - 1][$row]  
            = $dataref->{"TIMES"}[$tp][$row] 
                if $dataref->{"TIMES"}[$tp][$row];
             
      }
      # that takes all the values in the second column and puts them in the first column

      splice (@{$dataref->{"TIMES"}}, $tp, 1);
      # gets rid of extra TIMES array, now duplicated in the previous one

   }

}

sub skedidx_line {

   my $dataref = shift;

   my @index = ();
   my %seen = ();

   my @routes = sort byroutes grep {! $seen{$_}++}  @{$dataref->{ROUTES}};

   push @index, $dataref->{SKEDNAME};
   push @index, $dataref->{LINEGROUP};
   push @index, join("\035" , @routes);
   # \035 says "this is a repeating field" to FileMaker
   push @index, $dataref->{DAY};
   push @index, $dataref->{DIR};
   push @index, join("\035" , @{$dataref->{TP}});

   return join("\t" , @index);

}
