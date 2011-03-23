#!/usr/bin/perl

# pat-places 

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

my $in_service;

while (<>) {
   chomp;

   my @fields = split(/,/);

   if ($fields[0] eq 'PAT') {
      s/\s+$//;

      $in_service = $fields[6] eq 'X';

      next unless $in_service;

      print "\n\n$_\n";
      next;
   }

   next unless $in_service;

   my $place = $fields[2];

   $place =~ s/\s+$//;
   $place =~ s/^\s+//;
   
   print "$place " if $place;

}
