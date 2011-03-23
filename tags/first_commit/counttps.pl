#!/usr/bin/perl
# 

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skedfile qw(Skedread);
use Skeddir;
use Skedvars;
use FPMerge qw(FPread FPread_simple);
use Myopts;

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

my @files = glob ("skeds/*.txt");

foreach my $file (@files) {

   my $dataref = Skedread ($file);

   print scalar(@{$dataref->{TP}}) , " : " ;
   print $dataref->{SKEDNAME} , "\n" ;

}

