#!perl

$num = shift @ARGV or 16;

$count = 0;

foreach (1..$num) {

$count += $_;

}

print $count , "\n";

