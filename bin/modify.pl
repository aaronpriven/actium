use strict;

open OUT , ">newstops.txt";

select OUT;

$_ = <>;

chomp;

my @keys = split (/\t/);

 my @newkeys = qw (
StopID City Neighborhood OnStreet AtStreet NearFar Direction Condition Type
               );

print join ("\t" , @newkeys);

print "\n";

while (<>) {

   chomp;

   my @values = split(/\t/);
   my %hash;

   foreach (@keys) {
      $hash{$_} = shift @values;
      $hash{$_} =~ s/^\s+//;
      $hash{$_} =~ s/\s+$//;
   }

   %hash = dostuff(%hash);

   @values = ();

   push @values , $hash{$_} foreach (@newkeys);

   foreach (@values) {
      s/^\s+//;
      s/\s+$//;
   }

   print join ("\t" , @values) , "\n";

}

sub dostuff {

   my %hash = @_;

    $hash{"U_Description"} =~ s/\b(\w+)/\u\L$1/g;

   ($hash{"OnStreet"} , $hash{"AtStreet"} ) = 
      split (/\@/ , $hash{"U_Description"} , 2);

   delete $hash{"U_Description"};

return %hash;
}
