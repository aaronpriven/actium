#!/usr/bin/perl

# all routes

# lists all linegroups and the routes in them

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
use Skeddir;
use Myopts;
use Actium::Sorting (qw(sortbyline));

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

our (%options);    # command line options

Myopts::options (\%options, Skeddir::options(), 'quiet!');
# command line options in %options;

$| = 1; # don't buffer terminal output; perl's not supposed to need this, but it does

my $signup;
$signup = (Skeddir::change (\%options))[2];
#print "Using signup $signup\n" unless $options{quiet};
# Takes the necessary options to change directories, plus 'quiet', and
# then changes directories to the "actium/db/xxxx" base directory.

my @files = grep ((! /=/) , glob('skeds/*.txt'));
# easier to use grep than try to construct a glob pattern that doesn't include 
# equals signs

my %routes;
my %linegroups;

# slurp all the files into memory and build hashes
foreach my $file (@files) {
   my $sked = Skedread($file);
   foreach (@{$sked->{ROUTES}}) {
      $routes{$sked->{LINEGROUP}}{$_} = 1;
      $linegroups{$_}{$sked->{LINEGROUP}} = 1;
   }
}

print "\tLinegroups\tRoutes\n\n";
foreach (sortbyline keys %routes) {
   print "\t$_\t" , 
         join(", " , sortbyline keys %{$routes{$_}}) ,  "\n";
}

print "\nRoutes\tLinegroups\n\n";
foreach (sortbyline keys %linegroups) {
   print "\t$_\t" , 
         join(", " , sortbyline keys %{$linegroups{$_}}) ,  "\n";
}
