#!perl

# winstops.pl

require 'pubinflib.pl';

chdir get_directory() or die "Can't change to specified directory.\n";

our %tphash;

build_tphash();

open OUT , ">tptest.txt";

foreach (sort keys %tphash) {
 
   print OUT $_ , "\t" , $tphash{$_} , "\n";

}

