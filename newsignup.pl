#!/usr/bin/perl

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
use Skedfile qw(Skedread Skedwrite Skedwrite_anydir
                trim_sked copy_sked remove_blank_columns);
use Myopts;
use Skeddir;
use Storable;
use Algorithm::Diff;
use Actium::Sorting ('sortbyline');

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

our (%options);    # command line options
my  (%index);      # data for the index
my (%pages);       # pages

my %dirnames = ( NO => 'NB' , SO => 'SB' , EA => 'EB' , WE => 'WB' , 
                   CL => 'CW' , CO => 'CC' );
# translates new Hastus directions to old Transitinfo directions

my @privatetimepoints = ("OAKL AIRR" , );

my %specdayoverride = (
   305 => "TT" ,
   360 => "TT" ,
#   329 => "WF" ,
   356 => "TF" ,
   314 => "TF" ,
   391 => "TF" ,
) ; # Scheduling hasn't put those in Hastus
# 329 removed for Fall '06

my %no_split_linegroups;
$no_split_linegroups{$_} = 1 foreach qw(40 59 72 86 DB);

# Those are the lines that should be combined into a single schedule, for 
# purposes of point schedules.  Note 52 and 86 should not be combined
# for fulls.  
# S was removed 3/06.
# 52 removed 11/06
# 40, 52, 82 all irrelevant as of 11/06

# TODO - Ideally this would be in a database rather than being specified here, 
# but it isn't yet.
 
Myopts::options (\%options, Skeddir::options(), 'effectivedate:s' , 'quiet!');
# command line options in %options;

$| = 1; 
# don't buffer terminal output

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

   writeeffectivedate($effectivedate);

} else {

   if (-e 'effectivedate.txt') {
      open IN, 'effectivedate.txt';
      $effectivedate = <IN>;
      close IN;

   } else {

      print "Enter an effective date for this signup, please.\n";
   
      $effectivedate = <STDIN> ;
      until ($effectivedate) {
         print "No blank entries, please.\n";
         $effectivedate = <STDIN> ;
      }

      print "Thanks!\n\n";

      writeeffectivedate($effectivedate);

   }

   print "Using effective date $effectivedate\n\n" unless $options{quiet};

}

unless (-e 'timepointorder.txt') {
   die "Can't find timepointorder.txt.";
}



######################################################################
# import headway sheets as pages, and split them by routes
######################################################################

my %seenskedname;

