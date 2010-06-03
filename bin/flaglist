#!/ActivePerl/bin/perl

use strict;
use 5.010;
use warnings;

use autodie;

use List::MoreUtils ('uniq');

open IN , '<' , "/Volumes/Bireme/Actium/db/sp10/phoneids.txt";

my %phoneid;
my %desc;
my %lines;
my %numlines;
my %numlinesdirs;
my %numlinescdirs;

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

   $lines{$stopid} = $lines;

   $numlines{$stopid} = shift @items;
   $numlinesdirs{$stopid} = shift @items;
   $numlinescdirs{$stopid} = shift @items;
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

   $lines{$_} =~ s/-[NSEW]B//g;
   $lines{$_} =~ s/-/_/g;

   my @uniqlines = (split (' ' , $lines{$_}));
   @uniqlines = uniq @uniqlines;
   $lines{$_} = "@uniqlines";

   my $city = substr($_,0,2);
   my $file;

   given ($_) {
       when  ($numlinescdirs{$_} > 10) { 
           $file = 'oversize';
       }
       when ($numlinescdirs{$_} > 5 ) {
           $file = 'big';
       }
       when ($numlinescdirs{$_} == 5 ) {
           $file = 'medium-five';
       }
       when ($numlinescdirs{$_} == 4 ) {
           $file = 'medium-four';
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
