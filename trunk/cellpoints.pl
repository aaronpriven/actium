#!/usr/bin/perl

# cellpoints

# Makes text versions of the skeds in /skeds into /cellpoints, 
# in order to copy to cell phones

use strict;

@ARGV = qw (-s sp07);

####################################################################
#  load libraries
####################################################################

use fatal(qw(open close mkdir));

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

# TODO - does not put route down in multi-route lines (e.g., 72/72M)

use Skedfile qw(Skedread getfiles GETFILES_PUBLIC_AND_DB trim_sked copy_sked);
use Skedvars qw(%daydirhash %adjectivedaynames %bound %specdaynames);
use Skedtps qw(tphash TPXREF_FULL);

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

use Actium::Options (qw<option add_option>);
use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

$| = 1; # don't buffer terminal output

sayq "cellpoints - create a set of text point schedules\n";

sayq "Using signup $signup->get_signup";

# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

open DATE , "<effectivedate.txt" 
      or die "Can't open effectivedate.txt for input: $!";
our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;

our (@lines , %lines);

printq "Timepoints and timepoint names... ";
my $vals = Skedtps::initialize(TPXREF_FULL);
printq "$vals timepoints.\n" ;

mkdir "cellpoints" unless -d "cellpoints";

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

foreach my $file (@files) {
   my $sked = Skedread($file);
   my $skedname = $sked->{SKEDNAME};

   my $line = $sked->{LINEGROUP};
   mkdir "cellpoints/$line" unless -d "cellpoints/$line";

   trim_sked($sked);

   printq "$skedname\t";

   for my $tpnum (0 .. $#{$sked->{TP}}) {
   
      my $tp = $sked->{TP}[$tpnum];
      my $filename = "cellpoints/$line/$skedname $tpnum $tp.txt";
      open OUT, ">" , $filename;
      print OUT "$skedname $tp \n";
      my @times = ();
      foreach my $time (@{$sked->{TIMES}[$tpnum]}) {
         push @times, $time if $time;
      }
      print OUT join (" " , @times) , "\n";
   }
   
   close OUT;

}

printq "\n\n";

