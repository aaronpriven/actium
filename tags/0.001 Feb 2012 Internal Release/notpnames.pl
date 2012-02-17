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
use Skedvars qw(%daydirhash %adjectivedaynames %bound);
use Skedtps qw(TPXREF_FULL tpxref tphash);
use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;
my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->path();
my $signup = $signupdir->signup;

$| = 1; # don't buffer terminal output; perl's not supposed to need this, but it does

printq "notpnames - missing timepoint names \n\n" ;

printq "Using signup $signup\n" ;

printq "Timepoints and timepoint names... ";
my $vals = Skedtps::initialize(TPXREF_FULL);
printq "$vals timepoints.\n";

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
