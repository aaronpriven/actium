#!/usr/bin/perl

use strict;
use warnings;

use Fatal ('open' , 'chdir');

my %seen;

chdir "/Volumes/Bireme/ACTium/db/sum06";

$/ = "\r";

open my $in , "<" , "Signs.tab";
open my $out , ">" , "Signsout.tab";

while (<$in>) {

   my ($id, $line) = split("\t", $_, 2);

   print "$id ";

   next if ($seen{$line} and $id > 10000 );
   print $out "$id\t$line";

   $seen{$line} = 1;

} 

print "\n";