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

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;
my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;


use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);
use IDTags;
use Skedvars;
use Skedtps qw(tphash tpxref);
use Actium::Sorting::Line ('byline');

$| = 1; # this shouldn't be necessary to a terminal, but apparently it is

printq "Using signup $signup\n\n" ;

printq <<"EOF" ;
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@signs, @stops, @lines, @signtypes, @skedspec, @projects);
our (%signs, %stops, %lines, %signtypes, %skedspec, %projects);

our ($schooldayflag, $anysecondflag,$addminsflag);

printq "Signs... ";
FPread_simple ("Signs.csv" , \@signs, \%signs, 'SignID');
printq scalar(@signs) , " records.\nSkedspec... " ;
FPread ("SkedSpec.csv" , \@skedspec, \%skedspec, 'SignID' , 1, 0);
# ignores repeating fields, but works with non-unique SignIDs
# BUG - rest of program will break if there are *not* non-unique SignIDs.
# Not a problem in real life, but may break simple test runs.
printq scalar(@skedspec) , " records.\n\n" ;

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
   
