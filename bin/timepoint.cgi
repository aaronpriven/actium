#!/usr/bin/perl5

require ('/home/priven/public_html/cgi-lib.pl');

&ReadParse;

# get data from form

$_ = $in{"direction"};

($linenum, $dirname, $direction) = split (":",$_,3);


$infile = 
   'lynx -source "http://www.transitinfo.org/cgi-bin/'
   . $direction . '" |';


open IN, $infile;

do {

   $_ = <IN>;
} until /<pre>/;

# skip everything until "Key to timepoints"

$_ = <IN>;

until (m@timepoints@) {

# keep reading data until the close of the <pre>

   if (/<hr>/)
   
   # hr signals a block of repeated timepoint info, which we don't
   # need

   {
       $_ = <IN>;
       $_ = <IN>;
       next;
   }

   chomp;

   push @sched, $_ if ($_ and not /only/i);
   # add it to the array, unless it's blank or is "School Days Only"
   # or "School Holidays Only" or something

   $_ = <IN>;

}

# @sched is now schedule

$_ = <IN>;

until (m@</pre>@) {

   chomp;
   push @timepoints, $_;
   $_ = <IN>;

}

close IN;

# @timepoints is now the list of timepoints

$offset = 0;
$firstlinecode = substr($sched[0],1,3);

if ($firstlinecode eq "   ") {

   $firstlinecode = substr($sched[0],4,3);
   $offset = 3;

}

$totallines = 0;

if ($firstlinecode eq "RTE") {

   foreach (@sched) {
      $thisline = substr($_,1+$offset,3);
      $thisline =~ s/\s//g;
      $lines{$thisline} += 1;

   }

   $offset += 5;

   delete $lines{"RTE"};
   delete $lines{"NUM"};

   @lines =  sort { $lines{$b} <=> $lines{$a} } keys(%lines);

# that puts the lines in number order -- if there are lots of 6s and a
# few 6As, the order will be 6, 6A

   $totallines = $#lines;

   $alllines = join (":",@lines);
   
}



print "Content-type: text/html\n\n";

print <<EOF;
<title>VBS: Select timepoint and lines</title>
<h1>VBS: Line $linenum, $dirname</h1>

<form action="vbs.cgi" method="POST">

<input type=hidden name=linenum value="$linenum">
<input type=hidden name=offset value="$offset">
<input type=hidden name=direction value="$direction">
<input type=hidden name=alllines value="$alllines">
<input type=hidden name=totallines value="$totallines">
<input type=hidden name=dirname value="$dirname">

EOF

if ($firstlinecode eq "RTE") {
   print "<h2>Lines</h2>\n";

   foreach (sort @lines) {
   
   print "<p><INPUT TYPE=checkbox NAME=checkline VALUE=$_>Line $_</p>\n";

   }

}

print "<h2>Timepoint</h2>\n";

$count = 0;

foreach (@timepoints) {

   $count++;
   $code = substr($_,0,10);
   push @codes, $code;
   $_ = substr($_,10);

   print <<"EOF";

<p>
<INPUT TYPE=radio VALUE="$count" name=pickedpoint>
$count. <tt>$code</tt><br>$_
</p>
EOF

}

print <<EOF;

<INPUT TYPE=submit VALUE="Get Schedule for Timepoint">


</form>
<br>&nbsp;<br>
<p>Here's the whole schedule if it helps:</p>
<pre>

EOF


print join "\n", @sched;
print "\n</pre>";

mkdir "/tmp/priven-vbs", 0777 unless -d "/tmp/priven-vbs";

open TEMPFILE, ">/tmp/priven-vbs/$direction";

print TEMPFILE $#codes , "\n";

foreach (0 .. $#codes) {

   print TEMPFILE $codes[$_] , "\0" , $timepoints[$_] , "\n";

}

print TEMPFILE join "\n", @sched;

close TEMPFILE;

chmod 0644, "/tmp/priven-vbs/$direction";
chmod 0755, "/tmp/priven-vbs";
