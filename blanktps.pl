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
use Data::Dumper;

use Actium::Options (qw<option add_option>);
use Actium::Term;
use Actium::O::Folders::Signup;
my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

# open and load files

print STDERR "Using signup $signup\n\n" unless option('quiet');

print STDERR <<"EOF" unless option('quiet');
Now loading data...
EOF

our (@timepoints, %timepoints , @skedidx);

FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');
FPread('Skedidx.csv' , \@skedidx );

our (%tp9s , %found);

foreach my $skedidx (@skedidx) {

   my @tpnames = @{$skedidx->{TPNames}};
   my @tp9s = @{$skedidx->{"TP9s_NoEquals"}};
   
   for (0..$#tp9s) {
 
      #print $tp9s[$_] , "\n" unless $tpnames[$_];
      $found{$tp9s[$_]} = 1 unless $tpnames[$_];

   }

}

print "\n---\n" , join("\n" , sort keys %found ) , "\n";
