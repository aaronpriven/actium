#!/ActivePerl/bin/perl

use 5.014;
use warnings;

use File::Slurp;

my $file = $ARGV[0];

my $html = read_file ($file);

my $version = '20';

my $url = 
   "http://www.actransit.org/maps/schedule_results.php?version_id=$version&quick_line=";
   
$html =~ s/\s+/ /g; #no newlines

$html =~ s{.*?</head>}{}is;
$html =~ s{</?(div|span|body).*?>}{}igs;
$html =~ s/<(em|i|b)\s+.*?>/<$1>/igs;
$html =~ s/<(table|td|p|tr)\s+.*?>/<$1>/igs;
$html =~ s{<p>&nbsp;</p>\s+}{}gs;
$html =~ s{<td>\s*<p>}{<td>}gs;
$html =~ s{</p>\s*</td>}{</td>}gs;
#$html =~ s{</?(p|div|span|body).*?>}{}igs;

my $behind = qr{
     (?<![A-Za-z0-9:])
     (?<!January\s)
     (?<!February\s)
     (?<!March\s)
     (?<!April\s)
     (?<!May\s)
     (?<!June\s)
     (?<!July\s)
     (?<!August\s)
     (?<!September\s)
     (?<!October\s)
     (?<!November\s)
     (?<!December\s)
}x;  # not a letter or digit or colon, or month

my $ahead = qr{ (?! (?: , \s+ 201\d | [A-Za-z0-9] | : | \s+Loop) ) }x;
# not either ", 201x", where x is a digit and space is any space character, or
# a letter or digit, or a colon, or "Loop" (for A Loop / B Loop )

$html =~ s{$behind
          (
             \d{1,2}[A-Z]? |
             2\d\d         |
             3\d\d         |
             60[1-9]       |
             6[1-9]\d      |
             A[ABD-Z]\d?   |  # skip "AC"
             [B-Z][A-Z]\d? |
             [B-Z]         
          ) 
          $ahead
          }
         
         
          {<a href="$url$1">$1</a>}gx;
          
$html =~ s/<table.*?>/<table border="1" cellspacing="0" cellpadding="6">/igs;

$html =~ s#(</(?:table|td|p|tr)>\s+)#$1\n#igs;

print $html;