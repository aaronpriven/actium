#!/usr/bin/perl
# vimcolor: #001800

# newsignup

# This program changes the extremely-difficult-to-deal-with files from
# Hastus and changes them to easier-to-deal-with tab separated files.

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

use File::Copy;
use Skedfile qw(Skedread Skedwrite trim_sked copy_sked remove_blank_columns);
use Myopts;
use Skeddir;
use Byroutes 'byroutes';

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

# privatetimepoints stuff has been removed 'cause right now there aren't
# any and I don't feel like reimplementing it

our (%options);    # command line options
my  (%index);      # data for the index
my (%pages);       # pages

my %dirnames = ( NO => 'NB' , SO => 'SB' , EA => 'EB' , WE => 'WB' , 
                   CL => 'CW' , CO => 'CC' );
# translates new Hastus directions to old Transitinfo directions

Myopts::options (\%options, Skeddir::options(), 'effectivedate:s' , 'quiet!');
# command line options in %options;

$| = 1; 
# don't buffer terminal output; perl's not supposed to need this, 
# but it does

print "newsignup - create a new signup directory\n\n" unless $options{quiet};

my $signup;
$signup = (Skeddir::change (\%options))[2];
print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

######################################################################
# ask about effective date
######################################################################

my $effectivedate;

if (exists ($options{effectivedate}) and $options{effectivedate} ) {

   $effectivedate = $options{effectivedate};

   print "Using effective date $effectivedate\n\n" unless $options{quiet};

} else {

   print "Enter an effective date for this signup, please.\n";

   $effectivedate = <STDIN> ;
   until ($effectivedate) {
      print "No blank entries, please.\n";
      $effectivedate = <STDIN> ;
   }

   print "Thanks!\n\n";

}

open OUT , ">effectivedate.txt" 
    or die "Can't open effectivedate.txt for output";
print OUT $effectivedate ;
close OUT;


######################################################################
# import headway sheets as pages
######################################################################

my %seenskedname;

