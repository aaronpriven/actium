# Skedfile.pm
# vimcolor: #200000

# This is Skedfile.pm, a module to read and write
# the tab-separated-value text files which store the bus schedules.

# Also performs operations on bus schedule data structures that 
# are shared between various programs.

package Skedfile;

use strict;
our (@ISA , @EXPORT_OK);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(Skedread Skedwrite 
                remove_blank_columns trim_sked copy_sked times_column);

use Storable (dclone);
# Storable is a module that needs to be imported from CPAN
# By far the easiest way of doing that is to install fink (fink.sf.net) --
# fink requires it. And fink is good to have anyway

sub Skedread {

   local ($_);

   my $skedref = {};

   my ($file) = shift;

   open IN, $file
      or die "Can't open $file for input";

   $_ = <IN>;
   chomp;
   s/\s+$//;
   $skedref->{SKEDNAME} = $_;

   ($skedref->{LINEGROUP} , $skedref->{DIR} , $skedref->{DAY}) =
      split (/_/);

   $_ = <IN>;
   s/\s+$//;
   chomp;
   (undef, @{$skedref->{NOTEDEFS}} ) = split (/\t/ );
   # first column is always "Note Definitions"

   $_ = <IN>;
   chomp;
   s/\s+$//;
   (undef, undef, undef, undef, @{$skedref->{TP}} ) = split (/\t/);
   # the first four columns are always "SPEC DAYS", "NOTE" , "VT" , and "RTE NUM"

   while (<IN>) {
       chomp;
       s/\s+$//;
       next unless $_; # skips blank lines
       my ($specdays, $note, $vt, $route , @times) = split (/\t/);

       push @{$skedref->{SPECDAYS}} , $specdays;
       push @{$skedref->{NOTES}} , $note;
       push @{$skedref->{VT}} , $vt;
       push @{$skedref->{ROUTES}} , $route;

       $#times = $#{$skedref->{TP}}; 
       # this means that the number of time columns will be the same as 
       # the number timepoint columns -- discarding any extras and
       # padding out empty ones with undef values

       for (my $col = 0 ; $col < scalar (@times) ; $col++) {
          push @{$skedref->{TIMES}[$col]} , $times[$col] ;
       }
   }
   close IN;
   return $skedref;
}

sub Skedwrite ($;$) {

   my ($skedref , $extension) = @_;

   $extension ||= '.txt';

   my $skedname = $skedref->{SKEDNAME};

   unless (-d "skeds") {
      mkdir "skeds" or die "Can't create skeds directory";
   }

   open OUT , ">skeds/$skedname$extension"
      or die "Can't open skeds/$skedname$extension for output";

   print OUT $skedname , "\n";
   print OUT "Note Definitions:\t" , 
              join ("\t", @{$skedref->{"NOTEDEFS"}} ) , "\n"; 
   print OUT "SPEC DAYS\tNOTE\tVT\tRTE NUM\t" , 
              join ("\t"  , @{$skedref->{"TP"}} ) , "\n"; 

   # get the maximum number of rows

   my $maxrows = 0;
   foreach (@{$skedref->{"TIMES"}}) {
   
       # so $_ will be the reference to the first list 
       # of times, then the ref to second list of times...
   
       my $rowsforthispoint = scalar (@$_);
       
       # $_ is the reference to the list of times. 
       # @$_ is the list of times itself. 
       # scalar (@$_) is the number of elements in the list of times. Whew!

       $maxrows = $rowsforthispoint if $rowsforthispoint > $maxrows;
       
   }

   for (my $i=0; $i < $maxrows ;  $i++) {

      print OUT $skedref->{"SPECDAYS"}[$i] , "\t" ;
      print OUT $skedref->{"NOTES"}[$i] , "\t" ;
      print OUT $skedref->{"VT"}[$i] , "\t" ;
      print OUT $skedref->{"ROUTES"}[$i] , "\t" ;

      foreach (@{$skedref->{TIMES}}) {
          print OUT $_ -> [$i] , "\t";

      }
      # ok. $_ becomes the ref to the first, second, etc. list of times.  

      print OUT "\n";

   }
   
   close OUT;
   
   return $skedref;

}


