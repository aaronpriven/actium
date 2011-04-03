#!/usr/bin/perl
# vimcolor: #000030

# linelist
#
# List lines in order by name
# 

use strict;
use warnings;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

chdir "$Bin/.." ;

# libraries dependent on $Bin

use Actium::FPMerge qw(FPread FPread_simple);
use Myopts;
use Skeddir;

my %options;
Myopts::options (\%options, "basedir=s","firstdir=s","seconddir=s", 'quiet!');
# command line options in %options;

chdir ( $options{basedir} or "$Bin/.." ) ;

# open and load files

our (@first, %first, %filelist , @second, %second );

$filelist{$_} = 1 
    foreach qw(Rich.pdf Oak.pdf Hayw.pdf Frem.pdf line-map-legend-jun04.pdf);

FPread_simple ("db/" . $options{firstdir} . "/Lines.csv" , \@first, \%first, 'Line');

foreach (@first) {
   $filelist{$_->{MapFileName}} = 1 if $_->{MapFileName};
}

if ($options{seconddir} ) {
   FPread_simple 
      ("db/" . $options{seconddir} . "/Lines.csv" , \@second, \%second, 'Line');
   foreach (@second) {
      $filelist{$_->{MapFileName}} = 1 if $_->{MapFileName};
   }
}

my @files = glob('/Users/Shared/actium/schedulemaps/*');
map (s#.*/## ,@files);

foreach (@files) {
   print "$_\n" unless $filelist{$_};
}

print "---\n";
my %files;

$files{$_} = 1 foreach @files;

foreach (sort keys %filelist) {
   print "$_\n" unless $files{$_};
}
