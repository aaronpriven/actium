#!perl

# tdpbook.pl

use strict;
no strict 'subs';


no strict 'subs';
sub print_right_head () ;
sub print_right_tail ($);
sub print_rows ($$$$$$$$);
sub build_linenamehash () ;
sub print_left_tail ($$$) ;
sub print_tail ($$) ;
sub build_batchlists ($) ;
sub print_head ($$$$$) ;


use constant ROWSPERPAGE => 36;
use constant DROPCAPLINES => 3;
use constant BOXESINTEMPLATE => 23;
use constant BIGSPACE => '<\q>' x 2;
# will need to be 13 soon

require 'pubinflib.pl';

init_vars();

our %icons = 
    (
      ST => '<f"Zapf Dingbats">H<f$>',
      SD => '<f"Carta">V<f$>',
      SH => '<f"Festive"><\#105><f$>',
      '*' => '<f"Transportation"><\#121><f$>',
    );


our (%daydirhash, %longerdaynames);

chdir get_directory() or die "Can't change to specified directory.\n";

our %tphash;

build_tphash();

my %linename = build_linenamehash();

my $batchfile = $ARGV[1];

my $outfile = $ARGV[2];

my @batchlist = build_batchlists($batchfile);

open OUT, (">" . ($outfile or "booklet.txt")) or die "Cannot open out";
select OUT;

open REPORT , ">batchreport.txt";

our %fullsched;

my (@batchnotes, %batchroutes, %batchdays, %routes);
# %batchroutes are those routes given in the batch file.
# %routes are those in the actual file.

my (@tables);

# first we create the list of tables.

print REPORT "Processing schedules: \n";

foreach my $thisbatch (@batchlist) {

   my $line = $thisbatch->{LINE};

   read_fullsched($line, ".acs");

   %batchroutes = ();
   %batchdays = ();

   $batchroutes{$_} = 1 foreach (@{$thisbatch->{ROUTES}});

   $batchdays{$_} = 1 foreach (@{$thisbatch->{DAYS}});

   @batchnotes = @{$thisbatch->{NOTES}};

   DAYDIR:
   foreach my $day_dir (keys %fullsched) {

      my ($dir, $day) = split (/_/ , $day_dir);

      next DAYDIR unless ((not scalar %batchdays) or $batchdays{$day});

      # OK, so now we know that this daydir is indeed used

      my $thistable = {};

      print REPORT "$line\t$day_dir\n";

      $thistable->{DAY_DIR} = $day_dir;
      $thistable->{LINE} = $line;
      $thistable->{BATCHNOTES} = [@batchnotes];

      my $numroutes = scalar keys %batchroutes;

      # $numroutes is the number of routes *given*. Will often be "0"

      my %routes;

      if ($numroutes) { # if any routes are given
         %routes = %batchroutes;
         $thistable->{ROUTESGIVEN} = 1;
      } else {
         $routes{$_} = 1 foreach @{$fullsched{$day_dir}{ROUTES}};
         $thistable->{ROUTESGIVEN} = 0;
      }
      # if any are given, use the given ones. If not, use all that are present

      $thistable->{ROUTES} = [sort byroutes keys %routes];

#      print REPORT "{" , @{$thistable->{ROUTES}} , "} ";

      push @tables, $thistable;

   } # daydir

} #line

@tables = sort 
    {
     byroutes ($a->{"ROUTES"}[0], $b->{"ROUTES"}[0]) or 
     $daydirhash{$a->{"DAY_DIR"}} <=> $daydirhash{$b->{"DAY_DIR"}}
    } @tables;


my $firstsched = 1;

my $verso = 1;

print REPORT "\nProcessing tables:\n";
print STDOUT "\nProcessing tables:\n";

