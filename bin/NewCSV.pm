# This is NewCSV.pm, which picks out the fields from a CSV 
# There is a CPAN routine that does this (Text::CSV) but it's slow.
# Even slower than this.

package NewCSV;

use strict;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(parse_csv);

use constant QUOTE => '"';
use integer; # ever so slightly faster

1;

sub parse_csv ($) {

   my $line = shift;

   # my @chars = split (// , +shift);

   my $quotestatus = 0; # not in quotes

   # it is apparently faster to store length 
   # and decrement when necessary rather than recomputing it

   my $length = length($line);

   CHAR:
   for (my $i = 0; $i < $length; $i++) { # }

      my $c = substr($line, $i, 1);

      # print "i:$i\tc:$c\n";

      # we're working with the $c character, which is the $i'th 
      # character of $line

      ### If it's a quote
      if ($c eq QUOTE) { 
         substr($line,$i,1,"");
         $length--;
         # remove the quote from the line
         $c = substr($line, $i , 1); 

         # we are now working with the character *after* the quote.

         # If it's a quote, we know we've just seen a double quote.
         # Inside quotes, this should become a single quote, so we 
         # just leave the quote and go to the next character.
         # Outside quotes, this means we have a blank field. We
         # delete the quote and go to the next field.

         # If it's anything else, we know we've just seen a single quote,
         # so we toggle $quotestatus. Then we stay in the loop,
         # because it might be a comma.

         # If the quote is the last character in the line,  $c will be "",
         # and fail the following tests.

         if ($c eq QUOTE) {
            next CHAR if $quotestatus; # if we're in quotes, leave it
            substr($line,$i,1,""); # otherwise, we've just seen double
            $length--;
                                   # quotes indicating an empty field.
                                   # delete the quote. The only valid
                                   # next character is a comma.
            $c = substr($line, $i , 1); 
            # character after the second quote
         } else {
               $quotestatus = not ($quotestatus);
         }

      }

      next if $quotestatus;
      # if we're in quotes, we don't need to replace the comma

      ### It's a comma and we're in quotes, so make it a tab
      substr($line,$i,1,"\t") if $c eq ",";

   }

   # so now $line is tab-separated

   return split (/\t/ , $line);
   # returns the array

}

