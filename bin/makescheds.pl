#!/usr/bin/perl5


%namesubs = 

   qw( eastbound E
       westbound W
       northbound N
       southbound S
       counterclockwise CCw
       clockwise Cw
       saturday Sa
       sunday Su
       weekday Wkd
       weekend Wke
       );
       
@splatchars = split (//, ' *+=#%$-@&?!^bcdefghijklmnoqrstuvwxyzBCDEFGHIJKLMNOQRSTUVWXYZ');

# ASCII only. If this were platform-specific, we'd use specific characters from
# the character set: dagger, paragraph, section, etc.

# first one is space, 'cause we don't want the most common line combo to have a splat

%notesubs = 
   (  SD => "School Days Only" ,
      SH => "School Holidays Only" ,
      TF => "Tuesdays and Fridays Only" ,
      TT => "Tuesdays and Thursdays Only" ,
      WF => "Wednesdays and Fridays Only" ,
   );

#### DEBUGGING

# @ARGV = ("Ripley HD:Aaron's �:vigsched:files:12.txt");

foreach $filename (@ARGV) {

   undef %fullsched;
   undef %outsched;
   undef %all_lines;

   $basefile = substr ($filename , 0, rindex ($filename, "."));
   # basefile is the filename without the extension 

   $linenum = $basefile;
   $linenum =~ s@.*:@@;
   $linenum =~ s@.*/@@;
   $linenum =~ s@.*\\@@;

   # $linenum should be basefile without leading directory component. 

   ### read data from file

   open IN, $filename;
   
   read IN, $_, 200;
   
   foreach $pat ("\015\012", "\012", "\015")  {
   
       if (/$pat/) {
          $lineend = $pat;
          last;
       }
    }

   die "Cannot discover an end of line character in $filename. How odd.\n" unless $lineend;
   
   $/ = "---$lineend";
   
   seek IN, 0, 0;
   
   while (defined($wholesched = <IN>)) {
      
      chomp($wholesched);
         
      @wholesched = (split ($lineend, $wholesched));
            
      $schedname = shift (@wholesched);

      @{$fullsched{$schedname}{"TIMEPOINTS"}} = split (/\t/, shift @wholesched);
      @{$fullsched{$schedname}{"TP"}} =  split (/\t/, shift @wholesched);

      splice ( @{$fullsched{$schedname}{"TP"}} , 0, 2);
      splice ( @{$fullsched{$schedname}{"TIMEPOINTS"}} , 0, 2);

      # that gets rid of the "RTE NUM" and "NOTE" entries, and their equivalents in TIMEPOINTS

      $row = 0;
      foreach (@wholesched) {
         
         ($note, $line, @thesetimes ) = split (/\t/);
                           
         $tp = 0;
         foreach $thistime (@thesetimes) {
             $fullsched{$schedname}{"TIMES"}[$tp][$row] = $thistime ;
             $tp++;
         }

         $fullsched{$schedname}{"NOTES"}[$row] = $note if $note;
         
         if ($line) {
            $fullsched{$schedname}{"LINES"}[$row] = $line;
            $all_lines{"$line"}++;
         }
         
         $row++;
         
      }


   }

   close IN;

   ### now all data is in %fullsched
   ###     and every line is listed in %all_lines
   
   undef %shortschednames;
   
   foreach (keys %fullsched) {
   
       ($direction, $day) = split;
       $shortschednames{$_} = $namesubs{lc $direction} . $namesubs {lc $day} ;
   }
      
   
   ### Delete blank columns, and merge columns with the same timepoint (i.e., 
   ### where a point says "arrives 10:30, leaves 10:35" just use the latter)
   
   foreach $schedname (keys %fullsched) {
   
      
      undef $prevtp;
      $tp = 0;
      
      TIMEPOINT: while  ( $tp < ( scalar @{$fullsched{$schedname}{"TP"}}) ) {
      
         unless (join ("", scalar @{$fullsched{$schedname}{"TIMES"}[$tp]})) {
            
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
   
   output_schedule(">$basefile-slim.txt");
   
   ### Ask the user which lines to use
   
   $all_linesflag = 1;
   
   
   if (scalar (keys %all_lines) > 1) {

      while (1) {   

         undef %usinglines;

         print "The following lines are in this schedule:\n   ";
         print join ("," , keys %all_lines) , "\n";
      
         foreach (keys %all_lines) {
            getyorn ("Do you want to use line $_ ?") and $usinglines{$_}=1;
         }
      
      last if (scalar(keys %usinglines)) ;
      
      print "You have to pick at least one line!\n\n";
      
      }

   
   $all_linesflag = 0 unless ( scalar(keys %usinglines) == scalar (keys %all_lines) );
   
   } else {
   
      %usinglines = ( $linenum , 1)
        
   }
   
   
   ### Generate %outsched
   
   #  the idea here is to reorganize the data by columns. Each column (timepoint) in %outsched stands alone,
   #  so one can generate the final printed output.  Each column will end up being a final printed output
   #  of a VBS

   foreach $schedname (keys %fullsched) {
   
	   # get the maximum number of rows
	   
	   $maxrows = 0;
	   foreach (@{$fullsched{$schedname}{"TIMES"}}) {
	   
	       # so $_ will be the reference to the first list of times, then the ref to second list of times...
	   
	       $rowsforthispoint = scalar (@$_);
	       
	       # $_ is the reference to the list of times. @$_ is the list of times itself. scalar (@$_) is the
	       #     number of elements in the list of times. Whew!
	       
	       $maxrows = $rowsforthispoint if $rowsforthispoint > $maxrows;
	       
	   }

       undef @lasttp;

       for ($row=0; $row < $maxrows ;  $row++) {

          for ( $tp = scalar @{$fullsched{$schedname}{"TP"}} ; $tp >= 0;  $tp-- ) {
		   	   $lasttp[$row] = $tp;
		   	   last if $fullsched{$schedname}{"TIMES"}[$tp][$row];
	      }
       
       }
        
       # once that's done, $lasttp[$row] contains the last timepoint for each row



       for ($tp=0; $tp < ( scalar @{$fullsched{$schedname}{"TP"}} - 1) ;  $tp++) {
		   
           # do every timepoint except the last one
           
           $nrow = 0;
           for ($row=0; $row < $maxrows ;  $row++) {
              
              next unless $all_linesflag 
                  or ($fullsched{$schedname}{LINES}[$row] and
                  $usinglines{ $fullsched{$schedname}{LINES}[$row]} )  ;

              # unless we're using all lines, or this row has a line and it's on the list, skip the row
                  
              $_ = $fullsched{$schedname}{"TIMES"}[$tp][$row];
              # that saves us some typing.
              
              next unless $_;
              # if this time is blank, skip it

              next if $lasttp[$row] <= $tp;
              # skip this row if the last timepoint on the row is this one or prior to now
              #  (of course, the last test should have caught any "prior to now" ones)

              $outsched{$schedname}{"TIMES"}[$tp][$nrow] = $_;

              $outsched{$schedname}{"NOTES"}[$tp][$nrow] =  
                   $fullsched{$schedname}{"NOTES"}[$row] if $fullsched{$schedname}{"NOTES"}[$row];

              $outsched{$schedname}{"LINES"}[$tp][$nrow] = 
                   $fullsched{$schedname}{"LINES"}[$row] if $fullsched{$schedname}{"LINES"}[$row];

              $outsched{$schedname}{"LASTTP"}[$tp][$nrow] = $lasttp[$row];

              $nrow++;   
           }
           
       
       }


   
   }

   # now, go through it by columns and generate the end values
   
   foreach $schedname (keys %fullsched) {

      for ($tp=0; $tp < ( scalar @{$fullsched{$schedname}{"TP"}} - 1) ;  $tp++) {
      
      
         ### before we do any of this, if there is nothing to the right of any of the entries in
         ### this column, we should skip it.
         
         $skipflag = 0;
         
         for ($nrow=0; $nrow < ( scalar @{$outsched{$schedname}{"TIMES"}[$tp]}) ;  $nrow++) {
         
            next unless $outsched{$schedname}{"TIMES"}[$tp][$nrow];
            # if it's blank, skip it -- we're only concerned with valid entries.
            # (if they're all blank, that would have been caught previously.)
            # for example, line 12 has blanks at Lake Merritt for most, but for any
            # ending at Lake Merritt, these are the last ones.
            
            if ($outsched{$schedname}{"LASTTP"}[$tp][$nrow] > $tp) {
               $skipflag = 1;
               last;
            }
                        
         }
         
         next unless $skipflag;
            
         undef %thesenotes;
         undef %thesecombos;
         undef @thesenotes;
         undef @thesecombos;
         
         foreach ( @{$outsched{$schedname}{"NOTES"}[$tp]} ) {
             $thesenotes{$_}++ if $_;
         }
         
         # so keys %thesenotes consists of each note found, with the number found in the values

         # now generate the line / endpoint combinations

         for ($nrow=0; $nrow < ( scalar @{$outsched{$schedname}{"TIMES"}[$tp]}) ;  $nrow++) {

             $_ = $outsched{$schedname}{"LINES"}[$tp][$nrow] . ":" 
                  . $outsched{$schedname}{"LASTTP"}[$tp][$nrow];
             
             $thesecombos{$_}++;
             $outsched{$schedname}{"COMBO"}[$tp][$nrow] = $_;

         }

         # OK, now the combinations are in %thesecombos, same way as %thesenotes. 
         
         @thesecombos = sort { $thesecombos{$b} <=> $thesecombos{$a}  } 
                           keys (%thesecombos);
                           
         # now we have the order. It's reversed because we want the highest number of 
         #  hits for that line to have the lowest order
         
         for ($_ = 0; $_ < scalar (@thesecombos) ; $_++) {
         
            $thesecombos{$thesecombos[$_]} = $_
         
         }

         # that puts the *order*, rather than the *number* of instances, in %thesecombos
         # basically %thesecombos is the inversion of @thesecombos -- instead of saying $thesecombos[0]
         # and getting "FS:8" (meaning that it's line FS going to timepoint 8), we can do $thesecombos{"FS:8"}
         # and get 0

         @thesenotes = sort { $thesenotes{$b} <=> $thesenotes{$a}  } 
                           keys (%thesenotes);

         # ok, now @thesenotes are the notes, in order of common usage
         
         $count = scalar (@thesecombos);
                  
         foreach (@thesenotes) {
            $thesenotes{$_} = $count;
            $count++;
            
         }


         # that does the same thing for %thesenotes as the previous thing did for %thesecombos, except that while
         # the order in %thesecombos starts at 0, the order in %thesenotes starts with the next number after
         # $thesecombos. Thus, $splatchars[$thesenotes] is correct, as is $splatchars[$thesecombos]
         
            
         # So now we have all the information we need to print the damn thing out!
         
         @alphalines = sort keys %usinglines;
         
       	 # that puts the lines in alphabetical order

         if ($#alphalines > 1 ) {
			    
              $linesstring = "Lines ";
			        
			  foreach (0 .. $#alphalines - 1) {
			       $linesstring .= "$alphalines[$_], ";
			  }
			  $linesstring .= "and $alphalines[$#alphalines]";
			    
		 } elsif ($#alphalines == 1) {

			  $linesstring = "Lines $alphalines[0] and $alphalines[1]";

	     } else {
		      $linesstring = "Line $alphalines[0]";
		 }

         
         $outfile = $fullsched{$schedname}{TP}[$tp];
         $outfile =~ s/\W/_/g;
         $outfile = $outfile . "-" . join ("" , @all_lines) unless $all_linesflag;
         $outfile = ">$basefile-" . $shortschednames {$schedname} . "-$outfile.txt";
         open OUT , $outfile;

         $oldfh = select OUT;

         print $linesstring , "\n";         
         print $schedname , "\n";
         print "Times for $fullsched{$schedname}{TIMEPOINTS}[$tp] \n";
         print "  (Times may be somewhat later at this location)\n";

         $prevhour = "A";
         
         for ($nrow=0; $nrow < ( scalar @{$outsched{$schedname}{"TIMES"}[$tp]}) ;  $nrow++) {
         
            $thistime = $outsched{$schedname}{TIMES}[$tp][$nrow];
            $thiscombo = $outsched{$schedname}{COMBO}[$tp][$nrow];
            $thisnote = $outsched{$schedname}{NOTES}[$tp][$nrow];
         
            $thishour = substr ($thistime, 0, -3);
            
            # pick the hour off the end
            
            print "\n" if $thishour ne $prevhour;
            $prevhour = $thishour;
            
            print $thistime;
            
            if ( $thesecombos{$thiscombo} ) {
               # if this combo isn't the most common one,
               print " " if $splatchars[$thesecombos{$thiscombo}] =~ m/[A-Za-z0-9]/; 
               print $splatchars[$thesecombos{$thiscombo}];
            
            }
            
            if ($thisnote) {
               print " " if $splatchars[$thesenotes{$thisnote}] =~ m/[A-Za-z0-9]/; 
               print $splatchars[$thesenotes{$thisnote}];
            
            }             
            
            print " ";
            
         }
         
         ($thisline, $thistp) = split ( /:/ , $thesecombos[0] );
         
         
         $defaultline =  "\n\nAll times are for buses ";
         $defaultline .= "on line $thisline " if $thisline;
         $defaultline .= "ending at " . $fullsched{$schedname}{"TIMEPOINTS"}[$thistp];
         $defaultline .= " unless marked otherwise" if $#thesecombos;
         $defaultline .= ".\n\n";
         $defaultline =~ s/\.+/\./g;
         
         
         print $defaultline;

          
         for (1 .. $#thesecombos) {
            ($thisline, $thistp) = split ( /:/ , $thesecombos[$_] );
            print $splatchars[$_] , "  ";
            print "Line $thisline " if $thisline;
            print "to " , $fullsched{$schedname}{TIMEPOINTS}[$thistp] , "\n";
 
         }
         
         
         for (0 .. $#thesenotes) {
            print $splatchars[$_ + scalar (@thesecombos)] , "  ";
            print ( ( $notesubs{$thesenotes[$_]} or $thesenotes[$_] ) , "\n" );
            # prints the substitute note text, or if not there, the plain
            # text (so that "SH" shows up as "School Holidays Only, but "QZ" shows
            # up as "QZ")
         }
         
         close OUT;
         select $oldfh;
            
      }

   
   }

   print "Ending $filename.\n\n";
   
}


sub getyorn {

   my $input = "";
   
   print "$_[0] (enter Y or N)\n";

   local $/ = "\n";
   
   $input = uc(substr (<STDIN>, 0, 1)) until ($input eq "Y" or $input eq "N");

   return 1 if $input eq "Y";
   
   return 0;

}




#sub debug_pjc {

#   print (join "," , @_);
#   print "\n";

#}

sub output_schedule {

open OUT , $_[0];
   
foreach $schedname (keys %fullsched) {

   print OUT $schedname , "\n";
   print OUT "Notes\tLine number\t" , join ("\t"  , @{$fullsched{$schedname}{"TIMEPOINTS"}} ) , "\n"; 
   print OUT "NOTE\tRTE NUM\t" , join ("\t"  , @{$fullsched{$schedname}{"TP"}} ) , "\n"; 

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

      print OUT $fullsched{$schedname}{"NOTES"}[$i] , "\t" ;
      print OUT $fullsched{$schedname}{"LINES"}[$i] , "\t" ;

      foreach (@{$fullsched{$schedname}{TIMES}}) {
          print OUT $_ -> [$i] , "\t";

      }

     # ok. $_ becomes the *reference* to the first, second, etc. list of times.  

      print OUT "\n";

   }

   print OUT "---\n";

}

close OUT;

}

