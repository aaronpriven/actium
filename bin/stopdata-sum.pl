#!perl

# stopdata-sum.pl

#use Win32::GUI;
#use Win32;

use strict;
no strict 'subs';

require 'pubinflib.pl';

use constant ProgramTitle => "AC Transit Stop Signage Database - Stop Summary";

chdir get_directory() or die "Can't change to specified directory.\n";

open OUT, ">stop-sum.txt" or die "Can't open outfile";

select OUT;

shift @ARGV;

open STOPDATA, "stopdata.txt" or die "Can't open stop data file for reading";

$/ = "\n---\n";

while ($_ = <STOPDATA>) {

   chomp;
   my ($stopid, @pickedtps) = split (/\n/);

   next unless $stopid;

   $stopid =~ s/\t.*//;
   # remove everything after first tab

   my %routes = ();

   foreach (@pickedtps) {

      my @items = split (/\t/);
      @items = @items[3 .. $#items];
      $routes{$_} = 1 foreach @items;

   }

   print "$stopid - " , join (" " , sort {$a <=> $b or $a cmp $b} keys %routes ) , "\n"

}
