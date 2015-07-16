package Actium::Cmd::AVL2PatDest 0.010;

use Actium::Preamble;

use Storable();    ### DEP ###

use Actium::Union('ordered_union');
use Actium::Files::FileMaker_ODBC (qw[load_tables]);
use Actium::Sorting::Line('byline');
use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

sub HELP {

    my $helptext = <<'EOF';
avl2patdest gives the destination of the last timepoint 
of each pattern
EOF

    say $helptext;
    return;
}

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {

    my ( $class, %params ) = @_;
    my $actiumdb = actiumdb(%params);

    my $signup = Actium::O::Folders::Signup->new();
    chdir $signup->path();

    my %stoplist = ();

    my (%pat);

    {    # scoping
        my $avldata_r = $signup->retrieve('avl.storable');
        %pat = %{ $avldata_r->{PAT} };
    }

    my %places;

    load_tables(
        actiumdb => $actiumdb,
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
        }
    );

    open my $nbdest, ">", "nextbus-destinations.txt";

    print $nbdest "Route\tPattern\tDirection\tDestination\n";

    my @results;
    my (%seen);

    foreach my $key ( keys %pat ) {

        # GET DATA FROM PATTERN

        next unless $pat{$key}{IsInService};

        my $pat   = $pat{$key}{Identifier};
        my $route = $pat{$key}{Route};
        my $dir   = $pat{$key}{DirectionValue};

        my $lasttp = $pat{$key}{TPS}[-1]{Place};

        $lasttp =~ s/-[21AD]$//;

        my $dest = $places{$lasttp}{c_destination};

        my $city = $places{$lasttp}{c_city};

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

} ## tidy end: sub START

1;
