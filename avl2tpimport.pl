#!/usr/bin/perl

# avl2tpimport - see POD documentation below

# legacy status 2

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Carp;

#use Fatal qw(open close);
use Storable();

use Actium::Util(qw[jt]);
use Actium::Constants;
use Actium::Union('ordered_union');
use List::MoreUtils('uniq');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2tpimort reads the data written by readavl.
It then outputs a list of timepoints suitable for import to FileMaker.
EOF

my $intro = 'avl2tpimport -- Timepoints for FileMaker';

use Actium::Options;
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

my ( %plc );

{    # scoping
        # the reason to do this is to release the %avldata structure, so Affrus
        # (or, presumably, another IDE)
     # doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');


    %plc = %{ $avldata_r->{PLC} };

}

my %seen;

open my $out , '>' , 'tpimport.txt'
   or die "$!";

print $out "Abbrev4\tAbbrev9\tTPNameFromScheduling\tCityCode\n";


my %abbrev9_of;

foreach (keys %plc) {

   my $abbrev4 = $plc{$_}{Identifier};
   next unless length($abbrev4) eq 4;

   my $abbrev8 = $plc{$_}{Number};
   my $abbrev9 = substr($abbrev8,0,4) . " " . substr($abbrev8, 4, 4);
   $abbrev9 =~ s/  +/ /g;

   if ( $seen{$abbrev9} ) {
      warn ("Warning: $abbrev9 duplicated. Using $abbrev4 and $seen{$abbrev9}.\n");
      $abbrev9_of{$abbrev4} = $abbrev4;
      $abbrev9_of{$seen{$abbrev9}} = $seen{$abbrev9};
   } 
   else {

      $abbrev9_of{$abbrev4}=$abbrev9;
      $seen{$abbrev9} = $abbrev4;

   }

}

foreach (keys %plc) {
   
   my $abbrev4 = $plc{$_}{Identifier};
   next unless length($abbrev4) eq 4;

   my $desc = $plc{$_}{Description};
   my $district = $plc{$_}{District};

   my $abbrev9 = $abbrev9_of{$abbrev4};

   print $out  jt ($abbrev4,$abbrev9,$desc,$district) , "\n";

}


=head1 NAME

avl2tpimport - Timepoints for FileMaker

=head1 DESCRIPTION

avl2tpimort reads the data written by readavl.
It then outputs a list of timepoints suitable for import to FileMaker.

=head1 AUTHOR

Aaron Priven

=cut