TABLES:
foreach my $thistable (@tables) {

   my $line = $thistable -> {LINE};
   my $day_dir = $thistable -> {DAY_DIR};
   my @routes = @{$thistable -> {ROUTES}};
   my $routesgiven = $thistable -> {ROUTESGIVEN};
   my @batchnotes = @{$thistable -> {BATCHNOTES}} ;

   my $headnum = join ("/" , (sort byroutes @routes));

   print REPORT "$headnum\t$day_dir\n";
   print STDOUT "($headnum:$day_dir)\t";

   my ($dir, $day) = split (/_/ , $day_dir);

   read_fullsched($line, ".acs");

   my $totalrows = scalar (@{$fullsched{$day_dir}{ROUTES}});

   my $numroutes = scalar @routes;

   # the following while loop removes any rows that are for routes
   # we don't want right now.  

   if ($routesgiven) { # if any routes are given

      my %routes;
      $routes{$_} = 1 foreach @routes;
      # provides an easy "is an element" lookup

      my $count = 0;
      while ($count < $totalrows) {
         if ($routes{$fullsched{$day_dir}{ROUTES}[$count]}) {
            $count++;
         } else {
            $totalrows--;
            foreach ("ROUTES" , "NOTES" , "SPEC DAYS") {
               splice ( @{$fullsched{$day_dir}{$_}} , $count, 1);
            }
            foreach ( 0 .. ( (scalar @{$fullsched{$day_dir}{TP}}) - 1) ) {
                 splice ( @{$fullsched{$day_dir}{TIMES}[$_]} , $count, 1);
            }
         }
      }
   }

   # merge identical rows

   my $count = 1;  # not the first one -- has to be the second so it can
                   # be compared to the first. Arrays start at 0.

   IDENTIROW:
   while ($count < $totalrows) {

      my ($this, $prev);

      foreach (@{$fullsched{$day_dir}{TIMES}}) {
         $this .= $_->[$count];
         $prev .= $_->[$count-1];
      }

      if ($this ne $prev) {
         $count++;
      } else {

         if (join ("", sort 
              ($fullsched{$day_dir}{"SPEC DAYS"}[$count],
               $fullsched{$day_dir}{"SPEC DAYS"}[$count-1],
                )) eq "SDSH") 
         {
            $fullsched{$day_dir}{"SPEC DAYS"}[$count-1] = "",
         }

         # if the times are identical, and one is a school holiday and
         # the other is not, eliminate the special days on the remaining
         # timepoint.

         $totalrows--;
         foreach ("ROUTES" , "NOTES" , "SPEC DAYS") {
            splice ( @{$fullsched{$day_dir}{$_}} , $count, 1);
         }
         foreach ( 0 .. ( (scalar @{$fullsched{$day_dir}{TP}}) - 1) ) {
              splice ( @{$fullsched{$day_dir}{TIMES}[$_]} , $count, 1);
         }
         # eliminate this row
      } # if $this ne $prev 

   } # identirow

   # the following loop removes columns # for timepoints that aren't used
   for ( my $col = (scalar @{$fullsched{$day_dir}{"TP"}} -1 ); 
          $col >= 0;  $col-- ) {

      next if ( exists $fullsched{$day_dir}{TIMES}[$col] and
                join ("" , @{$fullsched{$day_dir}{TIMES}[$col]} ) ) ;

      foreach ( qw (TP TIMES TIMEPOINTS) ) {
          splice ( @{$fullsched{$day_dir}{$_}} , $col, 1);
      }
   }

   # now we determine which front columns are necessary: 
   # notes/special days, and routes


   my %uniqhash;
   my $specdays = 0;

   if ( (exists $fullsched{$day_dir}{'SPEC DAYS'}) and
        ( length(join ("" , @{$fullsched{$day_dir}{'SPEC DAYS'}})) > 0 ) ) {

      # we now know that there are special days here
 
      %uniqhash = ();
      foreach ( @{$fullsched{$day_dir}{"SPEC DAYS"}} ) {
         $uniqhash{$_ or "BLANK"} = 1;
      }

      my $theday = (keys %uniqhash)[0];

      if ((scalar keys %uniqhash) == 1 ) {
         $day = $theday;
      } else {
         $specdays = 1;
      }
   }

   my $notes = 0;
   my $allbikes = 0;

   if ( (exists $fullsched{$day_dir}{'NOTES'}) and
        ( length(join ("" , @{$fullsched{$day_dir}{'NOTES'}})) > 0 ) ) {

      # we now know that there are notes here

      %uniqhash = ();
      foreach ( @{$fullsched{$day_dir}{"NOTES"}} ) {
         $uniqhash{$_ or "BLANK"} = 1;
      }

      if ((scalar keys %uniqhash) != 1 ) {
         $notes = 1;
      } else {
         $allbikes = 1;

      }
   }

   my $notescol =  ( $notes and $specdays);

   my $routescol = ($numroutes > 1);

   my $tpcolumns = (scalar @{$fullsched{$day_dir}{TP}} );

   my $extracolumns = ($notescol ? 1 : 0) + ($routescol ? 1 : 0) ;

   my $wholespread = ($tpcolumns > 9);
   # if there are more than nine columns, we need to prepare both sides
   # of the spread

   # wholespread & verso - do nothing
   # wholespread & not verso - print a blank (recto) page, make verso true
   # not wholespread - toggle verso

   if ($wholespread) {
      unless ($verso) {
         print ('@timesblank:' , ("<\\b>" x BOXESINTEMPLATE));
         # that's the number of boxes in the template; will need to change
         $verso = 1;
      }
   } else {
     $verso = (not $verso) 
   }

   my $firstpagetps;
   if ($wholespread) {
      $firstpagetps = 9;
   } else {
      $firstpagetps = $tpcolumns;
   }
   # the above makes $firstpagetps the number of columns in the first
   # page of the spread

   my %notedefs = ();

   foreach (sort @{$fullsched{$day_dir}{NOTEDEFS}}) {
      my ($note, $def) = split (/:/);
      $notedefs{$note} = $def;
   }

   my $headname = $linename{$headnum};

   my $headday;

   if ($notedefs{$day}) {
      $headday = $notedefs{$day};
      $headday =~ s/ only//i;
   } else {
      $headday = $longerdaynames{$day};
      $headday = $day unless $headday;
   }

   $headday .= BIGSPACE . $icons{"*"} if $allbikes;

   # the following is to get the head destination,
   # which will be the last used timepoint
   my $headdest = $tphash{$fullsched{$day_dir}{TP}[-1]};

   # adds whole-schedule notes to batchnotes

   my $wholeschednotes = "";

   foreach (@batchnotes) {
#      print STDOUT "<$_> ";
      my ($notedaydir,$notedef) = split /:/;
      if ($notedaydir eq "*" or $notedaydir eq $day_dir) {
         $wholeschednotes .= "\n" if $wholeschednotes;
         # add \n but only if it's not the first one
         $wholeschednotes .= $icons{ST} . BIGSPACE . $notedef ;
         $headday .= BIGSPACE . $icons{'ST'};
      }
   }

   my $notedefs = "";

   foreach (sort @{$fullsched{$day_dir}{NOTEDEFS}}) {

       my ($note, $def) = split (/:/);

       if ($note eq '*' and $allbikes) {
          $wholeschednotes .= "\n" if $wholeschednotes;
          # add \n but only if it's not the first one
          $wholeschednotes .= $icons{'*'} . BIGSPACE . 
                  "All buses equipped with bicycle racks.";
       } elsif ($note ne $day) {
          $notedefs .= "\n" if $notedefs;
          $notedefs .= $icons{$note} . BIGSPACE . $def;
       }

   }

   # so now $notedefs is a big multiline string that has all the note
   # definitions in it.

   # OK, now we have all the information we need to print!
   # now we have to run through them in groups of 40 rows a piece.

   ROWGROUP: 
   for (my $rowgroup = 0; 
           $rowgroup < $totalrows;
           $rowgroup+= ROWSPERPAGE) 
   {

      my $continued = 0;
      my $lastrow = $totalrows;
      if ($lastrow > $rowgroup + ROWSPERPAGE) {
          $lastrow = $rowgroup + ROWSPERPAGE ;
          $continued = 1;
      } 

      if ($firstsched) {
         $firstsched = 0;
      } else {
         print "<\\b>";
         # add a "next box" character at the beginning, except on the
         # very first one
      }

      print_head ($headnum, $headname,
                  $headday, $headdest, $rowgroup != 0);
      # OK, there's the head! 


      print_rows ($rowgroup, $lastrow, $notescol, $routescol,
                  0, $firstpagetps, $day_dir , $wholespread);
      # the rows & tps for the first column

      print_left_tail($notedefs, $wholeschednotes,
                 ( $continued and ! $wholespread ));
      # the bottom bit for the first column. Include the 'continued' text
      # only if this is the last page, and this is not a full spread

      next ROWGROUP unless $wholespread;

      print '<\\b>';

      print_head ($headnum, $linename{$headnum}, 
                  $headday, $headdest, 1);
      # continued is always true on the wholespread.
      # need to do something more to distinguish continued markings...

      # rows and TPs for the second column below:
      print_rows ($rowgroup, $lastrow, 0, 0, $firstpagetps, 
        $tpcolumns+$extracolumns, $day_dir, 0);

      print_right_tail($continued); 

   } # rowgroup

} # tables

