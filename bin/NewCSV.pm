# This is NewCSV.pm, which picks out the fields from a line from a 
# FileMaker "merge" file.

# This is NOT a generalized CSV parser! Merge files guarantee that their

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

   my $quotestatus = 0; # not in quotes

   CHAR:
   for (my $i = 0 ; $i != -1 ; $i = index ($line, QUOTE , $i + 1) ) {

      substr($line,$i,1,"");
      # remove the quote from the line.

      my $c = substr($line, $i , 1); 

      # we are now working with the character *after* the quote.

      # If it's a quote, we know we've just seen a pair of quote marks.
      # Inside quotes, this should become a single quote, so we 
      # just leave the quote and go to the next character.
      # Outside quotes, this means we have a blank field. We
      # delete the quote and go to the next field.

      # If it's anything else, we know we've just seen a single quote,
      # so we toggle $quotestatus. Then we stay in the loop,
      # because it might be a comma.

      # If the quote is the last character in the line,  $c will be "",
      # and fail the following tests.


      # if the next character is also a quote,
      if ($c eq QUOTE) {
         next CHAR if $quotestatus; 
         # leave it alone if we're in a quoted area.
         # FileMaker encodes " as "" inside field data.

         substr($line,$i,1,"");
         # So this is seen double quotes not inside a field area,
         # It indicates an empty field. delete the quote. 
         # The only valid next character is a comma.

      } else {
            $quotestatus = not ($quotestatus);
            # it's not a double quote, so we toggle whether 
            # we're inside a field or not.
      }

      next if $quotestatus;

      substr($line, $i, 1, "\t") unless ($quotestatus);
      # OK. We know that we've just seen either a quote that ends
      # a field. The ONLY valid next character is a comma. Change it
      # to a tab, to avoid any commas in data.
   }

   # so now $line is tab-separated

   return split (/\t/ , $line);
   # returns the array

}

