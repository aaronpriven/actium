#!/usr/bin/perl
# vimcolor: #000030

# signslines
#
# This program lists the signs and what lines are associated with each one in Skedspec.pm


use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin



use Actium::FPMerge qw(FPread FPread_simple);
use IDTags;
use Skeddir;
use Skedvars;
use Skedtps qw(tphash tpxref);
use Actium::Sorting ('byline');
use Myopts;

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

$| = 1; # this shouldn't be necessary to a terminal, but apparently it is

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.



print "Using signup $signup\n\n" unless $options{quiet};

print <<"EOF" unless $options{quiet};
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@signs, @stops, @lines, @signtypes, @skedspec, @projects);
our (%signs, %stops, %lines, %signtypes, %skedspec, %projects);

our ($schooldayflag, $anysecondflag,$addminsflag);

print "Signs... " unless $options{quiet};
FPread_simple ("Signs.csv" , \@signs, \%signs, 'SignID');
print scalar(@signs) , " records.\nSkedspec... " unless $options{quiet};
FPread ("SkedSpec.csv" , \@skedspec, \%skedspec, 'SignID' , 1, 0);
# ignores repeating fields, but works with non-unique SignIDs
# BUG - rest of program will break if there are *not* non-unique SignIDs.
# Not a problem in real life, but may break simple test runs.
print scalar(@skedspec) , " records.\n\n" unless $options{quiet};

my %signlines = ();

my @signstodo;

if (@ARGV) {
   @signstodo = @ARGV;
} else {
   @signstodo = keys %signs;
}

SIGN:
foreach my $signid (sort {$a <=> $b} @signstodo) {

   next SIGN unless lc($signs{$signid}{Active}) ne "no" 
          and exists $skedspec{$signid};

   print "$signid\t" , $signs{$signid}{Status} , "\t";
   
   
   my %lines = ();
   foreach my $thisspec (@{$skedspec{$signid}}) {
      my @linesfromskedspec = split(/\n/ , $thisspec->{Lines});
      $lines{$_} = 1 foreach @linesfromskedspec;
   }

   print join (", " , sort byline keys %lines) , "\n";
 
     
}
   
