#!/usr/bin/perl

use Win32::GUI;
use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';

chdir get_directory() or die "Can't change to specified directory.\n";

my @lines;

@lines = get_lines();

shift @lines; # dump the first result, the line with the longest name

our @fullsched;

our %fullsched;

my $pageswide;

open OUT , ">u:/lines by division/countrows.txt";
select OUT;

foreach my $line (@lines) {

   read_fullsched ($line, 2);
   # the 2 says not to try to cross-reference *any* timepoints

   print "$line";

   foreach my $day_dir (sort byroutes keys %fullsched) {

#      print "\t$day_dir\t";

      $pageswide = 1;
      $pageswide = 2 if scalar (@{$fullsched{$day_dir}{TP}}) > 9;

      print "\t$pageswide\t";
 
      print scalar (@{$fullsched{$day_dir}{ROUTES}});

   }

   print "\n";
} 




