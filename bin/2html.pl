#!/usr/bin/perl

foreach (@ARGV) {
   push @files , glob($_);
}

foreach (@files) {
   next unless -f $_;
   system ("gvim -f -s u:/bin/batchhtml.vim $_");
   print "$_\n";
}
