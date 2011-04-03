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
use Skeddir;
use Myopts;

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

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

our (@signs, %signs);
FPread_simple ("Signs.csv" , \@signs , \%signs , 'SignID');
print STDERR scalar(@signs) , " signs.\n" unless $options{quiet};

my $last = (sort {$b <=> $a} keys %signs)[0];

for ( 1 .. $last ) {

   print "\t$_" unless $signs{$_};

}

print "\n\nLast: $last\n";
