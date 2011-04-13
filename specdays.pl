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
use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signupdir = Actium::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

printq "notpnames - missing timepoint names \n\n" ;

printq "Using signup $signup\n";
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

my @files = grep ((! /=/) , glob('skeds/*.txt'));
# easier to use grep than try to construct a glob pattern that doesn't include 
# equals signs

my %alldays;

# slurp all the files into memory and build hashes
foreach my $file (@files) {
   my $sked = Skedread($file);
   foreach (@{$sked->{SPECDAYS}}) {
      $alldays{$_} = 1;
   }
}

print join ("\n" , keys %alldays);
