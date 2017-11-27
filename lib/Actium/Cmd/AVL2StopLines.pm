package Actium::Cmd::AVL2StopLines 0.012;

use Actium;
use Actium::Sorting::Line (qw[sortbyline]);
use Actium::Set('ordered_union');
use Actium::DaysDirections (':all');

use List::Compare;

const my @opp => qw( EB WB NB SB CC CW A B IN OU);
const my %opposite_of => ( @opp, reverse @opp );

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
    return (qw/actiumdb signup/);
}

##### Retrieve data from AVL and from database

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $cry = cry('Generating stoplines');

    my $signup = $env->signup;
    chdir $signup->path();

    my %stops;
    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                index_field => 'h_stp_511_id',
                hash        => \%stops,
                fields      => [
                    qw/h_stp_511_id h_stp_identifier
                      h_stp_flag_routes h_loca_longitude h_loca_latitude/
                ],
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
          p_linedirs p_linedir_count
          h_stp_flag_routes p_flag_route_diff
          h_loca_longitude h_loca_latitude]
    );

    foreach my $stopid ( sort keys(%stops) ) {

        my $h_stp_flag_routes = $stops{$stopid}{h_stp_flag_routes};

        my (@flagroutes);
        my $flagroutes_all = $EMPTY;

        if ($h_stp_flag_routes) {
            @flagroutes = split( /[\s,]+/, $stops{$stopid}{h_stp_flag_routes} );
            $flagroutes_all = join( $SPACE, @flagroutes );
        }

        if ( not exists $routes_of{$stopid} ) {

            my $flagroute_diff = add_char( 'A:', @flagroutes );

            my $long = $stops{$stopid}{h_loca_longitude};
            my $lat  = $stops{$stopid}{h_loca_latitude};

            say $stoplines join( "\t",
                $stopid, 0, q[], 0, q[], 0, $flagroutes_all, $flagroute_diff,
                $long, $lat );
            next;
        }

        my $active   = 1;
        my $hastusid = $stops{$stopid}{h_stp_identifier};
        my $long     = $stops{$stopid}{h_loca_longitude};
        my $lat      = $stops{$stopid}{h_loca_latitude};
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

        #next unless @routes;    # eliminate BSH-only stops

        my $lc = List::Compare->new( \@flagroutes, \@routes );

        my $added   = add_char( 'A:', $lc->get_Lonly() );
        my $removed = add_char( 'M:', $lc->get_Ronly() );

        my $flagroute_diff
          = ( $added and $removed ) ? "$added $removed" : "$added$removed";

        say $stoplines join( "\t",
            $stopid, $active,
            join( $SPACE, sortbyline(@routes) ),    scalar @routes,
            join( $SPACE, sortbyline(@routedirs) ), scalar @routedirs,
            $flagroutes_all, $flagroute_diff,
            $long,           $lat,
        );

    }    ## #tidy# end foreach my $stop ( sort keys...)

    close $stoplines or die "Can't close stoplines file: $!";

    $cry->done;

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

sub add_char {
    my $char = shift;
    my @list = @_;

    return $EMPTY unless @list;
    return $char . join( " $char", @list );
}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

