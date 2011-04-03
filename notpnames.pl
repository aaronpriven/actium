#!/usr/bin/perl

# notpnames

# searches for missing timepoint names

use strict;

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin


use Skedfile qw(Skedread Skedwrite remove_blank_columns);
use Skeddir;
use Skedvars qw(%daydirhash %adjectivedaynames %bound);
use Skedtps qw(TPXREF_FULL tpxref tphash);
use Myopts;
use Actium::FPMerge qw(FPread FPread_simple);

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

our (%options);    # command line options

Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

$| = 1; # don't buffer terminal output; perl's not supposed to need this, but it does

print "notpnames - missing timepoint names \n\n" unless $options{quiet};

my $signup;
$signup = (Skeddir::change (\%options))[2];
print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

print "Timepoints and timepoint names... " unless $options{quiet};
my $vals = Skedtps::initialize(TPXREF_FULL);
print "$vals timepoints.\n";

my @files = grep ((! /=/) , glob('skeds/*.txt'));
# easier to use grep than try to construct a glob pattern that doesn't include 
# equals signs

my %alltps;

# slurp all the files into memory and build hashes
foreach my $file (@files) {
   my $sked = Skedread($file);
   foreach (@{$sked->{TP}}) {
      $alltps{$_} = 1;
   }
}

foreach (sort keys %alltps) {
   # print "$_:" , tphash($_) , "\n";
   print "$_:\n" unless tphash($_);
}
