#!/usr/bin/perl
# prints the number needed to get a specific letter name in an Indesign page
$a = "a";
for (1 .. 90000) {
  $hash{$a++} = $_;
}

print $hash{$ARGV[0]} , "\n";
