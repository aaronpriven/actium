#!/usr/bin/perl

# This simple script allows two files of the same name to be opened up in Excel
# since Excel doesn't like to have two files of the same name opened at the
# same time.

# Legacy stage 1

$signup1 = "f12";
$signup2 = "w12";

$dir1 = $ENV{SKEDSDIR} . "/db/$signup1/rawskeds/";
$dir2 = $ENV{SKEDSDIR} . "/db/$signup2/rawskeds/";

$_ = $ARGV[0];

s/\.txt$//;
$_ .= ".txt";

$f1 = "/tmp/$signup1-$_";
$f2 = "/tmp/$signup2-$_";

system "cp $dir1/$_ $f1";
system "cp $dir2/$_ $f2";
exec "open -a 'Microsoft Excel' $f1 $f2";
