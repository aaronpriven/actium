#!/usr/bin/perl

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use FPMerge qw(FPread FPread_simple);
use Skeddir;
use Actium::Sorting (qw(sortbyline));
use Myopts;

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

# $| = 1; # makes output "hot"

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

# open and load files

print STDERR "Using signup $signup\n\n" unless $options{quiet};

print STDERR <<"EOF" unless $options{quiet};
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@lines, %lines);

FPread_simple ("Lines.csv" , \@lines , \%lines , 'Line');

# fields - Line, Name, Color

my %nameless;

print STDERR scalar(@lines) , " lines.\n";

open IN, "linesbycity";

while (<IN>) {

   my $city;
   ($city, $_) = split (/:/);
   my $cityfile = $city;
   $cityfile =~ s/ /_/g;
   open OUT , ">bycity/$cityfile.html";

   s/\s+//g;
   my @theselines = split (/,/);
   print OUT "<h2>Lines in $city</h2>\n";
   print OUT qq(<form ACTION="http://hoohoo.ncsa.uiuc.edu/htbin-post/post-query" METHOD=POST>\n<blockquote>\n);

   foreach (@theselines) {
      next if /6\d\d/;
      if (exists $lines{$_}{Name}) {
#         print OUT "   $_ " , $lines{$_}{Name} , "\n";
      } else {
#         print OUT "   $_\n";
         $nameless{$_} = 1;
      }
      print OUT "<p>" , button($_) , "</p>";
      print OUT "\n";
   }
   print OUT qq(</blockquote>\n<input type=submit value="Submit!">);
   close OUT;
}

print "\nNameless: " , join (", " , sortbyline keys %nameless) , "\n";

sub button {

   local ($_) = shift;

   my $name = "";
   if (exists $lines{$_}{Name}) {
      $name = $lines{$_}{Name};
   }

   return qq(<input type=checkbox name="$_"> $_ $name);

}
