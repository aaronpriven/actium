#!perl

# bookscd.pl

use strict;
no strict 'subs';


no strict 'subs';
sub print_right_head () ;
sub print_right_tail ($);
sub print_rows ($$$$$$$);
sub build_linenamehash () ;
sub print_left_tail ($$) ;
sub print_tail ($$) ;
sub build_batchlists ($) ;
sub print_head ($$$$$) ;


use constant ROWSPERPAGE => 36;
use constant DROPCAPLINES => 2;

require 'pubinflib.pl';

init_vars();

our (%daydirhash, %longdaynames);

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

my (%batchroutes, %batchdays, %routes);
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

   DAYDIR:
   foreach my $day_dir (keys %fullsched) {

      my ($dir, $day) = split (/_/ , $day_dir);

      next DAYDIR unless ((not scalar %batchdays) or $batchdays{$day});

      # OK, so now we know that this daydir is indeed used

      my $thistable = {};

      print REPORT "$line\t$day_dir\n";

      $thistable->{DAY_DIR} = $day_dir;
      $thistable->{LINE} = $line;

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

print REPORT "\nProcessing tables:\n";
print STDOUT "\nProcessing tables:\n";

TABLES:
foreach my $thistable (@tables) {

   my $line = $thistable -> {LINE};
   my $day_dir = $thistable -> {DAY_DIR};
   my @routes = @{$thistable -> {ROUTES}};
   my $routesgiven = $thistable -> {ROUTESGIVEN};

   my $headnum = join ("/" , (sort byroutes @routes));

   print REPORT "$headnum\t$day_dir\n";
   print STDOUT "($headnum:$day_dir)\t";

   my ($dir, $day) = split (/_/ , $day_dir);

   read_fullsched($line, ".acs");

   my $totalrows = scalar (@{$fullsched{$day_dir}{ROUTES}});

   my $numroutes = scalar @routes;

   # the following while loop removes any rows that are for routes
   # we don't want right now.  If no specific rotues were given, 
   # simply set %routes 
   # to be all routes present.

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

   my $notescol =  ( ( exists $fullsched{$day_dir}{'NOTES'} and
        length(join ("" , @{$fullsched{$day_dir}{'NOTES'}})) > 0 )
              or
        ( exists ( $fullsched{$day_dir}{'SPEC DAYS'} ) and 
        length(join ("" , @{$fullsched{$day_dir}{'SPEC DAYS'}})) > 0 ) );

   # ok -- if the NOTES array exists and it's not empty, or if the
   # SPEC DAYS array exists and it's not empty, print the notes column.
   # (if you just check to see that it's empty, it gives a fatal
   # "can't use undefined value as array reference" error.)


   my $routescol = ($numroutes > 1);

   my $tpcolumns = (scalar @{$fullsched{$day_dir}{TP}} );

   my $extracolumns = ($notescol ? 1 : 0) + ($routescol ? 1 : 0) ;

   my $wholespread = ($tpcolumns+$extracolumns) > 9;
   # if there are more than nine columns, we need to prepare both sides
   # of the spread

   my $firstpagetps;
   if ($wholespread) {
      $firstpagetps = 9 - $extracolumns;
   } else {
      $firstpagetps = $tpcolumns;
   }
   # the above makes $firstpagetps the number of columns in the first
   # page fo the spread

   my $headday = $longdaynames{$day};
   $headday = $day unless $headday;

   # the following is to get the head destination,
   # which will be the last used timepoint
   my $headdest = $tphash{$fullsched{$day_dir}{TP}[-1]};

   my $notedefs = "";
   foreach (@{$fullsched{$day_dir}{NOTEDEFS}}) {
       my ($note, $def) = split (/:/);
       $notedefs .= "\n\@notedefs:$note: $def";
       # probably could do that just with an s/:/: / but 
       # I already did it and it's easier to do more with later.
   }
   # so now $notedefs is a big multiline string that has all the note
   # defintions in it.

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

      print_head ($headnum, $linename{$headnum}, 
                  $headday, $headdest, $rowgroup != 0);
      # OK, there's the head! Now the rows & tps for the first column


      print_rows ($rowgroup, $lastrow, $notescol, $routescol,
                  0, $firstpagetps, $day_dir);
      # Now the rows & tps for the first column

      print_left_tail($notedefs, 
                 ( $continued and ! $wholespread ));
      # the bottom bit for the first column. Include the 'continued' text
      # only if this is the last page, and this is not a full spread

      next ROWGROUP unless $wholespread;

      print_right_head ();

      # rows and TPs for the second column below:
      print_rows ($rowgroup, $lastrow, 0, 0, $firstpagetps, 
        $tpcolumns+$extracolumns, $day_dir);

      print_right_tail($continued); 

   } # rowgroup

} # tables

