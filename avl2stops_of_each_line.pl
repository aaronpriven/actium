#!/ActivePerl/bin/perl

# avl2stops_of_each_line

# legacy stage 2

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

use Actium::Sorting::Line ( qw<sortbyline>);
use Actium::Constants;
use Actium::Util('in');

my $helptext = <<'EOF';
avl2stops_of_each_line reads the data written by readavl and turns it into a 
list of lines with the number of stops. It is saved in the file 
"stops_of_each_line.txt" in the directory for that signup.
EOF

my $intro = 
'avl2stops_of_each_line -- make a list of lines with the number of stops served';

use Actium::Options (qw<add_option option init_options>);

use Actium::O::Folders::Signup;

init_options();

my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

# retrieve data

my %pat;
my %stp;

{ # scoping

my $avldata_r = $signup->retrieve('avl.storable');

%pat = %{$avldata_r->{PAT}};

}

my %seen_stops_of;

PAT:
foreach my $key (keys %pat) {

   next unless $pat{$key}{IsInService};

   my $route = $pat{$key}{Route};

   foreach my $tps_r ( @{$pat{$key}{TPS}}) {
       my $stopid = $tps_r->{StopIdentifier};

       $seen_stops_of{$route}{$stopid} = 1;

   }

}

open my $stopsfh , '>' , 'stops_of_each_line.txt' or die "$!";

say $stopsfh "Route\tStops\tDecals\tInventory\tPer set";

foreach my $route (sortbyline keys %seen_stops_of) {
 
    next if (in($route ,  qw/BSD BSH BSN 399 51S/ ));
 
    my $numstops = scalar keys %{$seen_stops_of{$route}};

    my $numdecals = 2 * $numstops;
    
    print $stopsfh "$route\t$numstops\t$numdecals\t";
    
    my $threshold = ceil ($numdecals * .02 )  * 10; # 
       # 20%, rounded up to a multiple of ten
       
    $threshold = 30 if $threshold < 30;
    
    my $perset = $threshold / 5;
    
    say $stopsfh "$threshold\t$perset";
    
}
    



