#!/Activeperl/bin/perl

# avl2patdest.pl

# legacy stage 2

# This is used for generating the destinations that Nextbus uses on its
# web site.

use 5.010;

use warnings;
use strict;

our $VERSION = 0.005;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Carp;

#use Fatal qw(open close);
use Storable();

use Actium::Constants;
use Actium::Union('ordered_union');

use Actium::Files::FileMaker_ODBC (qw[load_tables]);
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

my ( %pat );

{    # scoping
     # the reason to do this is to release the %avldata structure, so Affrus
     # (or, presumably, another IDE)
     # doesn't have to display it when it's not being used. 
     # Of course it saves memory, too

    my $avldata_r = $signup->retrieve('avl.storable');

    %pat = %{ $avldata_r->{PAT} };

}

my ( @timepoints, %timepoints );

load_tables(
    requests => {
        Timepoints => {
            array       => \@timepoints,
            hash        => \%timepoints,
            index_field => 'Abbrev4'
        },
    }
);

open my $nbdest, ">", "nextbus-destinations.txt";

print $nbdest "Route\tPattern\tDirection\tDestination\n";

my @results;
my ( %seen );

foreach my $key ( keys %pat ) {

    # GET DATA FROM PATTERN

    next unless $pat{$key}{IsInService};

    my $pat   = $pat{$key}{Identifier};
    my $route = $pat{$key}{Route};
    my $dir   = $pat{$key}{DirectionValue};

    my $lasttp = $pat{$key}{TPS}[-1]{Place};

    $lasttp =~ s/-[21AD]$//;

    my $dest = $timepoints{$lasttp}{DestinationF};

    my $city    = $timepoints{$lasttp}{City};
    my $usecity = $timepoints{$lasttp}{UseCity};

    $dest ||= $lasttp;

    # SAVE FOR RESULTS

    $seen{$lasttp} = $dest;

    for ($dir) {
        if ( $_ == 8 ) {
            $dest = "Clockwise to $dest";
            next;
        }
        if ( $_ == 9 ) {
            $dest = "Counterclockwise to $dest";
            next;
        }
        if ( $_ == 14 ) {
            $dest = "A Loop to $dest";
            next;
        }
        if ( $_ == 15 ) {
            $dest = "B Loop to $dest";
            next;
        }

        $dest = "To $dest";

    } ## tidy end: for ($dir)

    #$dest .= ", $city" if $usecity =~ /^y/i;

    push @results,
      { ROUTE  => $route,
        PAT    => $pat,
        DIR    => $dir,
        DEST   => $dest,
        LASTTP => $lasttp
      };

} ## tidy end: foreach my $key ( keys %pat)

foreach (
    sort {
             byline( $a->{ROUTE}, $b->{ROUTE} )
          or $a->{PAT} <=> $b->{PAT}
          or $a->{DIR} <=> $b->{DIR}
    } @results
  )
{

    say $nbdest join( "\t", $_->{ROUTE}, $_->{PAT}, $_->{DIR}, $_->{DEST} );

}

close $nbdest;

foreach ( sort keys %seen ) {
    say "$_\t$seen{$_}";
}

