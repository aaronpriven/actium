#/Actium/Cmd/StopsOfEachLine.pm

package Actium::Cmd::StopsOfEachLine 0.010;

use Actium::Preamble;
use Storable();    ### DEP ###
use Actium::Sorting::Line (qw<sortbyline>);
use Actium::Cmd::Config::Signup ('signup');

sub HELP {

    my $helptext = <<'EOF';
avl2stops_of_each_line reads the data written by readavl and turns it into a 
list of lines with the number of stops. It is saved in the file 
"stops_of_each_line.txt" in the directory for that signup.
EOF

    say $helptext;

    return;

}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return ( Actium::Cmd::Config::Signup::options($env) );
}

sub START {
    my ( $class, $env ) = @_;
    my $signup = signup($env);

    chdir $signup->path();

    # retrieve data

    my %pat;

    {    # scoping
        my $avldata_r = $signup->retrieve('avl.storable');
        %pat = %{ $avldata_r->{PAT} };
    }

    my %seen_stops_of;

  PAT:
    foreach my $key ( keys %pat ) {

        next unless $pat{$key}{IsInService};

        my $route = $pat{$key}{Route};

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};

            $seen_stops_of{$route}{$stopid} = 1;

        }

    }

    open my $stopsfh, '>', 'stops_of_each_line.txt' or die "$!";

    say $stopsfh "Route\tStops\tDecals\tInventory\tPer set";

    foreach my $route ( sortbyline keys %seen_stops_of ) {

        next if ( in( $route, qw/BSD BSH BSN 399 51S/ ) );

        my $numstops = scalar keys %{ $seen_stops_of{$route} };

        my $numdecals = 2 * $numstops;

        print $stopsfh "$route\t$numstops\t$numdecals\t";

        my $threshold = ceil( $numdecals * .02 ) * 10;    #
             # 20%, rounded up to a multiple of ten

        $threshold = 30 if $threshold < 30;

        my $perset = $threshold / 5;

        say $stopsfh "$threshold\t$perset";

    } ## tidy end: foreach my $route ( sortbyline...)

} ## tidy end: sub START

1;
