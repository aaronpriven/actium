# Actium/Cmd/Patterns.pm

# Subversion: $Id$

# Go through PAT and TPS, building whatever needs to be built

# legacy stage 4

use 5.012;
use warnings;

package Actium::Cmd::Patterns 0.001;

use Actium::Constants;
use Actium::O::Files::HastusASI;
use Actium::O::Files::FMPXMLResult;
use Actium::O::Folders::Signup;
use Actium::Term  (':all');
use Actium::Union ('ordered_union');
use Actium::Util qw(jk doe in);

use Actium::O::Pattern;
use Actium::O::Patterns::Stop;
use Actium::O::Patterns::Stop::PatternRelation;
use Actium::O::Patterns::Route;

use Carp;
use English('-no_match_vars');

sub START {

    my $signup     = Actium::O::Folders::Signup->new();
    my $flagfolder = $signup->subfolder('flags');

    my $xml_db  = $signup->load_xml;
    my $hasi_db = $signup->load_hasi;

    my ( $stop_obj_of_r, $route_obj_of_r ) =
      process_patterns( $hasi_db, $xml_db );

    my $pattern_folder = $signup->subfolder('patterns');

    $pattern_folder->store( $stop_obj_of_r,  'stops.storable' );
    $pattern_folder->store( $route_obj_of_r, 'routes.storable' );

}

sub process_patterns {

    my ( $hasi_db, $xml_db ) = @_;

    my ( %stop_obj_of, %pattern_objs_of_route );

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE NOT IsInService = '' ORDER BY Route} );

    my $hasi_dbh = $hasi_db->dbh();
    my $tps_sth =
      $hasi_dbh->prepare('SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');
    my $prevroute = $EMPTY_STR;

    my $stops_row_of_r  =
      $xml_db->all_in_columns_key(
        qw/Stops DescriptionCityF Connections district_id place_id/);
        
    emit 'Building lists of patterns, stops, and places';

  PAT:
    while ( my $pat_row = $eachpat->() ) {

        my ( $pat_ident, $route, $pattern_obj ) = _build_pattern_obj($pat_row);

        if ( $route ne $prevroute ) {
            emit_over $route ;
            $prevroute = $route;
        }

        push @{ $pattern_objs_of_route{$route} }, $pattern_obj;

        my ( $prevplace, $prevstop ) = ( $EMPTY_STR, $EMPTY_STR );
        my ( @intermediate_relation_objs, @all_relation_objs );

      TPS:

        for my $tps_row ( _tps_rows( $hasi_dbh, $tps_sth, $pat_row ) ) {

            my $place = $tps_row->{Place};
            $place =~ s/-[AD12]\z//sx;
            my $stop_ident = $tps_row->{StopIdentifier};

            if ( $stop_ident eq $prevstop ) {    # same stop
                next TPS
                  if ( not $place )
                  or ( $place eq $prevplace );

                # skip stop entirely unless place is changed

                $all_relation_objs[-1]->set_place($place);

                # if place changed, make previous stop this new place

                $pattern_obj->add_place($place);
                $prevplace = $place;

                next TPS;
            }

            # so not the same stop

            #my $stops_row_r = $xml_db->row( 'Stops', $stop_ident );

            my $stop_obj;
            if ( exists $stop_obj_of{$stop_ident} ) {
                $stop_obj = $stop_obj_of{$stop_ident};
            }
            else {
                $stop_obj =
                  _build_stop_obj( $stop_ident, $hasi_db,
                    $stops_row_of_r->{$stop_ident} );
                $stop_obj_of{$stop_ident} = $stop_obj;
            }

            my $is_at_place = 0;
            if ( $place and $place ne $prevplace ) {    # different place
                $pattern_obj->add_place($place);
                $prevplace = $place;

                $is_at_place = 1;

                foreach (@intermediate_relation_objs) {
                    $_->set_next_place($place);
                }
                @intermediate_relation_objs = ();
            }

            my $relation_obj = Actium::O::Patterns::Stop::PatternRelation->new(
                {
                    place             => $place,
                    is_at_place       => $is_at_place,
                    pattern_unique_id => $pattern_obj->unique_id,
                    stop_obj          => $stop_obj,
                }
            );

            my $connvalue =
              $stops_row_of_r->{$stop_ident}{Connections};
            foreach my $conn ( split( /\n/sx, $connvalue ) ) {
                $relation_obj->mark_at_connection($conn);
            }

            push @all_relation_objs,          $relation_obj;
            push @intermediate_relation_objs, $relation_obj;

            $stop_obj->add_relation($relation_obj);
            $stop_obj->set_route($route);
            $pattern_obj->add_stop($stop_ident);

        }    ## tidy end: for my $tps_row ( _tps_rows...)

        $all_relation_objs[-1]->set_last_stop();

        # connections and Transbay info
        _transbay_and_connections( $route, @all_relation_objs );

    }    ## tidy end: while ( my $pat_row = $eachpat...)

    my $route_obj_of_r = _build_route_objs( \%pattern_objs_of_route );

    emit_done;

    return \%stop_obj_of, $route_obj_of_r;

}    ## tidy end: sub process_patterns

