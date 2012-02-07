#!/ActivePerl/bin/perl

# pat-directions 

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use 5.010;

use FindBin('$Bin'); 
   # so $Bin is the location of the very file we're in now

use lib $Bin; 
   # there are few enough files that it makes sense to keep
   # main program and library in the same directory


use Actium::Files::Merge::FPMerge qw(FPread FPread_simple);

use Actium::Options (qw<option add_option>);
#add_option ('spec' , 'description');
use Actium::Term (qw<printq sayq>);
use Actium::Folders::Signup;
my $signupdir = Actium::Folders::Signup->new();
chdir $signupdir->get_dir();
my $signup = $signupdir->get_signup;

my $in_service;

my @patterns;

my (%options , %name_of);

@ARGV = glob q(avl/*.PAT);

while (my $line = <>) {
   chomp $line;

   my @fields = split(/,/ , $line);

   given ($fields[0]) {

      when ('PAT') {

      s/\s+$// foreach @fields;
      
      $in_service = $fields[6] eq 'X';

      next unless $in_service;

      push @patterns, { ROUTE => $fields[1] , PATNUM => $fields[2] };

      }

      when ('TPS') {
         
         next unless $in_service;

         my $place = $fields[2];

         $patterns[$#patterns]{PLACE} = $place;
      }
      default {
         die "Unknown field type $fields[0]";
      }

   }
}


my (@timepoints, %timepoints) ;

FPread_simple ('Timepoints.csv' , \@timepoints, \%timepoints, 'Abbrev9');

foreach (@timepoints) {

   next unless $_->{Abbrev4};
   $name_of{$_->{Abbrev4}} = $_->{TPName} ;

}


foreach (@patterns) {

   my $place = substr($_->{PLACE}, 0, 4);
   
   say $_->{ROUTE} , "\t" , $_->{PATNUM} , "\t" , $place , "\t" 
        , $name_of{$place} || q[((null))];
   #say $_->{ROUTE} , "\t" , $_->{PATNUM} , "\t" , $_->{PLACE};

}
