#!/usr/bin/perl
# vimcolor: #000030

# linelist
#
# List lines in order by name
# 

use 5.010;

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Sorting (qw(sortbyline));
use Actium::FPMerge qw(FPread FPread_simple);
use Myopts;
use Skeddir;
use Columnprint(':all');

my %options;
Myopts::options (\%options, Skeddir::options(), '1' , 'quiet!');
# command line options in %options;

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

# open and load files

our (@idx, %idx);

FPread_simple ("Skedidx.csv" , \@idx, \%idx, 'SkedID');

my %seen;
foreach my $idx (@idx) {
   my @lines = split ("\c]" , $idx->{Lines});
   $seen{$_} = 1 foreach @lines;
}

my @lines = sortbyline keys %seen;

#say join("\n" , @lines);

if ($options{'1'}) {
   print join("\n" , @lines) , "\n";
} 
else {
   print Columnprint::columnprint({SCREENWIDTH => 80 , PADDING => 5} , @lines);
}
