#!/ActivePerl/bin/perl

use strict;
use 5.010;
use warnings;

use autodie;

open IN , '<' , "/Volumes/Bireme/Actium/db/sp10/phoneids.txt";

my %phoneid;
my %desc;
my %lines;
my %numlines;

while (<IN>) {

   chomp;
   my @items = split (/\t/);

   my $stopid = shift @items;
 
   $phoneid{$stopid} = shift @items;
   $desc{$stopid} = shift @items;

}

close IN;

open IN , '<' , "/Volumes/Bireme/Actium/db/sp10/stoplines.txt";

$_ = <IN>; # skip header line

while (<IN>) {
   chomp;
   my @items = split (/\t/);
   my $stopid = shift @items;

   my $lines = shift @items;

   next if $lines =~ /1R/;
   next if $lines =~ /72R/;

   $lines{$stopid} = shift @items;
   $numlines{$stopid} = shift @items;
}

close IN;

#my @list = reverse sort { $numlines{$a} <=> $numlines{$b} or 
#               $a cmp $b } keys %lines;

my @list = sort keys %lines;

use FileCache;

my $pathprefix = "/Volumes/Bireme/Actium/db/sp10/flaglist/";

my %is_smallcity;
$is_smallcity{$_} = 1 foreach qw(04 12 18 19 21 23 24 25 26 97);

foreach (@list) {
   my $city = substr($_,0,2);
   my $file;

   given ($_) {
       when  ($numlines{$_} > 10) { 
           $file = 'oversize';
       }
       when ($numlines{$_} > 5 ) {
           $file = 'big';
       }
       when ($numlines{$_} > 3 ) {
           $file = 'medium';
       }
       when ( not (not ($is_smallcity{$city})) ) {
           # the double "not" forces the value to be a boolean, so it
           # doesn't smart-match against $_
           $file = 'small-smallcity';
       }
       default {
           $file = "small-$city";
       }
   }

   $file = $pathprefix . $file;

   no strict 'refs';

   cacheout $file;

   print $file "$_\t$phoneid{$_}\t$numlines{$_}\t$desc{$_}\t$lines{$_}\n";

}