{ # block for local scoping

local $/ = "\cL\cM";

foreach my $file (glob ("headways/*.{txt,prt}")) {
   open (my $fh , $file);

   print "\n$file" unless $options{quiet}; # debug

   my %seenprint = ();
   my $seenprintcount = 0;
   # keep track of which line groups have been seen, so we don't
   # print them more than once on to stdout

   while (<$fh>) {
      chomp;
      my @lines = split(/\r\n/);

      splice (@lines, 0, 3);
      splice (@lines, -5, 5);
      # delete header and footer

      # This next line dumps lines[2], which reads "SYSTEM WEEKDAY SCHEDULES SUMR06",
      # and returns the situation to where it was before
      splice (@lines, 2, 1) if $lines[2] !~ /__+/;

      { # another block for localization
      local $/ = "\r\n";
      chomp @lines;
      }
      last if $lines[3] eq "SUMMARY OF PROCESSED ROUTES:";  

      next if ((length($lines[6]) < 11) or substr($lines[6],5,3) ne "RTE");
      # TODO - THIS WILL THROW AWAY ALL PAGES CONSISTING ONLY OF
      # NOTES CONTINUED FROM THE PREVIOUS PAGE. WILL WANT TO HANDLE
      # THIS AT SOME POINT.

      my $linegroup = stripblanks(substr($lines[3],23,3));
      next if $linegroup eq "399"; # supervisor orders
      $linegroup = "51" if $linegroup eq "51S"; # stupid scheduling
      # $linegroup = "S" if $linegroup eq "131"; # S and SA decoupled 3/06
      $linegroup = "DB" if $linegroup eq "137"; 
      # Only need to override 1xx here where two routes are combined. Otherwise, will be overridden
      # later.

      unless ($options{quiet} or $seenprint{$linegroup}++) {
         print "\n" unless ($seenprintcount++ % 19 ) ;
         printf "%4s" , $linegroup;
      }

      # OK, we have the original line group. Now, read the times, lines, etc.

      my %thispage = (); # this has the times
      my %routes = (); # keep track of which routes we've seen

      my $timechars = index($lines[6], "DIV-IN") - 42;
      # DIV-IN is the column after the last timepoint column. The last character 
      # of the last column ends two characters before "DIV-IN". The notes in
      # the front comprise 42 characters. (used to be 63)

      my $template = "A4 A5 x11 A3 x12 A5 x2" . "A9" x ($timechars / 9); 
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
      
      # STUPID KLUDGE BECAUSE SCHEDULING HAS "HILL MALL" mean both Hilltop and Hillsdale malls
      if ($linegroup eq '135' or $linegroup eq '138') { # M, MA
         foreach (@tps) {
            $_ = 'HDAL MALL' if $_ eq 'HILL MALL';
         }
      }
      
      $thispage{TP} = \@tps;
      
      } # scoping

      $thispage{NOTEDEFS} = [];
      # initialize this to an empty array, since otherwise
      # things that expect it to be there break

      my %seenroutes = ();

      for (@lines[9..$#lines]) {

         next unless $_;
         next if /^\s+$/;
         next if /^_+$/;
         # skip lines that are blank, or only underlines

         last if /^Notes:/; # TODO - SKIP NOTE DEFINITIONS FOR NOW

         my ($specdays, $routes, $vt, $notes, @times) = 
              stripblanks (unpack $template, $_); 

         #print "[$specdays][$routes][$vt][$notes]";
         #print "[$_]" foreach  @times;
         #print "\n";
         # horrific debugging

         my $numtimes = 0;
         foreach (@times) {
            if (/^\.+$/ or /^\-+$/) {
               $_ = '' ; 
               next;
            }
            s/\(\s*//;
            s/\s*\)//;
            s/x/a/;
            s/b/p/;
            $numtimes++ if $_;
            
         }  # Hastus uses "a" for am, "p" for pm, and "x" for am the following
            # day (so 11:59p is followed by 12:00x). Also "b" for pm the previous
            # day.
            # TODO - move this so some programs can still retreive "b" and "x" if they
            # want it

         next if $numtimes < 2;
         # drop lines with only one time
         
         foreach (qw(RRFB RRF1 RRF OWL OL)) {
            $notes = '' if $notes eq $_;
         }
         # RRF RRFB, RRF1 are restroom facilities. OWL and OL
         # notes are just telling the operators stuff about owl
         # service. These prevent merging from taking place. Don't
         # want to tell the general public this anyway

         $routes = '51' if $routes eq '51S'; # stupid scheduling
         $routes = '1' if $routes eq '1Lx' or $routes eq '1L'; # *really* stupid scheduling

         foreach (keys %specdayoverride ) {
             if ($routes eq $_ and $specdays eq '') {
                $specdays = $specdayoverride{$_}
             }
         }
         # until scheduling puts the WF, etc. back in, then 
         # I have to override the shopper routes this way

         push @{$thispage{SPECDAYS}} , $specdays;
         push @{$thispage{ROUTES}} , $routes;
         $seenroutes{$routes} = 1;
         $vt = ''; $notes = ''; # blank out for comparison
         push @{$thispage{VT}} , $vt;
         push @{$thispage{NOTES}} , $notes;

         for (my $col = 0 ; $col < scalar (@times) ; $col++) {
            push @{$thispage{TIMES}[$col]} , $times[$col] ;
         }
 

      } # lines of the times


      if ($linegroup eq '805') {
         # Will be faster with restriction. Shouldn't make a difference at this point
         remove_private_timepoints (\%thispage , @privatetimepoints);
      }


# When Saturdays and Sundays were identical, this code assumed Saturday was weekend.

      if ($lines[1] =~ /Saturday/i) {
         $thispage{DAY} = "SA";
      } elsif ($lines[1] =~ /Sunday/i) { 
         $thispage{DAY} = "SU"; 
      } else {
         $thispage{DAY} = "WD";
      }#

      $thispage{LGNAME} = stripblanks(substr($lines[3],28));
      $thispage{DIR} = uc(stripblanks(substr($lines[4],14,2)));
      $thispage{DIR} = $dirnames{$thispage{DIR}} if $dirnames{$thispage{DIR}};
      $thispage{ORIGLINEGROUP} = $linegroup;

      # split pages so that it thinks there's a separate page for each route

      my %thesepages;

      if ($no_split_linegroups{$linegroup}) { 
        # routes should be combined:

         $linegroup = (sortbyline keys %seenroutes)[0] 
            unless $linegroup =~ /^\d\d$/;
         # use first route for linegroups, except for two-digit numbers

         $thesepages{$linegroup} = \%thispage;

      } elsif (scalar(keys (%seenroutes)) == 1) {
         # just one route

         $linegroup = (keys %seenroutes)[0];
         $thesepages{$linegroup} = \%thispage;

      } else { # multiple routes that should not be combined

         foreach my $thisroute (keys %seenroutes) {
            $thesepages{$thisroute} = Storable::dclone (\%thispage);
            for (my $line = $#{$thispage{ROUTES}}  ; $line >= 0 ; $line--) {
               next if $thispage{ROUTES}[$line] eq $thisroute;
               splice (@{$thesepages{$thisroute}{SPECDAYS}} , $line , 1);
               splice (@{$thesepages{$thisroute}{ROUTES}}   , $line , 1);
               splice (@{$thesepages{$thisroute}{VT}}       , $line , 1);
               splice (@{$thesepages{$thisroute}{NOTES}}    , $line , 1);
               for (my $col = $#{$thispage{TIMES}} ; $col >= 0 ; $col--) {
                  splice (@{$thesepages{$thisroute}{TIMES}[$col]} , $line , 1 );
               }
               # remove all the lines that are not relevant for this route.
               # yes I realize this is not particularly efficient.
            }
         }
      }
  
      foreach (keys %thesepages) {

         $thesepages{$_}{SKEDNAME} = join("_" , 
                $_,
                $thispage{DIR},
                $thispage{DAY},
                );

         $thesepages{$_}{LINEGROUP} = $_;

         if ( $seenskedname{$thesepages{$_}{SKEDNAME}}++ ) {
            $thesepages{$_}{SKEDNAME} .= "=" . $seenskedname{$thesepages{$_}{SKEDNAME}};
         }

         # change SKEDNAME to include a number

         $pages{$thesepages{$_}{SKEDNAME}} = $thesepages{$_};

      }

   } # pages 

} # files
} # local scoping of $/

