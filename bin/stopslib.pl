#!perl

=pod

stopslib.pl
library of routines associated with the stops file

The stops file is a tab-delimited ascii file. The field names
form the first line, followed by a set of stops, one line per stop, each
with a field.

The routines will accept and spit back any field.  They know about the 
following fields and will add them if they are not present in the 
original file:

   StopID
   City
   Neighborhood
   On
   At
   StNum
   NearFar
   Direction
   Condition
   SignType

The format in memory for this is under the hash %stops. The format is

$stops{stopid}{field} = the value of that field.

=cut

use strict;
use constant NL => "\n";
use constant TAB => "\t";

sub readstops ($) {

   my (@values, %isakey, @keys, %hash, %stops);
   my $filename = $_[0];
   local ($_);

   open  STOPFILE, $filename or die "Can't open stops file for reading";

   $_ = <STOPFILE>;
   chomp;
   @keys = split (/\t/);
   %stops = ();

   while (<STOPFILE>) {
      chomp;

      @values = split (/\t/);
      %hash = ();

      foreach (@keys) {
         $hash{$_} = shift @values;
         $hash{$_} = substr($hash{$_}, 1, length ($hash{$_}) -2)
              if ($hash{$_} =~ /^"/) and ($hash{$_} =~ /"$/);

         # removes bracketing quote marks, which are put there for mysterious
         # reasons by Excel sometimes

      }

      $stops{$hash{"StopID"}} = { %hash };

      # yes, $stops{$stopid}{"StopID"} will always be the same as
      # $stopid itself, on a valid record.
      
   }

   $isakey{$_} = 1 foreach (@keys);

   foreach (qw( StopID City Neighborhood On At
               StNum NearFar Direction Condition )) {

      push @keys, $_ unless $isakey{$_};   

   }

   return ( \@keys, \%stops );

}

sub writestops ($\@\%) {

   my $filename = shift;
   my @keys = @{ +shift } ;
   my %stops = %{ +shift } ;
   my @values;

   unless (rename $filename , "$filename.bak") {
      $filename = 'TEMPFILE.$$$';
      warn qq(Can't rename old stops file; saving as "$filename");
   }
 
   open STOPS , ">$filename" or die "Can't open stops file for writing";

   print STOPS join ( TAB , @keys) , NL ;

   while (my $stopid = each %stops) {

      @values = ();

      foreach (@keys) {
          push @values , $stops{$stopid}{$_};
      }

      print STOPS join ( TAB , @values) , NL;
      
   }

   close STOPS;

}


sub stopdescription ($$$) {

   my ($stopid, $stopref,$stopdata) = @_;

   my $description = "";

   $description .= "$stopref->{'StNum'} " 
          if $stopref->{'StNum'};
   $description .= $stopref->{'On'};
   $description .= " at $stopref->{'At'}" 
          if $stopref->{'At'};
   $description .= ", going $stopref->{'Direction'}";
   
   $description .= " ($stopid)";

   $description .= ' *' unless $stopdata;

   return $description;

}

sub get_stopid_from_description {

  my $description = shift;

  my $leftparenpos = rindex ($description, '(');
  my $rightparenpos = rindex ($description, ')');

  return
     substr ($description, $leftparenpos+1, $rightparenpos - $leftparenpos - 1)


}

sub stopdesclist (\%\%) {

   my %stops = %{+shift};
   my %stopdata = %{+shift};
   my @retlist;

   foreach (sort 
           {  
             $stops{$a}{"On"} cmp $stops{$b}{"On"} or 
             $stops{$a}{"At"} cmp $stops{$b}{"At"} or
             $stops{$a}{"StNum"} <=> $stops{$b}{"StNum"} or
             $stops{$a}{"Direction"} cmp $stops{$b}{"Direction"} 
           } 
         keys %stops) 
   {
      push @retlist, stopdescription($_,$stops{$_},$stopdata{$_});
   }

return @retlist;

}

1;
