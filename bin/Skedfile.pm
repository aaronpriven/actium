# Skedfile.pm
# vimcolor: #000000

# This is Skedfile.pm, a module to read and write
# the tab-separated-value text files which store the bus schedules.

package Skedfile;

use strict;
our (@ISA ,@EXPORT_OK ,$VERSION);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw(Skedread Skedwrite);

sub Skedread ($;$) {

   my $skedref = {};

   my ($line, $ext) = @_;

   # read the schedule

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
      or die "Can't open skeds/$skedname.$extension for output";

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
