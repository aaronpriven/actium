#!/usr/bin/perl

use Win32::GUI;
use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';

chdir get_directory() or die "Can't change to specified directory.\n";

my @lines;

@lines = get_lines();

# shift @lines; # dump the first result, the line with the longest name

our @fullsched;

our %fullsched;

open OUT , ">firstlast.txt";
select OUT;

foreach my $line (@lines) {

   read_fullsched ($line, 2);
   # the 2 says not to try to cross-reference *any* timepoints

   foreach my $day_dir (sort byroutes keys %fullsched) {

#      print "\t$day_dir\t";


      my %routestemp;

      foreach ( @{$fullsched[$day_dir]{ROUTES}}  ) {

         $routestemp{$_} = 1;  

      }

      foreach ( sort byroutes keys (%routestemp) ) {

         print "Route group: $line\tDay and Dir: $daydir\tRoute: $route\n"

         my @thisline, @tps;
         
         foreach my $tp ( @{$fullsched[$day_dir]{TPS}} ) {

            push @tps, $tp;

            push @thisline, $fullsched[$day_dir]{TIMES}[$tp][0];

         }

         print join ("\t" , @tps) , "\n";

         
    

         

      }
 
   }

   print "\n";
} 