{ # block for local scoping

local $/ = "\cL\cM";

foreach my $file (glob ("headways/*.prt")) {
   open (my $fh , $file);

   print "\n$file" unless $options{quiet}; # debug

   my %seenprint = ();
   my $seenprintcount = 0;

   while (<$fh>) {
      chomp;
      my @lines = split(/\r\n/);
      #splice (@lines, -1, 2) ;
      pop @lines;
      pop @lines;
      # gets rid of bottom 2 lines, which are always footer lines

      { # another block for localization
      local $/ = "\r\n";
      chomp @lines;
      }
      last if $lines[3] eq "SUMMARY OF PROCESSED ROUTES:";  

      next if substr($lines[6],8,3) ne "RTE";
      # TODO - THIS WILL THROW AWAY ALL PAGES CONSISTING ONLY OF
      # NOTES CONTINUED FROM THE PREVIOUS PAGE. WILL WANT TO HANDLE
      # THIS AT SOME POINT.

      my %thispage;

      $thispage{LINEGROUP} = stripblanks(substr($lines[3],11,3));
      next if $thispage{LINEGROUP} eq "399";

      # HORRIBLE, HORRIBLE LINE 40 KLUDGE
      $thispage{LINEGROUP} = "43" 
         if $thispage{LINEGROUP} eq "40" and ($lines[1] =~ m/D2/i );

      if ($lines[1] =~ /Week/i) {
         $thispage{DAY} = "WD" 
      } else { 
         $thispage{DAY} = "WE" 
      } #
      $thispage{LGNAME} = stripblanks(substr($lines[3],18));
      $thispage{DIR} = uc(stripblanks(substr($lines[4],11,2)));
      $thispage{DIR} = $dirnames{$thispage{DIR}} if $dirnames{$thispage{DIR}};

      $thispage{SKEDNAME} = join("_" , 
                $thispage{'LINEGROUP'},
                $thispage{DIR},
                $thispage{DAY},
                );

      unless ($options{quiet} or $seenprint{$thispage{LINEGROUP}}++) {
         print "\n" unless ($seenprintcount++ % 19 ) ;
         printf "%4s" , $thispage{LINEGROUP};
      }
         

      if ( $seenskedname{$thispage{SKEDNAME}}++ ) {
         $thispage{SKEDNAME} .= "=" . $seenskedname{$thispage{SKEDNAME}}
      }

      # change SKEDNAME to include a number

      my $timechars = index($lines[6], "DIV-IN") - 64;
      # DIV-IN is the column after the last timepoint column. The last character 
      # of the last column ends two characters before "DIV-IN". The notes in
      # the front comprise 63 characters.

      my $template = "A4 x4 A3 x27 A1 x15 A5 x3" . "A8" x ($timechars / 8); 
      # specdays rte vt note
      # that gives the template for the unpacking. There are $numpoints
      # points, and six characters to each one.  The capital A means to
      # strip spaces and nulls from the result. 

      { # scoping block
      my (undef, undef, undef, undef, @tps) = stripblanks(unpack $template, $lines[6]);
      my (undef, undef, undef, undef, @tps2) = stripblanks(unpack $template, $lines[7]);

      tr/,/./ foreach (@tps , @tps2); 
      # change commas to periods. FileMaker doesn't like commas for some reason.
      for my $thistp (0..$#tps) {
          $tps[$thistp] .= " " . $tps2[$thistp];
      } 
      $thispage{TP} = \@tps;
      }

      $thispage{NOTEDEFS} = [];
      # initialize this to an empty array, since otherwise
      # things that expect it to be there break

      for (@lines[9..57]) {

         next unless $_;
         next if /^_+$/;
         # skip lines that are blank, or only underlines

         last if /^Notes:/; # TODO - SKIP NOTE DEFINITIONS FOR NOW

         my ($specdays, $routes, $vt, $notes, @times) = 
              stripblanks (unpack $template, $_); 

         foreach (@times) {
            if ($_ eq "......") {
               $_ = "" ; 
               next;
            }
            s/\(\s*//;
            s/\s*\)//;
            s/x/a/;
            # Hastus uses "a" for am, "p" for pm, and "x" for am the following
            # day (so 11:59p is followed by 12:00x).
         }

         $notes = "" if $notes eq "RRF";
         # RRF note is "restroom facilities." At least in one case, this prevents
         # merging from taking place. Don't want to tell the general public this
         # anyway

         push @{$thispage{SPECDAYS}} , $specdays;
         push @{$thispage{ROUTES}} , $routes;
         push @{$thispage{VT}} , $vt;
         push @{$thispage{NOTES}} , $notes;

         for (my $col = 0 ; $col < scalar (@times) ; $col++) {
            push @{$thispage{TIMES}[$col]} , $times[$col] ;
         }
 

      } # lines

   $pages{$thispage{SKEDNAME}} = \%thispage;

   } # pages 

} # files
} # local scoping of $/

######################################################################
# All pages are in %pages. Now to combine pages...
######################################################################

# process each page

print "\n\nCombining pages.\n" unless $options{quiet};

foreach my $dataref (values %pages) {
#   remove_blank_columns($dataref);
   # from Skedfile.pm
# shouldn't be necessary with Hastus
   add_duplicate_tp_markers ($dataref);
}

#{
#open (my $fh , ">pages.txt");
#print $fh join("\n" , keys %pages ) , "\n";
#close $fh;
#}

my @skipped;
my @skippedwhy;

