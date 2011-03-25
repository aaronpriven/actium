#!/ActivePerl/bin/perl

# avl2randomstops.pl

# another variant of avl2stoplines that randomizes the results, 
# allowing us to pick random stops for sampling.

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

use Actium::FPMerge (qw(FPread FPread_simple));
use Actium( qw[say sayt jn byroutes jt initialize avldata ensuredir option]);
use Actium::Constants;
use Actium::Union('ordered_union');

use List::Util('shuffle');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2randomstops reads the data written by readavl and turns it into a 
list of stops sorted randomly.
EOF

my $intro = 'avl2randomstops -- make a list of stops, randomly';

Actium::initialize ($helptext, $intro);

my ( @stops, %stops );
FPread_simple( 'Stops.csv', \@stops, \%stops, 'stop_id_1' );

# retrieve data

my %stp;

{ # scoping

my $avldata_r = avldata();

%stp = %{$avldata_r->{STP}};

}

my @stopids;

foreach my $stop_r (values %stp) {
   my $stopid =  $stop_r->{Identifier};
   next if $stopid =~ /^[a-z]/i;
   push @stopids, $stop_r->{Identifier};
}

@stopids = shuffle (@stopids);

open my $stopsfile , '>' , 'randomstops.txt' or die "$!";

say $stopsfile "StopID\tPhoneID\tDescription\tCity";

foreach my $stopid (@stopids) {

   my $phoneid = ($stops{$stopid}{PhoneID} //= 'NONE');
   my $description = ( $stops{$stopid}{DescriptionF} //= 'NONE');
   my $city = ( $stops{$stopid}{CityF} //= 'NONE');
   say $stopsfile "$stopid\t$phoneid\t$description\t$city";

}