######################################################################
# All pages are in %pages. Now to combine pages...
######################################################################

# process each page$pagetp

print "\n\nCombining pages.\n" unless $options{quiet};

foreach my $dataref (values %pages) {
   remove_blank_columns($dataref);
   # from Skedfile.pm
   add_duplicate_tp_markers ($dataref);
}

#{
#open (my $fh , ">pages.txt");
#print $fh join("\n" , keys %pages ) , "\n";
#close $fh;
#}

#my @skipped;
#my @skippedwhy;

SKEDNAME: 
for my $skedname (sort keys %seenskedname) {

   my @morepages = sort byskednamenum grep /^$skedname=/ , keys %pages ; 
   next SKEDNAME unless scalar(@morepages); # only one page? don't combine 
   
   for my $thispage (@morepages) {

#		if ($thispage eq "51_NB_WD=2") {
#		   print "We're at the 51\n";	
#		}

      if (join ("" , @{$pages{$skedname}{TP}}) eq
          join ("" , @{$pages{$thispage}{TP}}) ) {
      # if timepoints are identical, just add the times.
       
	      for my $col (0 .. $#{$pages{$thispage}{TP}}) { 
   	      for my $row (0 .. $#{$pages{$thispage}{ROUTES}}) {
      	      push @{$pages{$skedname}{TIMES}[$col]} ,
         	        $pages{$thispage}{TIMES}[$col][$row] ;
        	 	}
      	}

      # ADD TIMES
        
      } else { # if timepoints aren't identical, do this bit that 
        # splices unlike timepoints together.

#### INSERT SPLICING ROUTINE HERE ####

		my @components = Algorithm::Diff::sdiff($pages{$skedname}{TP},$pages{$thispage}{TP});
		# That gives me a series of differences.
		
		my ($count, %pagetpnum);
		$pagetpnum{$_} = $count++ for @{$pages{$thispage}{TP}};
		
		my $skedtpcounter = 0;
		foreach my $componentnum (0 .. $#components) {
	
		   my ($action, $skedtp, $pagetp) = @{$components[$componentnum]};
		
		   if ($action eq "c") {
		      my $skedtpfirst = 1; #default is to splice thistp first. An arbitrary choice.
		      # the zero / one thing is meaningful.
		      
		      SKEDTPFIRST: {
			      if ($skedtp =~ /$pages{$skedname}{TP}[$skedtpcounter-1]=/) {
			         # if this skedtp is the same as the previous, with an equals,
			      	$skedtpfirst = 1; # do the skedtp first
			      	last;
			      }
			      if ($pagetp =~ /$pages{$skedname}{TP}[$skedtpcounter-1]=/) {
	               $skedtpfirst = 0; # do thistp first
	               last;
	            }
	            
		         my ($prevcomp) = "";
	            my $compcount = $componentnum - 1;
	            PREVLOOP: while ($compcount >= 0) {
	                $prevcomp = $components[$compcount][0];
	                last PREVLOOP if $prevcomp ne "c";
	                $compcount--;
	            } # so $prevcomp is the previous component that isn't "c"

	            my ($nextcomp) = "";
	            $compcount = $componentnum + 1;
	 				NEXTLOOP: while ($compcount >= scalar(@components)) {
	                $nextcomp = $components[$compcount][0];
	                last NEXTLOOP if $nextcomp ne "c";
	            } # so $nextcomp is the next component that isn't "c"

					if ($prevcomp eq "+" or ($nextcomp) eq "-") {
					   # previous was thistp or next is skedtp,
					   $skedtpfirst = 1; # do thistp first
					   last;
					} elsif ($prevcomp eq "-" or ($nextcomp) eq "+") {
					   # previous was skedtp or next is thistp,
					   $skedtpfirst = 0; # do skedtp first
					   last;
					}

            } # skedtpfirst 'loop'
            
            # So now we know whether we have to put thistp first, or skedtp first.
            
            
            my ($skedtpcol, $pagetpcol);
             
            if ($skedtpfirst) {
                $skedtpcol = $skedtpcounter;
                $pagetpcol = $skedtpcounter + 1;
            } else {
                $skedtpcol = $skedtpcounter + 1;
                $pagetpcol = $skedtpcounter;
            }
              
            # First, splice the one in from thispage
				splice(@{$pages{$skedname}{TP}},$pagetpcol,0,$pagetp);
				# add $pagetp to skedpage
				
				my @newcol =  ("") x @{$pages{$skedname}{ROUTES}};
				push @newcol, @{$pages{$thispage}{TIMES}[$pagetpnum{$pagetp}]};
				splice (@{$pages{$skedname}{TIMES}}, $pagetpcol, 0, \@newcol);
				# add empty entries to fill out skedpage rows, 
				# and then add times from thispage, to skedpage

				# Then, add enough blanks to fill out the other column
            push @{$pages{$skedname}{TIMES}[$skedtpcol]}, (("") x @{$pages{$thispage}{ROUTES}});

            $skedtpcounter++; # extra one, since two columns were added for this component

			} elsif ($action eq "-") {
				# item is in the skedname page but not this page.
            push @{$pages{$skedname}{TIMES}[$skedtpcounter]}, (("") x @{$pages{$thispage}{ROUTES}});
            # Add enough blanks to fill out the column.

         } elsif ($action eq "+") {
            # item is in this page but not the skednum page
				splice(@{$pages{$skedname}{TP}},$skedtpcounter,0,$pagetp);
				# add $pagetp to skedpage
				
				my @newcol =  ("") x @{$pages{$skedname}{ROUTES}};
				push @newcol, @{$pages{$thispage}{TIMES}[$pagetpnum{$pagetp}]};
				splice (@{$pages{$skedname}{TIMES}}, $skedtpcounter, 0, \@newcol);
				# add empty entries to fill out skedpage rows, 
				# and then add times from thispage, to skedpage
      
         } else { # action eq "u"
            push @{$pages{$skedname}{TIMES}[$skedtpcounter]}, @{$pages{$thispage}{TIMES}[$pagetpnum{$pagetp}]};
            # add times from thispage to skedpage
         }
		
         $skedtpcounter++;
		
		}

      # so now the columns and times from first and second pages should be
      # identical.

      }

      for my $a ( qw(ROUTES SPECDAYS VT NOTES ) ) {
         push @{$pages{$skedname}{$a}} , @{$pages{$thispage}{$a}};
      } # add other entries
      
      delete $pages{$thispage};

   }

   # Where we have timepoints FRED and FRED=2 adjacent to each other,
   # put all times in proper columns.
   for my $tpnum (1 .. $#{$pages{$skedname}{TP}} - 1) { # second to penultimate
      next if (($pages{$skedname}{TP}[$tpnum-1] . "=2") ne $pages{$skedname}{TP}[$tpnum]);
      # Is the last one plus "=2" the same as this one?
      # Will not combine =2 and =3 , etc., if they are adjacent. This is unlikely.
      for my $row (0 .. $#{$pages{$skedname}{ROUTES}}) { # go through each row
			next if $pages{$skedname}{TIMES}[$tpnum-1][$row] and $pages{$skedname}{TIMES}[$tpnum][$row];
			# If both entries are times, and not the empty string, go to the next row. 
			my $allsubsquenttimes = "";
			$allsubsquenttimes .= $pages{$skedname}{TIMES}[$_][$row] foreach ($tpnum+1 .. $#{$pages{$skedname}{TP}});
			# concatenates all the subsequent times on this row in $allsubsequent times
			if ($allsubsquenttimes) { 
			   # If there are any subsequent times, put the time on the right (departure)
				next if $pages{$skedname}{TIMES}[$tpnum][$row]; # skip it if it's already there
				$pages{$skedname}{TIMES}[$tpnum][$row] = $pages{$skedname}{TIMES}[$tpnum-1][$row];
				$pages{$skedname}{TIMES}[$tpnum-1][$row] = "";
			} else {
			   # If there aren't any subsquent times, put the time on the left (arrival)
			   next if $pages{$skedname}{TIMES}[$tpnum-1][$row]; # skip it if it's already there
			   $pages{$skedname}{TIMES}[$tpnum-1][$row] = $pages{$skedname}{TIMES}[$tpnum][$row];
			   $pages{$skedname}{TIMES}[$tpnum][$row] = "";
			}
	   } # end row
   } # end tpnum


   printf "%10s" , $skedname unless $options{quiet};
    
}

print "\n";


######################################################################
# All schedules now joined, or skipped. 
######################################################################

foreach my $dataref (sort {$a->{SKEDNAME} cmp $b->{SKEDNAME}} values %pages) {
   trim_sked($dataref);
}

merge_days (\%pages, "SA" , "SU" , "WE");
merge_days (\%pages, "WD" , "WE" , "DA");
# Should we ever have a schedule that is Weekdays-and-Saturdays but Sundays are different, I'll have to add
# more merge_days-es.

######################################################################
# Reorder columns where necessary.
######################################################################

# read timepointorder from file

my %newtps_of;

open IN, 'timepointorder.txt' or die "Can't open timepointorder.txt";

while (<IN>) {
   s/\s+\z//s; # strip final white space
   my ($skedid, @tps) = split(/\t/);
   $newtps_of{$skedid} = \@tps;
}

close IN;

print "\n\nReordering timepoint columns.\n" unless $options{quiet};

foreach my $skedname (keys %newtps_of) {

   unless ($options{quiet}) {
      printf "%10s" , $skedname;
      print "(not found) " unless $pages{$skedname};
   }

   next unless $pages{$skedname};
   # skip not-found schedules

   my @oldtps = @{$pages{$skedname}{TP}};
   my @newtps = @{$newtps_of{$skedname}};

   if (scalar(@oldtps) != scalar(@newtps)
       or join("",sort @oldtps) ne join("", sort @newtps)) {
      warn "\nTimepoints in $skedname in timepointorder.txt don't match timepoints\n"
           . "from scheduling. Can't reorder.\n";
      next;
   } # if the timepoints aren't exactly equal, skip and emit a warning.

  
   # Build mapping from old column list to new one.
   
   # create tporder hashes
   my (%newcol_of);
   for my $col (0 .. $#newtps) {
      $newcol_of{$newtps[$col]} = $col;
   }
   # so $newcol_of{'BLAH BLAH'} is the new column that times associated with 'BLAH BLAH' should go in
  
   my @savedtimes = @{$pages{$skedname}{TIMES}}; # array full of references to various columns
   
   my @tpmap = ();
   for my $col (0 .. $#oldtps) {
      my $newcol = $newcol_of{$oldtps[$col]};
      $pages{$skedname}{TIMES}[$newcol] = $savedtimes[$col];
   }

   $pages{$skedname}{TP}=\@newtps;
   # set the timepoint abbreviations to be the new ones
   
}

######################################################################
# Write schedules to disk
######################################################################


foreach my $dataref (sort {$a->{SKEDNAME} cmp $b->{SKEDNAME}} values %pages) {
   Skedwrite ($dataref, ".txt"); 
   Skedwrite_anydir ('rawskeds' , $dataref, '.txt');
   $index{$dataref->{SKEDNAME}} = 
           skedidx_line ($dataref) unless $dataref->{SKEDNAME} =~ m/=/;
}

print "\n" unless $options{quiet};

### read exception skeds 
# I've changed this so that now exceptions have to go in the signup directory. 
# It turns out that each signup will have to have its own exceptions, although sometimes
# these can be copied from the old ones...

my @skeds = sort glob "exceptions/*.txt";

print "\nAdding exceptional schedules (possibly overwriting previously processed ones).\n" unless $options{quiet};

my $displaycolumns = 0;

my $prevlinegroup = "";
foreach my $file (@skeds) {
   next if $file =~ m/=/; # skip file if it has a = in it

   unless ($options{quiet}) {
      my $linegroup = $file;
      $linegroup =~ s#^exceptions/##;
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
   $newfile =~ s#exceptions#skeds#; # result is "skeds/filename"
   copy ($file, $newfile) or die "Can't copy $file to $newfile: $!"; 
   # call to File::Copy

   # print "\t[$file - $newfile]\n";

   my $dataref = Skedread($newfile);

   $index{$dataref->{SKEDNAME}} = skedidx_line ($dataref);

}

open IDX, ">Skedidx.txt" or die "Can't open $signup/skedidx.txt";
print IDX "SkedID\tTimetable\tLines\tDay\tDir\tTP9s\tNoteLetters\n";
print IDX join("\n" , sort {$a <=> $b || $a cmp $b} values %index) , "\n" ;
close IDX;

open TPS, ">Skedtps.txt" or die "Can't open $signup/skedtps.txt";
foreach ( sort {$a <=> $b || $a cmp $b} values %index) {
   my @values = split (/\t/, $_) ;
   my $skedid = $values[0];
   my @tps = split (/\035/, $values[5]);
   for (my $i = 0; $i < scalar(@tps); $i++) {
      print TPS join ("\t" , $skedid , $i , $tps[$i]) , "\n";
   }
}
close TPS;

print <<"EOF" unless $options{quiet};


Indexes $signup/Skedidx.txt and $signup/Skedtps.txt written.
Remember to import it into FileMaker or the databases won't work properly.
EOF

######################################################################
#### end of main, and
#### start of subroutines internal to newsignup
######################################################################


sub remove_private_timepoints {

   my $thispage = shift;

   my (%privatetimepoints);

   $privatetimepoints{$_} = 1 foreach (@_);

   my $tp = 0;
   while ( $tp < ( scalar @{$thispage->{"TP"}}) ) {
      if ($privatetimepoints{$thispage->{"TP"}[$tp]}) {
         splice (@{$thispage->{"TIMES"}}, $tp, 1);
         splice (@{$thispage->{"TP"}}, $tp, 1);
         next;
      }
      $tp++;
   }

}

sub merge_days {

   my ($alldataref, $firstday, $secondday, $mergeday) = @_;
   # the last three are, for example, (SA, SU, WE) or (WD, WE, DA)

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
   # in the day position. If we ever have a linegroup called "WD" or "SA"
   # I'll have to fix this
  
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

      # I removed NOTES from all the following comparisons because
      # they weren't being used and they were different across 
      # weekends/weekdays

      foreach ( qw(TP ROUTES SPECDAYS TIMES VT NOTEDEFS) ) {
   
         next SKED if scalar @{$tempskedref->{$_}} 
                  != scalar @{$alldataref->{$secondscheds[$sked]}{$_}}  ;

      }
      # if the number of timepoints or rows, etc., are different, skip it
      
      foreach ( qw(TP ROUTES SPECDAYS NOTEDEFS )) {
      
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
   my @routes = sortbyline grep {! $seen{$_}++}  @{$dataref->{ROUTES}};
   %seen = ();
   my @notes = sort grep {$_ and ! $seen{$_}++}  @{$dataref->{NOTES}};

   push @indexline, $dataref->{SKEDNAME};
   push @indexline, $dataref->{LINEGROUP};
   push @indexline, join("\035" , @routes);
   # \035 says "this is a repeating field" to FileMaker
   push @indexline, $dataref->{DAY};
   push @indexline, $dataref->{DIR};

   my @tps = ($dataref->{TP}[0]);
   for (1 .. $#{$dataref->{TP}}) {
      my @thesetps;
      for (@thesetps = @{$dataref->{TP}}[$_-1,$_] ) {s/=\d+$//};
      push @tps , $dataref->{TP}[$_] 
            if $thesetps[0] ne $thesetps[1];
   } # drop out duplicate arrival/departure timepoints (like merge_columns)

   push @indexline, join("\035" , @tps);

   push @indexline, join ("\035" , @notes);

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

sub writeeffectivedate {

my $effectivedate = $_[0];

open OUT , ">effectivedate.txt" 
    or die "Can't open effectivedate.txt for output";
print OUT $effectivedate ;
close OUT;

}

