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
use Myopts;
use Skeddir;
use Skedvars qw(%daydirhash %adjectivedaynames %bound %specdaynames);
use Skedtps qw(tphash TPXREF_FULL);

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

my %options;

Myopts::options (\%options, Skeddir::options(), 'quiet!' );
# command line options in %options;

$| = 1; # don't buffer terminal output

print "cellpoints - create a set of text point schedules\n\n" unless $options{quiet};

my $signup;
$signup = (Skeddir::change (\%options))[2];
print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

open DATE , "<effectivedate.txt" 
      or die "Can't open effectivedate.txt for input: $!";
our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;

our (@lines , %lines);

print "Timepoints and timepoint names... " unless $options{quiet};
my $vals = Skedtps::initialize(TPXREF_FULL);
print "$vals timepoints.\n" unless $options{quiet};

mkdir "cellpoints" unless -d "cellpoints";

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

foreach my $file (@files) {
   my $sked = Skedread($file);
   my $skedname = $sked->{SKEDNAME};

   my $line = $sked->{LINEGROUP};
   mkdir "cellpoints/$line" unless -d "cellpoints/$line";

   trim_sked($sked);

   print "$skedname\t" unless $options{quiet};

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

print "\n\n" unless $options{quiet};