SKEDNAME: 
for my $skedname (sort {$a <=> $b} keys %seenskedname) {

   my @morepages = sort byskednamenum grep /^$skedname=/ , keys %pages ; 
   next SKEDNAME unless scalar(@morepages); # only one page? don't combine 

   for my $thispage (@morepages) {
      unless (join ("" , @{$pages{$skedname}{TP}}) eq
              join ("" , @{$pages{$thispage}{TP}}) ) {
        # unless timepoints are identical, skip this bit that 
        # splices unlike timepoints together.

        # If one is subset of the other, and no non-consecutive
        # duplicate timepoint names in longer one, can match.

        my $skednumtps = $#{$pages{$skedname}{TP}} ;
        my $thisnumtps = $#{$pages{$thispage}{TP}} ;

        if ($skednumtps == $thisnumtps) {
           push @skipped, $skedname;
           push @skippedwhy, 1;
           next SKEDNAME;
           # they have equal numbers, but since the timepoints aren't equal
           # (we know this from test done earlier) 
           # we know one is not a subset of the other. skip it.
        }

        my (%bigset , %smallset, $big, $small);

        if ($skednumtps > $thisnumtps ) {
           $big = $skedname;
           $small = $thispage;
        } else {
           $big = $thispage;
           $small = $skedname;
        }
        my $count = 0;
        $bigset{$_} = $count++ foreach @{$pages{$big}{TP}};
        $count = 0;
        $smallset{$_} = $count++ foreach @{$pages{$small}{TP}}; 

        foreach (keys %smallset) {
           unless (exists $bigset{$_}) {
              push @skipped, $skedname ;
              push @skippedwhy, 2 ;
              next SKEDNAME;
           } # if each entry in smallset isn't in bigset, skip this sked
        }

        for my $num (0 .. scalar keys %bigset) {
           if (/=/) {
              (my $sanseq = $pages{$big}{TP}[$num]) =~ s/=.*//;
              unless ($pages{$big}{TP}[$num-1] eq $sanseq) {
                 push @skipped, $skedname  ;
                 push @skippedwhy, 3;
                 next SKEDNAME;
              }
           }
        } # if there are any equal entries in %bigset, and the previous
          # one isn't the same as this one without the equal, then skip it
          # (this will filter out all =3, =4s etc.)
        
        # OK, we know we can put these together now.

        foreach (keys %smallset) {
           next if /=/;
           if (exists $bigset{"$_=2"} and not exists $smallset{"$_=2"}) {
              $pages{$small}{TP}[$smallset{$_}] .= "=2";
           }
        }  # for each entry, if there's no =2 entry in the small set,
           # but there is in the big set, change this timepoint to be
           # the =2 entry instead. Aligns on departure, not arrival column

        # regenerate smallset to deal with changed entries
        $count = 0;
        %smallset = ();
        $smallset{$_} = $count++ foreach @{$pages{$small}{TP}}; 

        { #scoping
        # next: add extra tp columns to the shorter one
        my @blankcol = ("") x @{$pages{$small}{ROUTES}};
        my @newsmalltimes = ();
        for my $col (0 .. $#{$pages{$big}{TP}}) { 
           if (exists $smallset{$pages{$big}{TP}[$col]}) {
               my $smallcol = $smallset{$pages{$big}{TP}[$col]};
               push @newsmalltimes, $pages{$small}{TIMES}[$smallcol];
           } else {
               push @newsmalltimes, [@blankcol];
           }
        }
        $pages{$small}{TIMES} = \@newsmalltimes;
        }

        $pages{$small}{TP} = $pages{$big}{TP};
        # in case the small one is the first page, make sure it
        # has the whole set of timepoint abbreviations

        # so now the columns from first and second pages should be
        # identical.

      }


      for my $a ( qw(ROUTES SPECDAYS VT NOTES ) ) {
         push @{$pages{$skedname}{$a}} , @{$pages{$thispage}{$a}};
      }

      for my $col (0 .. $#{$pages{$thispage}{TP}}) { 
         for my $row (0 .. $#{$pages{$thispage}{ROUTES}}) {
            push @{$pages{$skedname}{TIMES}[$col]} ,
                 $pages{$thispage}{TIMES}[$col][$row] ;
         }
      }

      delete $pages{$thispage};

   }

   printf "%10s" , $skedname unless $options{quiet};
    
}

print "\n\nCan't combine multiple pages, skipping:\n"  unless $options{quiet};


for (0 .. $#skipped) {
   printf "%10s" ,  $skipped[$_] unless $options{quiet};
   #print $skipped[$_] , " " , $skippedwhy [$_] , "\n" ;
   #print $skipped[$_] , " " , $skippedwhy [$_] , "\n" ;
   $pages{$skipped[$_]}{SKEDNAME} = $skipped[$_] . "=1";
   $pages{$skipped[$_] . "=1"} = $pages{$skipped[$_]};
   delete $pages{$skipped[$_]};
}

print "\n";


######################################################################
# All schedules now joined, or skipped. 
######################################################################

foreach my $dataref (sort {$a->{SKEDNAME} cmp $b->{SKEDNAME}} values %pages) {
   trim_sked($dataref);
}

merge_days (\%pages, "WD" , "WE" , "DA");
# since Saturdays and Sundays are now always the same, this is the only possible
# merger. 

