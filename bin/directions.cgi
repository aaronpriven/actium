#!/usr/bin/perl5

require ('/home/priven/public_html/cgi-lib.pl');

&ReadParse;

# get data from form

$linenum = $in{"line"};

$agency = $in{"agency"};

$agency="AC" unless $agency;

$infile = 
    'lynx -source "http://www.transitinfo.org/cgi-bin/sched?C='
    . $agency . '&R=' . $linenum . '&E=New" |';

open IN, $infile;

# so that gets the schedule marker

while (<IN>) {

   push @scheds, $_ if /href=\"sched?.*DR=/

}

foreach (@scheds) {

   chomp;
   s/.*?href="//;
   ($url, $_) = split ('"',$_,2);
   
   s@^>@@;

   s@</a>$@@;

   $url{$_} = $url;

}

print <<EOF;
Content-type: text/html

<title>VBS: Which Direction?</title>
<h1>Which Direction on line $linenum?</h1>

<form action="timepoint.cgi" method="POST">

EOF

foreach (sort keys %url) {


   print <<"EOF";
  
<p>   
<INPUT name=direction type=radio value="$linenum:$_:$url{$_}"> 
$_</p>

EOF

}


print '<INPUT TYPE=SUBMIT VALUE="Select Timepoint"></form>';
