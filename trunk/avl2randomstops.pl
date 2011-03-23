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

=head1 NAME

avl2stoplines - Make a list of stops with the lines for that stop.

=head1 DESCRIPTION

avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop. 
It is saved in the file "stoplines.txt" in the directory for that signup.

=head1 AUTHOR

Aaron Priven

=cut



