#!/usr/bin/perl
# vimcolor: #000030

# linelist
#
# List lines in order by name
# 

use 5.010;

use strict;
use warnings;

package Linelist;

use Actium::FPMerge qw(FPread FPread_simple);

use Exporter qw/import/;
our @EXPORT_OK = qw/linelist/;
our %EXPORT_TAGS = ( all => \@EXPORT_OK );

sub linelist {

   my (%idx, @idx);


   if (@_) {
      @idx = @_;
   } 
   else {
      FPread_simple ("Skedidx.csv" , \@idx, \%idx, 'SkedID');
   }

   my %seen;
   foreach my $idx (@idx) {
      my @lines = split ("\c]" , $idx->{Lines});
      $seen{$_} = 1 foreach @lines;
   }

   return keys %seen;

}
