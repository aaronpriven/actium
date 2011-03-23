#!/usr/bin/perl

$signup1 = "f05";
$signup2 = "w05";

$dir1 = $ENV{SKEDSDIR} . "/db/$signup1/skeds/";
$dir2 = $ENV{SKEDSDIR} . "/db/$signup2/skeds/";

$_ = $ARGV[0];

s/\.txt$//;
$_ .= ".txt";

$f1 = "/tmp/$signup1-$_";
$f2 = "/tmp/$signup2-$_";

system "cp $dir1/$_ $f1";
system "cp $dir2/$_ $f2";
exec "open -a 'Microsoft Excel' $f1 $f2";
