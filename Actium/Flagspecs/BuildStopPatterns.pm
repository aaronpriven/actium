# Actium/Flagspecs/BuildStopPatterns.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::BuildStopPatterns 0.001;

use Actium::Util qw(jk);
use Actium::Constants;
use Actium::Term (':all');

use Carp;
use English('-no_match_vars');

use Readonly;

# These should be moved to Lines and Cities tables, respectively
Readonly my @TRANSBAY_NOLOCALS => qw/FS L NX NX1 NX2 NX3 U W/;

Readonly my %SIDE_OF => (
    ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 98 99/ ) ),
    ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
);

1;

# Go through PAT and TPS, building whatever needs to be built

sub build_stop_patterns {

    my $hasi_db = shift;
    my $xml_db  = shift;

    my %stop_obj_of;
    my %pattern_obj_of;

    emit 'Building lists of patterns, stops, and places';

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE NOT IsInService = '' ORDER BY Route} );

    my $hasi_dbh = $hasi_db->dbh();
    my $tps_sth =
      $hasi_dbh->prepare('SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');

    my $prevroute = $EMPTY_STR;

  PAT:
    while ( my $pat = $eachpat->() ) {

        my $pat_ident = $pat->{Identifier};
        my $route     = $pat->{Route};
        if ( $route ne $prevroute ) {
            emit_over $route ;
            $prevroute = $route;
        }

        my $pattern_obj = Actium::Flagspecs::Pattern->new(
            {
                route     => $route,
                direction => $pat->{DirectionValue},
                identifer => $pat_ident,
            }
        );

        my $pattern_unique_id = $pattern_obj->unique_id;
        $pattern_obj_of{$pattern_unique_id} = $pattern_obj;

        my @tps_rows = @{
            $hasi_dbh->selectall_arrayref( $tps_sth, { Slice => {} },
                $pat->{PAT_id} )
          };

        my $prevplace = $EMPTY_STR;
        my $prevstop  = $EMPTY_STR;
        my ( @intermediate_stop_objs, @all_stop_objs );

        my %seen_stop_in_this_pattern;

      TPS:

        for my $tps_row (@tps_rows) {
            my $place = $tps_row->{Place};
            $place =~ s/-[AD12]\z//sx;
            my $stop_ident = $tps_row->{StopIdentifier};

            if ( $stop_ident eq $prevstop ) {    # same stop
                next TPS if ( not $place ) or ( $place eq $prevplace );

                # skip stop entirely unless place is changed

                $all_stop_objs[-1]->set_place($pattern_unique_id , $place);

                # if place changed, make previous stop this new place

                $pattern_obj->add_place($place);
                $prevplace = $place;

                next TPS;
            }

            # so not the same stop

            my $stops_row_r = $xml_db->row( 'Stops', $stop_ident );

            my $stop_obj;
            if ( exists $stop_obj_of{$stop_ident} ) {
                $stop_obj = $stop_obj_of{$stop_ident};
            }
            else {
                my $district = $stops_row_r->{'calc_district_id'};
                $district =~ s/\A 0//sx;
                my $side = $SIDE_OF{$district};
                if ( not $side ) {
                    carp "Unknown district: $district";
                    set_term_pos(0);
                }
                $stop_obj = Actium::Flagspecs::Stop->new(
                    id       => $stop_ident,
                    district => $district,
                    side     => $side
                );
                $stop_obj_of{$stop_ident} = $stop_obj;
            }

            my $is_at_place = 0;
            if ( $place and $place ne $prevplace ) {    # different place
                $pattern_obj->add_place($place);
                $prevplace = $place;

                $is_at_place = 1;

                foreach (@intermediate_stop_objs) {
                    $_->set_nextplace->($pattern_unique_id, $place);
                }
                @intermediate_stop_objs = ();
            }

            my $relation_obj = Actium::Flagspecs::Stop::PatternRelation->new(
                {
                    place             => $place,
                    is_at_place       => $is_at_place,
                    pattern_unique_id => $pattern_obj->unique_id,
                }
            );

            foreach
              my $connection ( split( /\n/sx, $stops_row_r->{Connections} ) )
            {
                $relation_obj->add_connection($connection);
            }

            push @all_stop_objs,          $pattern_obj;
            push @intermediate_stop_objs, $pattern_obj;

            # If this stop is present more than once in the same pattern
            # then do not add this pattern relation to the list.
            # This would be the case for loops, where the last stop is
            # the same as the first. For lollipop routes or other weird
            # shapes, it might not be the last stop.... 
            
            if ( not $seen_stop_in_this_pattern{$stop_ident} ) {
                $stop_obj->add_pattern_relation($pattern_obj);
                $seen_stop_in_this_pattern{$stop_ident} = 1;
                $stop_obj->add_route($route);
            }

            $pattern_obj->add_stop($stop_ident);

            # references to the same anonymous hash

        }    ## tidy end: for my $tps_row (@tps_rows)

        $all_stop_objs[-1]->set_last_stop($pattern_unique_id);

        # connections and Transbay info

        transbay_and_connections( $route, @all_stop_objs );

        # Place lists

        my $placelist = jk( $pattern_obj->places );

=for FIXING SHORTLY

        push @{ $pats_of{$routedir}{$placelist} }, $pat_rdi;
        $placelist_of{$pat_rdi} = $placelist;
        
=cut

        # now we have cross-indexed the pattern ident
        # and its place listing

    }    ## tidy end: while ( my $pat = $eachpat...)

    emit_done;

    return;

}    ## tidy end: sub build_stop_patterns

#  TODO - finish modifying below for OO

sub transbay_and_connections {
    my ( $route, @all_stops ) = @_;

    my $transbay;
    my $prev_side;
    my %these_connections;
    for my $patinfo ( reverse @all_stops ) {

        # first, put all existing connections into ConnIcons
        foreach my $connection ( keys %these_connections ) {
            $patinfo->{ConnIcons}{$connection} = 1;
        }

        # then, save the connections of the current stop for later
        foreach my $connection ( keys %{ $patinfo->{Connections} } ) {
            $these_connections{$connection} = 1;
        }

        if ($transbay) {
            $patinfo->{TransbayIcon} = 1;
        }
        else {
            my $side = $patinfo->{Side};
            if ( $prev_side and ( $prev_side ne $side ) ) {
                $transbay = 1;
                $patinfo->{TransbayIcon} = 1;
            }
            else {
                $prev_side = $side;
            }
        }
    }    ## tidy end: for my $patinfo ( reverse...)

    if ( $route ~~ @TRANSBAY_NOLOCALS ) {
        my $dropoff;
        undef $prev_side;
        for my $patinfo (@all_stops) {
            if ($dropoff) {
                $patinfo->{DropOffOnly} = 1;
            }
            else {
                my $side = $patinfo->{Side};
                if ( $prev_side and ( $prev_side ne $side ) ) {
                    $dropoff = 1;
                    $patinfo->{DropOffOnly} = 1;
                }
                else {
                    $patinfo->{TransbayOnly} = 1;
                    $prev_side = $side;
                }
            }

        }

    }    ## tidy end: if ( $route ~~ @TRANSBAY_NOLOCALS)

}    ## tidy end: sub transbay_and_connections

1;