foreach my $dataref (sort {$a->{SKEDNAME} cmp $b->{SKEDNAME}} values %pages) {
   Skedwrite ($dataref, ".txt"); 
   $index{$dataref->{SKEDNAME}} = 
           skedidx_line ($dataref) unless $dataref->{SKEDNAME} =~ m/=/;
}

print "\n" unless $options{quiet};

### read exception skeds (these don't change from signup to signup
### unless this is done manually)

my @skeds = sort glob "../exceptions/*.txt";

print "\nAdding exceptional schedules (possibly overwriting previously processed ones).\n" unless $options{quiet};

my $displaycolumns = 0;

my $prevlinegroup = "";
foreach my $file (@skeds) {
   next if $file =~ m/=/; # skip file if it has a = in it

   unless ($options{quiet}) {
      my $linegroup = $file;
      $linegroup =~ s#^\.\./exceptions/##;
      $linegroup =~ s/_.*//;

      unless ($linegroup eq $prevlinegroup) {
         $displaycolumns += length($linegroup) + 1;
         if ($displaycolumns > 70) {
            $displaycolumns = 0;
            print "\n";
         }
         $prevlinegroup = $linegroup;
         print "$linegroup ";
      }
   
   }

   my $newfile = $file;
   $newfile =~ s#\.\./exceptions#skeds#; # result is "skeds/filename"
   copy ($file, $newfile) or die "Can't copy $file to $newfile"; 
   # call to File::Copy

   # print "\t[$file - $newfile]\n";

   my $dataref = Skedread($newfile);

   $index{$dataref->{SKEDNAME}} = skedidx_line ($dataref);

}

open IDX, ">Skedidx.txt" or die "Can't open $signup/skedidx.txt";
print IDX "SkedID\tTimetable\tLines\tDay\tDir\tTP9s\n";
print IDX join("\n" , sort {$a <=> $b || $a cmp $b} values %index) , "\n" ;
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


#sub remove_private_timepoints {

#   my $dataref = shift;

#   our (%privatetps);

#   my (%theseprivatetps);

#   $theseprivatetps{$_} = 1 foreach (@{$privatetps{$dataref->{LINEGROUP}}});

#   my $tp = 0;
#   while ( $tp < ( scalar @{$dataref->{"TP"}}) ) {
#      if ($theseprivatetps{$dataref->{"TP"}[$tp]}) {
#         splice (@{$dataref->{"TIMES"}}, $tp, 1);
#         splice (@{$dataref->{"TP"}}, $tp, 1);
#         splice (@{$dataref->{"TIMEPOINTS"}}, $tp, 1);
#         next;
#      }
#      $tp++;
#   }

#}