print REPORT "\n";

close REPORT;

close OUT;

#sub print_right_head () {
#    # I have no idea what should go here right now, so I'm putting nothing.
#    print '<\\b>';
#    print '<\\b>';
#}

sub print_rows ($$$$$$$$) {

# also prints timepoint headers

         my ($rowgroup, $lastrow, $notescol, $routescol,
             $starttp, $lasttp, $day_dir, $spreadverso) = @_;
         our @fullsched;


         ####################
         # timepoint numbers

         for (my $col = $starttp; $col < $lasttp ; $col++) {
            print '<\\b>@tpnum:' , $col + 1;
         } 

         # print the numbers

         print ('<\\b>' x (9 -  ($lasttp - $starttp )));
         # and any extra boxes

         ####################
         # timepoint headers

         print '<\\b>';

         print '@tpname:Notes' if $notescol;
         print ' and Route' if $routescol; 
         # must fix later to make good routes column
         
         TPHEADERCOL: 
         for (my $col = $starttp; $col < $lasttp ; $col++) {
            print '<\\b>@tpname:';
            unless ($col == 0) 
            { 
               print "Dep. " if 
                 ($fullsched{$day_dir}{TP}[$col-1] eq
                 $fullsched{$day_dir}{TP}[$col]);
            }
            unless (not $spreadverso and $col == $lasttp - 1) 
            # unless this is not the left page of a whole spread,
            # and this is the last column, check to see if the next one
            # is the same as this one
            {
               print "Arr. " if 
                 ($fullsched{$day_dir}{TP}[$col+1] eq
                 $fullsched{$day_dir}{TP}[$col]);
            }
            print $tphash{ $fullsched{$day_dir}{TP}[$col] };
         }
         # print the headers

         my $extracolumns = ($notescol ? 1 : 0) + ($routescol ? 1 : 0) ;
         # get $extracolumns for this page, which may be different from that
         # for the whole spread

         print ('<\\b>' x (9 -  ($lasttp - $starttp )));
         # print box markers for the remainder of the timepoint headers

         #######
         # rows

         print '<\\b>'; # to start the box

         ROWINGROUP: 
         for (my $row = $rowgroup; 
                $row < $lastrow;
                $row++) {

            print "\n" unless $row == $rowgroup; # all but the first one

            my $timestemp = "";
            for (my $col = $starttp; $col < $lasttp ; $col++) {
                $timestemp .= $fullsched{$day_dir}{TIMES}[$col][$row];
            }

            if ($timestemp and $starttp != 0) {
               print '@timesdots:';
            } else {
               print '@times:';
            }

            print (${fullsched}{$day_dir}{ROUTES}[$row] ) if $routescol;

            # so route always goes first

            print "\t";
            # always the columns now

            if ($notescol) {
                my @notesary;
                push @notesary, $icons{$fullsched{$day_dir}{'SPEC DAYS'}[$row]}
                       if $fullsched{$day_dir}{'SPEC DAYS'}[$row];
                push @notesary, $icons{$fullsched{$day_dir}{NOTES}[$row]}
                       if $fullsched{$day_dir}{'NOTES'}[$row];
                print join(BIGSPACE, @notesary);
            }

            COL: 
            for (my $col = $starttp; $col < $lasttp ; $col++) {
   
               my $time = $fullsched{$day_dir}{TIMES}[$col][$row];
               my $ampm = chop $time;

               substr($time, -2, 0) = ":" if $time;
   
               if ($ampm eq "p") {
                  print "\t" , '<f"HelveticaNeue BoldCond">' , $time, '<f$>';
               } else {
                  print "\t$time";
               } 

            } # col


            # add blank space for rules

            unless (($row+1) % 6) {
               print "\n\@timesblank:";
            }

         } # row

}

