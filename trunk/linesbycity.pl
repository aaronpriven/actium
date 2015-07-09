#!/ActivePerl/bin/perl

use strict;

# initialization

our $VERSION = 0.010;

use FindBin('$Bin');  ### DEP ###
   # so $Bin is the location of the very file we're in now

use lib ($Bin);  ### DEP ###
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

use Actium::Files::FileMaker_ODBC (qw[load_tables]);

use Actium::Sorting::Line (qw(sortbyline));

use Actium::Options (qw<option add_option init_options>);
use Actium::O::Folders::Signup;

init_options();

#my $signupdir = Actium::O::Folders::Signup->new();
#chdir $signupdir->path();
#my $signup = $signupdir->signup;

# open and load files

# read in FileMaker Pro data into variables in package main

our ( @stops);

load_tables(
    requests => {
        Stops_Neue => {
            array => \@stops,
            fields => [qw[
            h_stp_511_id p_active p_lines c_city
            ]],
        },
    }
);

my %lines_of;
my %cities_of;

foreach my $stop (@stops) {

   next unless $stop->{p_active};

   my @routes = split(' ' , $stop->{p_lines});
   foreach (@routes) {

      next if /NULL/;
      my $city = $stop->{c_city};
      $city =~ s/^\s+//;
      $city =~ s/\s+$//;
      $lines_of{$city}{$_}++;
      $cities_of{$_}{$city}++;
   }
}

my @cities = sort keys %lines_of;

my @lines = sortbyline keys %cities_of;

foreach my $line (@lines) {
   print "\t$line";
}
print "\n";

foreach my $city (@cities) {
   print "$city:";
   foreach my $line (@lines) {
      my $x = $lines_of{$city}{$line} ? 'X' : '';
      print "\t$x";
   }

   print "\n";

}


