#!/usr/bin/perl

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::FPMerge qw(FPread FPread_simple);
use Actium::Sorting (qw(sortbyline));

use Actium::Options (qw<option add_option>);
use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

# $| = 1; # makes output "hot"

# open and load files

printq STDERR "Using signup $signup->get_signup\n\n";

printq STDERR <<"EOF";
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
