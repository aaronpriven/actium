# Byroutes.pm, Aaron's extra special cool routine to sort route numbers
# properly.

# by Aaron Priven

package Byroutes;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('byroutes');

# usage: sort byroutes (@list);

sub byroutes ($$) {

   local ($^W) = 0;
   # turn warnings off, so that we don't get "bogus numeric conversion" errors

   my ($aa, $bb) = (uc($_[0]) , uc($_[1]));
   # I know there was a reason I used @_ here instead of $a and $b. 
   # I think it had to do with one of the calling routines itself being in
   # a sort {block}, and the $a and $b from byroutes were clobbering 
   # the sort block's own $a and $b.

   # Also, the man page says that you need the prototyped version
   # to use a sort routine in another package, but that's not why I did it.
 
   my $anum = ( $aa =~ /^\d/ );
   my $bnum = ( $bb =~ /^\d/ );
   # So, $anum is true if $aa starts with a number.

   unless ($anum == $bnum) {
           return -1 if $anum;
           return 1;
   }

   #  If they're not both numbers or both letters,
   #  return -1 if $a is a number (and $b is not), otherwise
   #  return 1 (since $b must be a number and $a is not)
   
   #  letters come after numbers in our lists.

   return ($aa cmp $bb) unless ($anum);
   # return a string comparison unless they're both numeric
   # (of course, $anum == $bnum or it would have returned already)

   my @a = split (/(?<=\d)(?=\D)/ , $aa, 2);
   my @b = split (/(?<=\d)(?=\D)/ , $bb, 2);

   # splits on the boundary (zero-width) between
   # a digit on the left and a non-digit on the right.
   # so it splits 72L into 72 and L, whereas it leaves
   # 72, O, and OX1 as one entry each.

   return (   ($a[0] <=> $b[0]) || ($a[1] cmp $b[1]) )
   # they are both numbers, so return a numeric comparison
   # on the first component, unless they're the same, 
   # in which case return a string comparison on the second component.

}
