# This is NewCSV.pm, which picks out the fields from a CSV 
# There is a CPAN routine that does this (Text::CSV) but it's slow.

package NewCSV;

use strict;

use Exporter;
our @ISA = ('Exporter');
our @EXPORT = qw(parse_csv);

use constant IN => 1;
use constant OUT => 0;
use constant QUOTE => '"';

1;

sub parse_csv ($) {

   my $line = shift;
   my $newline = "";

   # my @chars = split (// , +shift);

   my $quotestatus = OUT;


   local ($_);
   for (my $i = 0; $i < length($line); $i++) {

      $_ = substr($line, $i, 1);

      ### It's a comma
 
      if ($_ eq ",") { 
         $newline .= ( $quotestatus ? "," : "\t" );
         # if we're in quotes, it's still a comma, otherwise it's a tab

      ### It's a quote

      }  elsif ($_ eq QUOTE) {
         $_ = substr($line, $i + 1, 1); 
         # this is now the *following* character

         ### We've been in quotes
 
         if ($quotestatus) { 

            ### following char is a quote -- a double quote representing
            ### a quote char in the field

            if ($_ eq QUOTE) {
               $newline .= QUOTE;
               $i++; 
               # add a quote to $newline and skip the next entry

            ### next char is not a quote -- so we're no longer in quotes

            } else {
               $quotestatus = OUT;
            }

         ### It's a quote, and we've not been in quotes

         } else { # we've not been in quotes
               $quotestatus = IN;
               # now we are
         }

      # neither quote nor comma
      } else {

      $newline .= $_;

      }

   } # end for loop 

   # so now $newline is tab-separated

   return split (/\t/ , $newline);
   # returns the array

}

