sub byroutes  {


   no warnings "numeric";

   my ($aa, $bb, $anum, $bnum);

   $aa = uc($a);
   $bb = uc($b);
   
   $anum = $aa > 0;
   $bnum = $bb > 0;
   # So, $anum is true if $a is a number, etc.

   return ($bnum <=> $anum) unless $anum == $bnum;

   #  If they're not the same, return whichever one is lesser
   #  (which will be whichever one is the number).

   return ($aa <=> $bb) if ($anum and $bnum);
 
   # if $a and $b are both numbers, return a numeric comparison

   return ($aa cmp $bb);

   # otherwise they are both strings, so return the string comparison

}

1;