sub merge_days {

   my ($alldataref, $firstday, $secondday, $mergeday) = @_;
   # the last three are, for example, (SA, SU, WE) or (WD, WE, DA)
   # only WD, WE, and DA are expected now

   my (@firstscheds, @secondscheds);  
   
   foreach (sort grep (/$firstday/ , (keys %$alldataref) ) ) {
      (my $other = $_ ) =~ s/$firstday/$secondday/;
      next unless exists $alldataref->{$other};
      push @firstscheds, $_;
      push @secondscheds, $other;
      
   } 

   # so create lists in @firstscheds and @secondscheds of all the schedules
   # that have both $firstday and $secondday variants. Lists are skednames,
   # not references to the schedules themselves.

   # this will break if $firstday is found elsewhere in the skedname than
   # in the day position. If we ever have a linegroup called "WD" I'll have to
   # fix this
  
   return -1 unless scalar(@firstscheds);

   # If nothing to merge, return -1
   # I don't know that I'll actually use the return values.
   
   my $count = 0;

   SKED: foreach my $sked (0 .. $#firstscheds ) {
      my $tempskedref;
   
      if ($firstday eq "WD") {
         # if the first schedule is a weekday, 
         # create a version with "SD" lines removed. Use that 
         # for comparison.  This works because "School Days Only" 
         # can work just as well on a weekend as weekday schedule.

         # At this writing, at least 72 & 88 are like this.
 
         # Duplicate SD/SH rows already trimmed away by earlier invocation of
         # trim_sked

          $tempskedref = copy_sked($alldataref->{$firstscheds[$sked]});
          my $totalrows = scalar (@{$tempskedref->{ROUTES}});
        
          my $row = 1; # second row (first row is #0)
          while ($row++ < $totalrows) {
             next unless $tempskedref->{SPECDAYS}[$row] eq "SD";
             $totalrows--;
             foreach (qw(ROUTES NOTES VT SPECDAYS)) {
                splice ( @{$tempskedref->{$_}} , $row, 1);
             }
             foreach ( 0 .. ( (scalar @{$tempskedref->{TP}}) - 1) ) {
                  splice ( @{$tempskedref->{TIMES}[$_]} , $row, 1);
             }
             # eliminate this row
          }

          remove_blank_columns($tempskedref); # 

      } else { # should not happen unless Saturday and Sunday scheds diverge again
          $tempskedref = ($alldataref->{$firstscheds[$sked]});
      }

      foreach ( qw(TP ROUTES SPECDAYS TIMES VT NOTES NOTEDEFS) ) {
   
         next SKED if scalar @{$tempskedref->{$_}} 
                  != scalar @{$alldataref->{$secondscheds[$sked]}{$_}}  ;

      }
      # if the number of timepoints or rows, etc., are different, skip it
      
      foreach ( qw(TP ROUTES SPECDAYS VT NOTES NOTEDEFS )) {
      
         next SKED 
            if join ("" , @{$tempskedref->{$_}})      ne
               join ("" , @{$alldataref->{$secondscheds[$sked]}{$_}}) ;
      }
      # if the text of any of the data (other than TIMES) is different skip it

      for (my $column = 0; 
           $column < scalar @{$tempskedref->{"TIMES"}} ;  
           $column++) {
         next SKED
           if join ("" , @{$tempskedref->{TIMES}[$column]}) ne
              join ("" , @{$alldataref->{$secondscheds[$sked]}{TIMES}[$column]});
      }

      # if any of the times are different, skip it.

      # At this point, we know they're identical.
      # References make it pretty easy.
      
      my $newschedname = $firstscheds[$sked];
      $newschedname =~ s/$firstday/$mergeday/;
      
      $alldataref->{$newschedname} = $alldataref->{$firstscheds[$sked]};
      $alldataref->{$newschedname}{DAY} = $mergeday;
      $alldataref->{$newschedname}{SKEDNAME} = $newschedname;
      
      # remember, that's a reference. Same reference, same thing.
      
      delete $alldataref->{$firstscheds[$sked]};
      delete $alldataref->{$secondscheds[$sked]};
 
      # so now, the original two days are gone, 
      # but the first day is still stored in $alldataref->{$newschedname}  
      
      $count++;
   }
   
   return $count;
   
   # returns the number of merged schedules. 
   # I don't see that it actually matters.
   
}


sub skedidx_line {

   my $dataref = shift;

   my @indexline = ();
   my %seen = ();

   my @routes = sort byroutes grep {! $seen{$_}++}  @{$dataref->{ROUTES}};

   push @indexline, $dataref->{SKEDNAME};
   push @indexline, $dataref->{LINEGROUP};
   push @indexline, join("\035" , @routes);
   # \035 says "this is a repeating field" to FileMaker
   push @indexline, $dataref->{DAY};
   push @indexline, $dataref->{DIR};

   my @tps = ($dataref->{TP}[0]);
   for (1 .. scalar @{$dataref->{TP}}) {
      push @tps , $dataref->{TP}[$_] 
            if $dataref->{TP}[$_-1] ne $dataref->{TP}[$_];
   } # drop out duplicate arrival/departure timepoints (like merge_columns)

   push @indexline, join("\035" , @tps);

   return join("\t" , @indexline);

}

sub add_duplicate_tp_markers {

   my $dataref = shift;

   my %seen = ();
   foreach (@{$dataref->{"TP"}}) {
      $_ .= "=" . $seen{$_} if $seen{$_}++;
   }
      # If there's a duplicate timepoint, 
      # it now has a "=" and number (usually "2") appended to it

   return $dataref;

} 

##### added 11/03 ####

sub stripblanks {

   my @ary = @_;
   foreach (@ary) {
     s/^\s+//;
     s/\s+$//;
   }

   return wantarray ? @ary : $ary[0];

}


sub byskednamenum {

   (my $aa = $a) =~ s/.*=//;
   (my $bb = $b) =~ s/.*=//;
   return $aa <=> $bb;

}

