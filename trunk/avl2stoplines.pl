#!/ActivePerl/bin/perl

@ARGV = qw(-s sp09) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2stoplines - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use 5.010;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ($Bin , "$Bin/../bin");

use Carp;
use POSIX ('ceil');
#use Fatal qw(open close);
use Storable();

use Actium( qw[say sayt jn byroutes jt initialize avldata ensuredir option]);
use Actium::Constants;
use Actium::Union('ordered_union');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop.
It is saved in the file "stoplines.txt" in the directory for that signup.
EOF

my $intro = 'avl2stoplines -- make a list of stops with lines served from AVL data';

Actium::initialize ($helptext, $intro);

# retrieve data

my %pat;
my %stp;

{ # scoping
# the reason to do this is to release the %avldata structure, so Affrus 
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = avldata();

%pat = %{$avldata_r->{PAT}};

%stp = %{$avldata_r->{STP}};

}

my %routes_of;

PAT:
foreach my $key (keys %pat) {

   next unless $pat{$key}{IsInService};

   my $route = $pat{$key}{Route};
   next if $route eq '399';

   foreach my $tps_r ( @{$pat{$key}{TPS}}) {
       my $stopid = $tps_r->{StopIdentifier};
       next unless $stopid =~ /^\d+$/msx;
       
       $routes_of{$stopid}{$route} = 1;
       
   }

}

open my $stoplines , '>' , 'stoplines.txt' or die "$!";

#say $stoplines "StopID\tLines\tNumLines\tFullQSchool\tHalf\tHalfQSchool\tQuarter\tNonschool\tSchool";
say $stoplines "PhoneID\tud_stp_FlagRoute\tNumLines\tNonschool\tSchool\tplace_id\tdescription\tdistrict_id";

my (@numlines, @fullqschool , @half, @halfqschool, @quarter, @nonschool, @school);

foreach my $stop (sort keys %routes_of) {
   print $stoplines "$stop\t";
   my @lines = sort byroutes keys %{$routes_of{$stop}} ;
   my $numlines = scalar(@lines);
   print $stoplines join (" " , @lines);
   
   my ($twodigit, $school, $allnighter, $threedigit) = (0,0,0,0);

   for my $line (@lines) {
      given ($line) {
         when (length ($_) < 3) {
            $twodigit++;
         }
         when (/^6/) {
            $school++;
         }
         when (/^8/) {
            $allnighter++;
         }
         default {
            $threedigit++;
         }

     }

   }

   no warnings 'numeric';

   $numlines[$numlines]++;
   
   my $fullqschool = $twodigit + $threedigit + $allnighter + ceil ($school / 4);

   $fullqschool[$fullqschool]++;

   my $half = ceil($twodigit / 2) + $school + $allnighter + $threedigit;

   $half[$half]++;

   my $halfqschool = $allnighter + $threedigit + 
         ceil ( ( ceil ($school / 2) + $twodigit ) / 2) ;
   # 3 digits except schools count as one, twodigits count as a half, schools count
   # as a quarter.  Schools and twodigits are added together because you can put two
   # schools and a twodigit on the same box.

   $halfqschool[$halfqschool]++;

   my $quarter = ceil (( $numlines - $allnighter )/ 4  + ceil ( $allnighter / 2) );
      # allnighter are double-wide

   $quarter[$quarter]++;

   my $nonschool = $numlines - $school;

   $nonschool[$nonschool]++;
   $school[$school]++;

   #say $stoplines "\t$numlines\t$fullqschool\t$half\t$halfqschool\t$quarter\t$nonschool\t$school";
   print $stoplines "\t$numlines\t$nonschool\t$school\t";
   say $stoplines join ("\t" , $stp{$stop}{Place}, $stp{$stop}{Description} , $stp{$stop}{District});
   

}

say "With\tNumLines\tFullQSchool\tHalf\tHalfQSchool\tQuarter\tNonschool\tSchool";

no warnings 'uninitialized';

for my $num (reverse 1 .. $#numlines ) {

   say "$num\t$numlines[$num]\t$fullqschool[$num]\t$half[$num]\t$halfqschool[$num]\t$quarter[$num]";

}

say '';

=head1 NAME

avl2stoplines - Make a list of stops with the lines for that stop.

=head1 DESCRIPTION

avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop. 
It is saved in the file "stoplines.txt" in the directory for that signup.

=head1 AUTHOR

Aaron Priven

=cut