sub _tps_rows {

    my $hasi_dbh = shift;
    my $tps_sth  = shift;
    my $pat_row  = shift;

    return @{
        $hasi_dbh->selectall_arrayref( $tps_sth, { Slice => {} },
            $pat_row->{PAT_id} )
      };

}

sub _build_pattern_obj {

    my $pat_row = shift;

    my $pat_ident = $pat_row->{Identifier};
    my $route     = $pat_row->{Route};

    my $direction = $pat_row->{DirectionValue};

    #$direction = $DIRCODES[$HASTUS_DIRS[$direction]];

    my $pattern_obj = Actium::O::Pattern->new(
        {
            route      => $route,
            direction  => $direction,
            identifier => $pat_ident,
        }
    );

    return ( $pat_ident, $route, $pattern_obj );

}    ## tidy end: sub _build_pattern_obj

sub _build_stop_obj {
    my $stop_ident  = shift;
    my $hasi_db     = shift;
    my $stops_row_r = shift;

    my ( $side, $district ) =
      _get_district( $stop_ident, $hasi_db, $stops_row_r );

    my $stop_obj = Actium::O::Patterns::Stop->new(
        id       => $stop_ident,
        district => $district,
        side     => $side
    );

    return $stop_obj;
}

sub _get_district {
    my $stop_ident  = shift;
    my $hasi_db     = shift;
    my $stops_row_r = shift;

    my $district = $stops_row_r->{'district_id'};

    # get district from Stops database

    # if not there, get it from places field in HASI
    if ( not $district ) {
        my $place = $stops_row_r->{'place_id'};
        my $plc_row = $hasi_db->row( 'PLC', $place );
        $district = $plc_row->{District};
    }

    # if not there either, get it from stops field in HASI
    if ( not $district ) {
        my $stp_row = $hasi_db->row( 'STP', $stop_ident );
        $district = $stp_row->{District};
    }

    # or, finally, give up
    if ( not $district ) {
        emit_text "Couldn't find district ID at stop $stop_ident ("
          . $stops_row_r->{DescriptionCityF} . ")";
        return ( '?', '?' );
    }

    $district =~ s/\A 0//sx;
    $district =~ s/\s+//sx;
    my $side = $SIDE_OF{$district};
    if ( not $side ) {
        emit_text qq<Unknown district: "$district" at stop $stop_ident>;
    }

    return ( $side, $district );

}    ## tidy end: sub _get_district

sub _transbay_and_connections {

    # runs once for each pattern

    my ( $route, @all_relation_objs ) = @_;

    my $transbay;
    my $prev_side;
    my %these_connections;

    # go through stops, backwards.
    # It puts connection information from the subsequent stops
    # in the pattern into the current stop

    for my $relation_obj ( reverse @all_relation_objs ) {

        # first, put all existing connections into ConnIcons
        foreach my $connection ( keys %these_connections ) {
            $relation_obj->mark_connection_to($connection);
        }

        # then, save the connections of the current stop for later
        foreach my $connection ( $relation_obj->connections_here ) {
            $these_connections{$connection} = 1;
        }

        if ($transbay) {
            $relation_obj->set_going_transbay;
        }
        else {
            my $side = $relation_obj->stop_obj->side;
            if ( $prev_side and ( $prev_side ne $side ) ) {
                $relation_obj->set_going_transbay;
                $transbay = 1;
            }
            else {
                $prev_side = $side;
            }
        }
    }    ## tidy end: for my $relation_obj ( ...)

    # next block sets either Transbay only or Drop Off only

    if ( in ($route , @TRANSBAY_NOLOCALS )) {
        my $dropoff;
        undef $prev_side;
        for my $relation_obj (@all_relation_objs) {
            if ($dropoff) {
                $relation_obj->set_dropoff_only;
            }
            else {
                my $side = $relation_obj->stop_obj->side;
                if ( $prev_side and ( $prev_side ne $side ) ) {
                    $dropoff = 1;
                    $relation_obj->set_dropoff_only;
                }
                else {
                    $relation_obj->set_transbay_only;
                    $prev_side = $side;
                }
            }

        }

    }    ## tidy end: if ( $route ~~ @TRANSBAY_NOLOCALS)

    return;

}    ## tidy end: sub _transbay_and_connections

sub _build_route_objs {

    my $patterns_of_r = shift;
    my %route_obj_of;

    foreach my $route ( keys %$patterns_of_r ) {

        $route_obj_of{$route} =
          Actium::O::Patterns::Route->new( $route, $patterns_of_r->{$route} );

    }

    return \%route_obj_of;

}

1;

__END__