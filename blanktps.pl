#!/usr/bin/perl

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

@ARGV = qw(-s f08) if $ENV{RUNNING_UNDER_AFFRUS};

use FPMerge qw(FPread FPread_simple);
use Skeddir;
use Myopts;
use Data::Dumper;

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
