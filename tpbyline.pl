#!/usr/bin/perl

# legacy status: 1

# This obviously produces a cross-tabulation of line groups and
# timepoints. I don't remember why I wanted this... or why I wanted
# it in HTML...

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);
use Actium::Sorting::Line 'byline';
use Data::Dumper;

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signupdir = Actium::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

# open and load files

printq "Using signup $signup\n\n" ;

printq <<"EOF" ;
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@timepoints, %timepoints , @skedidx);

FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');
FPread('Skedidx.csv' , \@skedidx );

our (%tp9s , %linegroups, %lines);

foreach my $skedidx (@skedidx) {
   my $linegroup = $skedidx->{Timetable};
   next if $linegroup =~ m/^I/;
   #my $linegroup = join("/" , @{$skedidx->{Lines}});

   $linegroup = (sort byline @{$skedidx->{Lines}})[0] if $linegroup > 99 and $linegroup < 200;

   $lines{$linegroup}{$_} = 1 for (@{$skedidx->{Lines}});

   foreach my $tp9 (@{$skedidx->{'TP9s_NoEquals'}}) {
      
      $linegroups{$linegroup}{$tp9} = 1;
      $tp9s{$tp9}{$linegroup} = 1;

   }

}

open HTML , ">line-tp-xref.html" or die "Can't open line-tp-xref.html: $!";

select HTML;

print <<"EOF";
<html>
<head><title>Line Groups and Timepoint Cross-Reference</title></head>
<body><h1>Line Groups and Timepoint Cross-Reference</title></h1>
<hr>
<ul>
<li><a href="#tp">Timepoints by Line Group</a>
<li><a href="#lg">Line Groups by Timepoint</a>
</ul>
<hr>
<h2><a name="tp">Timepoints by Line Groups</a></h2>
<dl>
EOF

my %linegrouptext;

foreach my $linegroup (sort byline keys %linegroups) {

   my $linegrouptext = $linegroup;
   my @lines = sort byline keys %{$lines{$linegroup}};
   $linegrouptext .= " (" . join ("/" , @lines) . ")" if scalar @lines > 1;

   print "<dt>$linegrouptext";
   $linegrouptext{$linegroup} = $linegrouptext;
   my @tps = ();
   for (sort keys %{$linegroups{$linegroup}}) {;
       my $tp = ("$_: " . $timepoints{$_}{TPName}) ;
       $tp .= ", " . $timepoints{$_}{City} if $timepoints{$_}{City};
       push @tps, $tp;

   }

   print "\n<dd>" , join ("<br>" , @tps) , "\n";
}

print qq(</dl>\n<h2><a name="lg">Line Groups by Timepoint</a></h2>\n<dl>\n);

foreach my $tp9 (sort keys %tp9s) {
   print "<dt>$tp9: " , $timepoints{$tp9}{TPName} ;
   print ", " . $timepoints{$tp9}{City} if $timepoints{$tp9}{City};

   print "\n";
   my @thesetexts = ();
   push @thesetexts , $linegrouptext{$_} 
        for (sort byline keys %{$tp9s{$tp9}});
   print "<dd>" , 
      join (", " , @thesetexts) , "\n";
}

print "</dl>\n</body></html>";

close HTML;
