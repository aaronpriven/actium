#!/usr/bin/perl

use strict;

# initialization

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory

# libraries dependent on $Bin

use Actium::FPMerge qw(FPread FPread_simple);
use Actium::Sorting (qw(sortbyline));

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Signup;
my $signupdir = Actium::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

# open and load files

printq STDERR "Using signup $signup\n\n";

printq STDERR <<"EOF" ;
Now loading data...
EOF

# read in FileMaker Pro data into variables in package main

our (@stops, %stops);

FPread_simple ("Stops.csv" , \@stops , \%stops , 'stop_id_1');

print STDERR scalar(@stops) , " stops.\n";

# fields - stop_id_1,STOPROUTES,UNSHOWNROU,ERRSHOWNRO,POLENUM,SHELTR,TIMEPOINT,SignID,MyNeighborhood,MyPoleType,MyDescription,CityF,OnF,AtF,StNumF,CommentF,CornerF,SiteF,DirectionF,NotesForR_P

my %lines_of;
my %cities_of;

foreach my $stop (@stops) {

   next if $stop->{In_last_update} =~ /no/i;

   my @routes = split(' ' , $stop->{ud_stp_FlagRoute});
   foreach (@routes) {

      next if /NULL/;
      my $city = $stop->{CityF};
      $city =~ s/^\s+//;
      $city =~ s/\s+$//;
      $lines_of{$city}{$_}++;
      $cities_of{$_}{$city}++;
   }
}

my @cities = sort keys %lines_of;

my @lines = sortbyline keys %cities_of;

#foreach my $city (@cities) {

#   print "$city: ";
#   print join ( ", " , sort byroutes keys (%{$lines_of{$city}} ) );
#   print "\n";
#
#}

# build matrix

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


