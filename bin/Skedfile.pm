# Skedfile.pm
# vimcolor: #200000

# This is Skedfile.pm, a module to read and write
# the tab-separated-value text files which store the bus schedules.

package Skedfile;

use strict;
our (@ISA , @EXPORT_OK);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(Skedread Skedwrite);

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
   (undef, undef, undef, @{$skedref->{TP}} ) = split (/\t/);
   # the first three columns are always "SPEC DAYS", "NOTE" , and "RTE NUM"

   while (<IN>) {
       chomp;
       s/\s+$//;
       next unless $_; # skips blank lines
       my ($specdays, $note, $route , @times) = split (/\t/);

       push @{$skedref->{SPECDAYS}} , $specdays;
       push @{$skedref->{NOTES}} , $note;
       push @{$skedref->{ROUTES}} , $route;

       $#times = $#{$skedref->{TP}}; 
       # this means that the number of time columns will be the same as 
       # the number timepoint columns -- discarding any extras and
       # padding out empty ones with undef values

       for (my $i = 0 ; $i < scalar (@times) ; $i++) {
          push @{$skedref->{TIMES}[$i]} , $times[$i] ;
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
   print OUT "SPEC DAYS\tNOTE\tRTE NUM\t" , 
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
