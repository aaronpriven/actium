#!/usr/bin/env perl

use 5.020;
use strict;
use autodie;
use feature 'postderef';

open my $in, '<' , 'blocks_and_dates.txt' ;

my %dates_of_block;

my @currentblocks;
my %allblocks;
my %alldates;

use DateTime;

while (<$in>) {
   chomp;
   next unless $_;
   if (/BLOCK/) {
       (undef, @currentblocks) = split;
        for my $block (@currentblocks) {
           $allblocks{$block} = 1;
        }

   }
   else {

      s/\s+//;
      my ($month, $day, $year) = split m#/#, $_;
      $year += 2000 if $year < 100;

      my $dt = DateTime->new(year => $year, month => $month, day => $day);
      my $ymd = $dt->ymd('-');
      $alldates{$ymd} = 1;

      for my $block (@currentblocks) {
         $dates_of_block{$block}{$ymd} = 1;
      }

  }
}

use DateTime;
use DateTime::Duration;

my %wday_of;
my %string_of;

my $dt = DateTime->new(year => 2016, month => 12, day => 19);
my $ymd = $dt->ymd('-');

do {

   my $month = $dt->month;
   my $day = $dt->day;
   my $year = $dt->year;
   my $wday = $dt->day_abbr;

   if ($wday ne 'Sat' and $wday ne 'Sun') {
      $alldates{$ymd} = 1;
      $wday = 'Thurs' if $wday eq 'Thu';
      $wday = 'Tues' if $wday eq 'Tue';
      $wday_of{$ymd} = $wday;
      $string_of{$ymd} = $dt->day . "-" . $dt->month_abbr;
   }

   $dt->add(days => 1);  
   $ymd = $dt->ymd('-');

} until $ymd eq '2017-06-19';

my @alldates = sort keys %alldates ;

# dates
say join("\t" , qw/New New C D E F/ , @string_of{@alldates});
say join("\t" , qw/Block Frag School PULL_OUT PULL_IN Dist./ , @wday_of{@alldates});
say join("\t" , qw/A Run C TIME TIME F/ , (("0") x scalar @alldates)) ;

for my $block (keys %allblocks) {

   print join("\t" , $block, qw/B C D E F/ );

   for my $date (@alldates) {
       if ( exists $dates_of_block{$block}{$date} ) {
           print "\t-ON-";
       } else {
           print "\t-off-";
       }
   }

   print "\n";

}



