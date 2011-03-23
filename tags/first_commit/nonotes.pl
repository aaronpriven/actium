#!/usr/bin/perl
# 
# nonotes - make copy of /skeds without notes

@ARGV = qw(-s w07) if $ENV{RUNNING_UNDER_AFFRUS};

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Skeddir;
use Myopts;

my %options;
Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

my $signup;
$signup = (Skeddir::change (\%options))[2];
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "Skeds" base directory.

my @files = glob ("skeds/*.txt");

mkdir "nonotes-skeds" or die "Can't create skeds-nonotes directory: $!"
   unless -d "nonotes-skeds";

foreach my $file (@files) {

   open IN , '<' , $file;
   open OUT , '>' , "nonotes-$file";

   $_ = <IN>;
   s/\t+$//;
   print OUT $_;
   $_ = <IN>;
   s/\t+$//;
   print OUT $_;
   # skip first two lines
   
   while (<IN>) {
      s/\t+$//;
      my @cols = split (/\t/);
      splice (@cols, 1, 1);
      print OUT join("\t" , @cols);
   }
   
   close IN;
   close OUT;

}

