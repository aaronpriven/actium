#!/usr/bin/perl

# this is NOT the mythical SD-shell.
# SDSH - school days, school holidays

@ARGV = "/Volumes/Bireme/ACTium/db/f08/headways/weekday.prt" 
   if $ENV{'RUNNING_UNDER_AFFRUS'};

use strict;
use warnings;

my %hash;

$/ = "\r\n";

my $divin_index;
my $offset;

while (<>) {
    chomp;
    
    next if length($_) > 9 and substr($_, 5, 3) =~ /6\d\d/;
    next if length($_) > 10 and substr($_, 6, 3) =~ /51S/;

    if (/DIV-IN/) {
       $divin_index = index($_, 'DIV-IN') -3 ;
       next;
    }
    
    next unless /^S[DH] /;
    
    my $times = substr($_, 0, $divin_index);
    my $exc = substr($times , 0, 2, '');
    substr($times, 10, (51-10) , '') ;
    # remove run number, block number, vehicle type,  
    # remove the initial SD or SH and return it in $exc
    
    my $allbutfirsttime = $times;
    substr($allbutfirsttime, 0, 19, '');
    
    next unless $allbutfirsttime =~ /\d/;
   
    #print;
    #print "\n";
    
    $hash{$exc}{$times} = $_;

}

foreach (sort keys %{$hash{SH}}) {
# sort is only there for debugging

   my $exists = exists($hash{SD}{$_});

   if (exists $hash{SD}{$_}) {

      delete $hash{SD}{$_};
      delete $hash{SH}{$_};

   }

}

#my %all = ( %{$hash{SD}} , %{$hash{SH}} );

#my %reverse = reverse %all;

#my @values = sort { notfirsttwo($a) cmp notfirsttwo($b) } keys %reverse; 

#foreach (@values) {
#   print "\n$reverse{$_}\n$_\n";
#}

print "\nSD:\n" , join ("\n" , sort values %{$hash{SD}}) , "\n";
print "\nSH:\n" , join ("\n" , sort values %{$hash{SH}}) , "\n";


#sub notfirsttwo {
#   return substr($_[0], 3 );
#}