sub remove_blank_columns ($) {

   my $dataref = shift;

   my $tp = 0;
   while ( $tp < ( scalar @{$dataref->{"TP"}}) ) {
      # loop around each timepoint
      unless (join ('', times_column($dataref,$tp))) {
         # unless there is some data in the TIMES for this column,
         splice (@{$dataref->{"TIMES"}}, $tp, 1);
         splice (@{$dataref->{"TP"}}, $tp, 1);
         # delete this column
         next;
      }
   $tp++;
   }

}

sub times_column ($$) {

   my ($skedref , $tpnum) = @_;
   my @times = ();

   for (my $row = 0 ; $row < scalar (@{$skedref->{ROUTES}}) ; $row++) {
      push @times , $skedref->{TIMES}[$tpnum][$row]; # TODO - check this out
   }

   return @times;

}

sub copy_sked {

   # takes a schedule and returns a reference to a copy of all the 
   # data in the schedule

   my ($givensked) = @_;

   return dclone ($givensked);

=pod   


   my $sked = {}; # empty anonymous hash

   ### make a copy of all data in $givensked into $sked
   #   (we have to do this because otherwise we will screw up future
   #   passes with this data)

   # first, copy scalars
   $sked->{$_} = $givensked->{$_} foreach qw(SKEDNAME LINEGROUP DIR DAY);
   # then, copy arrays
   @{$sked->{$_}} = @{$givensked->{$_}} 
      foreach qw(SPECDAYS VT NOTES ROUTES NOTEDEFS TP);

   # then, copy TIMES (an array of arrays)
   $sked->{TIMES} = []; # ref to empty array

   foreach my $col (0 .. scalar (@{$givensked->{TP}}) - 1) {
      push @{$sked->{TIMES}} , [ @{$givensked->{TIMES}[$col]} ];
   }

   return $sked;

=cut

}

sub trim_sked {

   my ($sked, $subset) = @_;

   # the following will remove any rows that are for 
   # routes we don't want right now.  

   my %routes = ();

   my $totalrows = scalar (@{$sked->{ROUTES}});

   if ($subset) { # if any routes are given

      # provides an easy "is an element" lookup
      $routes{$_} = 1 foreach @$subset;

      my $count = 0;
      while ($count < $totalrows) {
         if ($routes{$sked->{ROUTES}[$count]}) {
            $count++;
         } else {
            $totalrows--;
            foreach ( qw(ROUTES NOTES VT SPECDAYS)) {
               splice ( @{$sked->{$_}} , $count, 1);
            }
            foreach my $col ( 0 .. ( (scalar @{$sked->{TP}}) - 1) ) {
                 splice ( @{$sked->{TIMES}[$col]} , $count, 1);
            }
         }
      }
   } else { # no routes are given, so use them all
      $routes{$_} = 1 foreach @{$sked->{ROUTES}};
   }

   ### merge identical rows

   my $row = 1;    # not the first one -- has to be the second so it can
                   # be compared to the first. Arrays start at 0.

   IDENTIROW:
   while ($row < $totalrows) {

      my $this = "";
      my $prev = "";

      foreach my $col (0 .. scalar @{$sked->{TP}} - 1) {
         my $thistime = ($sked->{TIMES}[$col][$row] or "");
         my $prevtime = ($sked->{TIMES}[$col][$row-1] or "");

         $this .= $thistime;
         $prev .= $prevtime;
      }

      if ($this ne $prev) {
         $row++;
      } else {

         if (join ("", sort 
              ($sked->{SPECDAYS}[$row],
               $sked->{SPECDAYS}[$row-1],
                )) eq "SDSH") 
         {
            $sked->{SPECDAYS}[$row-1] = "",
         }

         # if the times are identical, and one is a school holiday and
         # the other is school days only, eliminate the special days 
         # on the remaining # timepoint.

         $totalrows--;
         foreach (qw(ROUTES NOTES VT SPECDAYS)) {
            splice ( @{$sked->{$_}} , $row, 1);
         }
         foreach ( 0 .. ( (scalar @{$sked->{TP}}) - 1) ) {
              splice ( @{$sked->{TIMES}[$_]} , $row, 1);
         }
         # eliminate this row
      } # if $this ne $prev 

   } # identirow

   ### remove columns for timepoints that aren't used

   remove_blank_columns($sked);

   return %routes;

}
