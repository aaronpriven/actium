#!/usr/bin/perl

# allroutes.pl

# legacy status 1

# lists all linegroups and the routes in them, deriving this from the
# skeds files.

use strict;

our $VERSION = 0.002;

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
use Actium::Sorting::Line (qw(sortbyline));

######################################################################
# initialize variables, command options, change to Skeds directory
######################################################################

use Actium::Options;
use Actium::O::Folders::Signup;
my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

$| = 1; # don't buffer terminal output; perl's not supposed to need this, but it does

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