sub build_linenamehash () {

   open LINENAME, "<linename.txt";

   my ($key, $value, %linenamehash);

   while (<LINENAME>) {

      next if /^\s*#/;
      next unless /\t/;
      chomp;
      ($key, $value) = split("\t");
      $linenamehash{$key} = $value;

   }

   return %linenamehash;

   close LINENAME;

}

sub print_right_tail ($) {
   print_tail ( "" , shift);
   # print no text, but include the continued value from @_
}

sub print_left_tail ($$$) {
   my ($notedefs, $wholeschednotes, $continued) = @_;
   my $toprint = 
        '@legend:Light Face = a.m.' . BIGSPACE . 
        '<f"HelveticaNeue BoldCond">Bold Face = p.m.<f$>' ;
   $toprint .= "\n" . $wholeschednotes 
                 if $wholeschednotes;
   $toprint .= "\n" . $notedefs 
                 if $notedefs;
   print_tail ($toprint, $continued);
}

sub print_tail ($$) {

   my ($toprint, $continued) = @_;
   print '<\\b>';
   print $toprint;
   # print "\n" if $toprint and $continued;
   # print '@continued:Continued Next Page' if $continued;

}

sub build_batchlists ($) {

   open BATCH, (shift or "batchfile.txt");

   my (@batchlist);

   while (<BATCH>) {

      my $thisbatch = {};
      # a ref to an empty hash

      chomp;

      my @ary = split (/\t/);
      # tabs only

      my $line = shift @ary;

      my (@batchroutes, @batchnotes, @batchdays) = ();

      foreach (@ary) {

         if (s/^://) {
            push @batchdays, $_;
         } elsif (s/^=//) {
            push @batchnotes, $_;
         } else {
            push @batchroutes, $_;
         }
      }

#      print STDOUT "BATCHROUTES: " , join ("," , @batchroutes);
#      print STDOUT "BATCHNOTES: " , join ("," , @batchnotes);

      $thisbatch->{DAYS} = [ @batchdays ];

      $thisbatch->{ROUTES} = [ @batchroutes ];

      $thisbatch->{LINE} = $line;

      $thisbatch->{NOTES} = [ @batchnotes ];

      push @batchlist, $thisbatch;

   }

   close BATCH;

   return @batchlist;

}


sub print_head ($$$$$) {

      my ($num, $name, $day, $dest, $continued) = @_;

      print '@headnum:' , $num , "\n";
      print '@headname:' , $name , "\n";
      print '@headdest:To ' , $dest , "\n";
      print '@headdays:' , $day;

      print '<f"HelveticaNeue CondensedObl">' , BIGSPACE , '(continued)<f$>' 
          if $continued;

#      print '<\\b>';

}

