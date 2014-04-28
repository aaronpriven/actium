#!/usr/bin/perl

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::O::Folders::Signup;
my $signupdir = Actium::O::Folders::Signup->new();
chdir $signupdir->path();
my $signup = $signupdir->signup;

# open and load files

printq "Using signup $signup\n\n";

printq <<"EOF" ;
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@signs, %signs);
FPread_simple ("Signs.csv" , \@signs , \%signs , 'SignID');
printq scalar(@signs) , " signs.\n" ;

my $last = (sort {$b <=> $a} keys %signs)[0];

for ( 1 .. $last ) {

   print "\t$_" unless $signs{$_};

}

print "\n\nLast: $last\n";
