package Actium::Cmd::AVL2StopLines 0.010;

use Actium::Preamble;
use Actium::Term;
use Actium::Sorting::Line (qw[sortbyline]);
use Actium::Union('ordered_union');
use Actium::DaysDirections (':all');
use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

const my @opp = qw( EB WB NB SB CC CW A B);
const my %opposite_of = ( @opp, reverse @opp );

sub HELP {

    my $helptext = <<'EOF';
avl2stoplines reads the data written by readavl and turns it into a 
list of stops with the lines served by that stop.
It is saved in the file "stoplines.txt" in the directory for that signup.
EOF

    say $helptext;

    return;

}

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

##### Retrieve data from AVL and from database

sub START {

    my ( $class, %params ) = @_;
    my $actiumdb = actiumdb(%params);

    emit 'Generating stoplines';

    my $signup = Actium::O::Folders::Signup->new();
    chdir $signup->path();

    use Actium::Files::FileMaker_ODBC (qw[load_tables]);

    my %stops;
    load_tables(
        actiumdb => $actiumdb,
        requests => {
            Stops_Neue => {
                index_field => 'h_stp_511_id',
                hash        => \%stops,
                fields      => [qw/h_stp_511_id h_stp_identifier/],
            },
        }
    );

    # retrieve data

    my %pat;

    {    # scoping
        my $avldata_r = $signup->retrieve('avl.storable');
        %pat = %{ $avldata_r->{PAT} };
    }

    my ( %routes_of, %routedirs_of );

    # go through patterns, get routes and directions of each stop

  PAT:
    foreach my $key ( keys %pat ) {

        next unless $pat{$key}{IsInService};

        my $route = $pat{$key}{Route};
        next if $route eq '399';    # supervisor order

        my $dir = dir_of_hasi( $pat{$key}{DirectionValue} );

        for my $tps_n ( 0 .. $#{ $pat{$key}{TPS} } ) {
            my $tps_r  = $pat{$key}{TPS}[$tps_n];
            my $stopid = $tps_r->{StopIdentifier};
            next unless $stopid =~ /^\d+$/msx;

            $dir .= '-LAST' if $tps_n == $#{ $pat{$key}{TPS} };

            $routes_of{$stopid}{$route} = 1;
            $routedirs_of{$stopid}{"$route-$dir"} = 1;

        }

    }    ## #tidy# end foreach my $key ( keys %pat)

    # go through each stop and output data

    my $max = 0;

    open my $stoplines, '>', 'stoplines.txt' or die "$!";
    say $stoplines join(
        "\t",
        qw[
          h_stp_511_id p_active p_lines p_line_count
          p_linedirs p_linedir_count]
    );

    foreach my $stopid ( sort keys(%stops) ) {

        if ( not exists $routes_of{$stopid} ) {
            say $stoplines join( "\t", $stopid, 0, q[], 0, q[], 0 );
            next;
        }

        my $active   = 1;
        my $hastusid = $stops{$stopid}{h_stp_identifier};
        $active = 0 if $hastusid =~ /\AD/i;    # mark virtual stops inactive

        my @routes = keys %{ $routes_of{$stopid} };
        my @routedirs;

      # add routedirs to list, but only add -LAST if there's no better direction
      # that appears there

      ROUTEDIR:
        foreach my $routedir ( keys %{ $routedirs_of{$stopid} } ) {

            if ( $routedir =~ /LAST\z/ ) {

                my $opposite = get_opposite($routedir);
                if (   $routedirs_of{$stopid}{$opposite}
                    or $routedirs_of{$stopid}{ remove_last($routedir) } )
                {
                    next ROUTEDIR;
                }
            }
            push @routedirs, $routedir;
        }

        next unless @routes;    # eliminate BSH-only stops

        say $stoplines join( "\t",
            $stopid, $active,
            join( $SPACE, sortbyline(@routes) ),
            scalar @routes,
            join( $SPACE, sortbyline(@routedirs) ),
            scalar @routedirs,
        );

    }    ## #tidy# end foreach my $stop ( sort keys...)

    close $stoplines or die "Can't close stoplines file: $!";

    emit_done;

    return;

} ## tidy end: sub START

sub get_opposite {
    my $disp = shift;
    my ( $route, $dir, $has_last ) = split( /-/, $disp );
    return "$route-" . $opposite_of{$dir};
}

sub remove_last {
    my $disp = shift;
    $disp =~ s/-LAST\z//;
    return $disp;
}

1;
