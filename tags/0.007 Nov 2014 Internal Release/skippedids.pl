#!/ActivePerl/bin/perl

use strict;

our $VERSION = 0.005;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::Options (qw<option init_options add_option>);
use Actium::Files::FileMaker_ODBC (qw[load_tables]);

init_options();

# open and load files

# read in FileMaker Pro data into variables in package main

my %signs;

load_tables(
    requests => {
        Signs => { hash => \%signs, index_field => 'SignID',
           fields => [qw[
           SignID stp_511_id 
           ]], 
             },
        },
);

my $last = (sort {$b <=> $a} keys %signs)[0];

print "Skipped signs:";

for ( 1 .. $last ) {

   print "\t$_" unless $signs{$_};

}

print "\n\nLast: $last\n";