print REPORT "\n";

close REPORT;

close OUT;

sub print_right_head () {
    # I have no idea what should go here right now, so I'm putting nothing.
    print '<\\b>';
}

sub print_rows ($$$$$$$) {

# also prints timepoint headers

         my ($rowgroup, $lastrow, $notescol, $routescol,
             $starttp, $lasttp, $day_dir) = @_;
         our @fullsched;

         ####################
         # timepoint headers

         print '<\\b>@tpheader:Notes' if $notescol;
         print '<\\b>@tpheader:Route' if $routescol;
         
         TPHEADERCOL: 
         for (my $col = $starttp; $col < $lasttp ; $col++) {
            print '<\\b>@tpheader:';
            print $tphash{ $fullsched{$day_dir}{TP}[$col] };
         }
         # print the headers

         my $extracolumns = ($notescol ? 1 : 0) + ($routescol ? 1 : 0) ;
         # get $extracolumns for this page, which may be different from that
         # for the whole spread

         print ('<\\b>' x (9 -  ($extracolumns + $lasttp - $starttp )));
         # print box markers for the remainder of the timepoint headers

         #######
         # rows

         print '<\\b>@times:';

         ROWINGROUP: 
         for (my $row = $rowgroup; 
                $row < $lastrow;
                $row++) {

            print "\n" unless $row == $rowgroup; # all but the first one

            if ($notescol) {
                my @notesary;
                push @notesary, $fullsched{$day_dir}{'SPEC DAYS'}[$row];
                push @notesary, $fullsched{$day_dir}{NOTES}[$row];
                print "\t" , join (' ', @notesary);
            }

            print ("\t" , ${fullsched}{$day_dir}{ROUTES}[$row] ) if $routescol;

            COL: 
            for (my $col = $starttp; $col < $lasttp ; $col++) {
   
               my $time = $fullsched{$day_dir}{TIMES}[$col][$row];
               my $ampm = chop $time;

               substr($time, -2, 0) = ":" if $time;
   
               if ($ampm eq "p") {
                  print "\t<B>$time<B>";
               } else {
                  print "\t$time";
               } 

            } # col

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

sub print_left_tail ($$) {
   my ($notedefs, $continued) = @_;
   my $toprint = '@timenote:Light Face = a.m.  <B>Bold Face = p.m.<B>' . 
              $notedefs;
   print_tail ($toprint, $continued)
}

sub print_tail ($$) {

   my ($toprint, $continued) = @_;
   print '<\\b>';
   print $toprint;
   print "\n" if $toprint and $continued;
   print '@continued:Continued Next Page' if $continued;

}

sub build_batchlists ($) {

   open BATCH, (shift or "batchfile.txt");

   my (@batchlist);

   while (<BATCH>) {

      my $thisbatch = {};
      # a ref to an empty hash

      chomp;

      my @ary = split (/[\s,]+/);
      # either commas or white space

      my $line = shift @ary;

      my @batchdays = ();

      while ($ary[0] =~ /^:/) {
         # if it begins with a colon, mark it as a day, not a route
         my $day = shift @ary;
         $day =~ s/^://;
         push @batchdays, $day;
      }

      $thisbatch->{DAYS} = [ @batchdays ];

      $thisbatch->{ROUTES} = [ @ary ];

      $thisbatch->{LINE} = $line;

      push @batchlist, $thisbatch;

   }

   close BATCH;

   return @batchlist;

}


sub print_head ($$$$$) {

      my ($num, $name, $day, $dest, $continued) = @_;

      print '@head:<';

      print '*d(' , length($num) +1 , ',' , DROPCAPLINES , ')>';  # drop cap

      print "$num \U$name\E<\\n>";
      print "$day to $dest";

      print ' <I>(continued from previous page)<I>' if $continued;

#      print '<\\b>';

}

