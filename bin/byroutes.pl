sub byroutes ($$) {

   my ($a, $b) = (uc($_[0]) , uc($_[1]));
 
   my $anum = ( $a lt "A" );
   my $bnum = ( $b lt "A" );
   # So, $anum is true if $a is a number, etc.

   unless ($anum == $bnum) {
           return -1 if $anum;
           return 1;
   }

   #  If they're not both numbers or both letters,
   #  return -1 if $a is a number (and $b is not), otherwise
   #  return 1 (since $b must be a number and $a is not)
   
   #  letters come after numbers in our lists.

   return ($a cmp $b) unless ($anum);
   # return a string comparison unless they're both numeric
   # (of course, $anum == $bnum or it would have returned already)

   my @a = split (/(?<=\d)(?=\D)/ , $a, 2);
   my @b = split (/(?<=\d)(?=\D)/ , $b, 2);

   # splits on the boundary (zero-width) between
   # a digit on the left and a non-digit on the right.
   # so it splits 72L into 72 and L, whereas it leaves
   # 72, O, and OX1 as one entry each.

   return (   ($a[0] <=> $b[0]) || ($a[1] cmp $b[1]) )
   # they are both numbers, so return a numeric comparison
   # on the first component, unless they're the same, 
   # in which case return a string comparison on the second component.

}

1;
