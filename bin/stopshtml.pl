#!perl

open IN, "c:/aarondoc/scheds/mar01/stops.txt" or die;

open OUT , ">c:/aarondoc/scheds/mar01/stopsigns-test.html" or die;

$_ = <IN>;

chomp;

@fields = split (/\t/);

$count = 0;

foreach (@fields) {

   $fields{$_} = $count;

   $count++;
}

# @fields gives all the fields in order.
# %fields contains the index entry for each field.
# so if "On" is the 3rd field, $fields{"On"} is 2.  (starts at 0)

while (<IN>) {

   chomp;
   push @lines , [ split (/\t/) ];

}

print OUT "<table border=1>\n<tr><th>" , join ("</th><th>" , @fields) ;
print OUT "</th></tr>\n";

@lines = sort { 
        $a->[$fields{"Project"}] cmp $b->[$fields{"Project"}] or
        $a->[$fields{"City"}] cmp $b->[$fields{"City"}] or
        $a->[$fields{"On"}] cmp $b->[$fields{"On"}] or
        $a->[$fields{"At"}] cmp $b->[$fields{"At"}] or
        $a->[$fields{"StopID"}] <=> $b->[$fields{"StopID"}]
              } @lines;

foreach (@lines) {

   print OUT "<tr><td>";

   print OUT join ("</td><td>" , @{$_}) ;

   print OUT "</td></tr>\n";

}

print OUT "</table>";

