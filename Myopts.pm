# Myopts

# My wrapper for Getopt::Long

# by Aaron Priven

# Legacy stage 1. This should be replaced by Actium::Options

package Myopts;
use Exporter;
our @ISA = ('Exporter');
our @EXPORT_OK = ('options');

use Getopt::Long;

sub options {

   # arguments:
   # if first arg is a hash ref, uses that as the place to store the
   # results.
   # The rest is a list of options, in the format used by 
   # Getopts::Long. e.g., option=s asks for a string marked "options".

   my $hashref;
   if (ref ($_[0]) eq "HASH" ) {
      $hashref = shift;
      %$hashref = (); 
      # zeroes out option entries -- not doing this might confuse Getopt::Long
   } else {
      $hashref = {};
   }

   GetOptions ($hashref, @_);

   my @args = @_; # make a copy so it doesn't try to modify read-only values
   foreach my $entry (@args) {
      $entry =~ s/[!+:=][sif]?$//; # eliminates options
      $hashref->{$entry} = undef unless exists $hashref->{$entry};
   }

   # This says that all entries not on the command line are undef.
   # If we don't do this, the hash won't have an entry at all, and
   # $hashref->{$entry} might give an error. Or so I am told.

   return;

}
