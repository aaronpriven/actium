#!/Activeperl/bin/perl

# avl2patdest.pl

# legacy stage 2

# This is used for generating the destinations that Nextbus uses on its 
# web site.

use 5.010;

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Carp;

#use Fatal qw(open close);
use Storable();

use Actium::Constants;
use Actium::Union('ordered_union');

use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils('uniq');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2patdest gives the destination of the last timepoint 
of each pattern
EOF

my $intro = 'avl2patdest -- patterns and destinations';

use Actium::Sorting::Line('byline');
use Actium::Options ('init_options');
use Actium::O::Folders::Signup;

init_options;

my $signup = Actium::O::Folders::Signup->new();
chdir $signup->path();

my %stoplist = ();

my ( %pat , %vdc );

{    # scoping
        # the reason to do this is to release the %avldata structure, so Affrus
        # (or, presumably, another IDE)
     # doesn't have to display it when it's not being used. Of course it saves memory, too

my $avldata_r = $signup->retrieve('avl.storable');

    %pat = %{ $avldata_r->{PAT} };
    %vdc = %{ $avldata_r->{VDC} };


}

my (@timepoints, %timepoints);
FPread_simple( "Timepoints.csv", \@timepoints, \%timepoints, 'Abbrev4' );

open my $nbdest , ">" , "nextbus-destinations.txt";

print $nbdest "Route\tPattern\tDirection\tDestination\n";

my @results;
my (%seen, %messages_of);

foreach my $key ( keys %pat ) {

    # GET DATA FROM PATTERN

    next unless $pat{$key}{IsInService};

    my $pat = $pat{$key}{Identifier};
    my $route = $pat{$key}{Route};
    my $dir = $pat{$key}{DirectionValue};

    my $lasttp = $pat{$key}{TPS}[-1]{Place};

    $lasttp =~ s/-[21AD]$//;

    my $dest = $timepoints{$lasttp}{DestinationF};

    my $city = $timepoints{$lasttp}{City};
    my $usecity = $timepoints{$lasttp}{UseCity};

    $dest ||= $lasttp;

    # GET DATA FROM VDCS

    my $vdccode = $pat{$key}{VehicleDisplay};

    my @messages;
    foreach (qw(Message1 Message2 Message3 Message4)) {
        my $message = $vdc{$vdccode}{$_};
        next unless $message;
        push @messages, $vdc{$vdccode}{$_};
    }
    my $messages = join ("/" , @messages);
    push @{$messages_of{$lasttp}} , $messages;

    # SAVE FOR RESULTS

    $seen{$lasttp} = $dest;

    given ($dir) {
       when (8) {
          $dest = "Clockwise to $dest";
       }
       when (9) {
          $dest = "Counterclockwise to $dest";
       }
       when (14) {
          $dest = "A Loop to $dest";
       }
       when (15) {
          $dest = "B Loop to $dest";
       }
       default {
          $dest = "To $dest";
       }
    }

    #$dest .= ", $city" if $usecity =~ /^y/i;

    push @results, { ROUTE => $route , PAT => $pat, DIR => $dir, DEST => $dest , LASTTP => $lasttp };


}


foreach (sort { byline ($a->{ROUTE} , $b->{ROUTE}) or $a->{PAT} <=> $b->{PAT} 
or $a->{DIR} <=> $b->{DIR} 
} @results ) {

   say $nbdest join("\t" , $_->{ROUTE} , $_->{PAT} , $_->{DIR} , $_->{DEST} );

}

close $nbdest;

foreach (sort keys %seen) {
   say "$_\t$seen{$_}";
   foreach my $message (@{$messages_of{$_}}) {
      say "_\t\t\L$message";
   }
}

