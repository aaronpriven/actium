#!/usr/bin/perl

$dir = shift(@ARGV);

if ($dir) {

   $dir =~ s#/$##;
   @files = glob("$dir/*");

} else {
   @files = glob("*");
}

die "index exists" if -e "index.htm";

open IN , ">index.htm" or die "can't open index";

select IN;

print "<table>";

foreach (@files) {
   
    ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
       $atime,$mtime,$ctime,$blksize,$blocks)
           = stat();

    $time = localtime($mtime);

    print qq|<tr><td><a href="$_">$_</td><td>$time</td><td align=right>$size</td></tr>\n|;

}

print "</table>";
