#!/usr/bin/perl

@ARGV = qw(-s f08) if $ENV{RUNNING_UNDER_AFFRUS};

# gettps - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

#use List::Util;

use Actium;
use Actium::Constants;

# don't buffer terminal output
$| = 1;

my $helptext = "gettps - reads stored AVL data and makes timepoint files";

Actium::initialize($helptext, $helptext);                

# retrieve data

my %plc;

{

my $avldata_r = avldata();

%plc = %{$avldata_r->{PLC}}

}

my %tp4_of;

foreach my $tp4 (keys %plc) {
   next if $tp4 =~ /-[AD12]\z/;
   my $tp8 = $plc{$tp4}{Number};

   my $tp9 = make_tp9 ($tp8);   
   $tp4_of{ $tp9 } = $tp4;
}

$tp4_of{'HDAL MALL'} = 'HDMA';

open my $list , '>' , 'tplist.txt';

while ( my ($key, $value) = each %tp4_of) {
   print $list "$value\t$key\t";
   print $list $plc{$value}{Description} ;
   print $list "\n";
}

close $list;

print "Exiting.";

# tp9 -> tp4 conversion now handled in avl2skeds

#open my $in, '<' , 'timepointorder.txt';
#open my $out , '>' , 'tp4order.txt';
#
#while (<$in>) {
#   chomp;
#   my ($sked, @tp9s) = split (/\t/);
#   print $out "$sked\t";
#   my @newtp9s;
#   foreach my $tp9 (@tp9s) {
#      push @newtp9s, $tp4_of{$tp9} || $tp9;
#   }
#   print $out (join ("\t" , @newtp9s)) , "\n";
#
#}
#
#close $in;
#close $out;

sub make_tp9 {

   my $tp8 = shift;
   
   return $tp8 if length($tp8)<5;

   $tp8 =~ tr/,/./; # FileMaker doesn't like commas
   my $first  = substr($tp8, 0, 4);
   my $second = substr($tp8, 4);
   $first =~ s/\s+$//;
   $second =~ s/\s+$//;
   return "$first $second";

}


=head1 NAME

gettps - Get timepoints from the avl stored data.

=head1 DESCRIPTION

gettps reads the data written by readavl and extracts the timepoint
information.

=head1 AUTHOR

Aaron Priven

=cut

