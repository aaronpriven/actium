# Actium/Flagspecs/BuildStopPatterns.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::BuildStopPatterns 0.001;

use Actium::Util qw(jk);
use Actium::Constants;
use Actium::Term (':all');

use Actium::Flagspecs::Pattern;
use Actium::Flagspecs::Stop;
use Actium::Flagspecs::Stop::PatternRelation;

use Carp;
use English('-no_match_vars');

use Readonly;

# These should be moved to Lines and Cities tables, respectively
#Readonly my @TRANSBAY_NOLOCALS => qw/FS L NX NX1 NX2 NX3 U W/;

#Readonly my %SIDE_OF => (
#    ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 98 99/ ) ),
#    ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
#);

# those should now be from Actium::Constants

1;

# Go through PAT and TPS, building whatever needs to be built

sub build_stop_patterns {

    my $hasi_db = shift;
    my $xml_db  = shift;

    my %stop_obj_of;
    my %pattern_obj_of;
    my %placelist_obj_of;

    emit 'Building lists of patterns, stops, and places';

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE NOT IsInService = '' ORDER BY Route} );

    my $hasi_dbh = $hasi_db->dbh();
    my $tps_sth  = $hasi_dbh->prepare(
        'SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');

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
            {   route     => $route,
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

        my ( $prevplace, $prevstop ) = ( $EMPTY_STR, $EMPTY_STR );
        my ( @intermediate_relation_objs, @all_relation_objs );

      TPS:

        for my $tps_row (@tps_rows) {
            my $place = $tps_row->{Place};
            $place =~ s/-[AD12]\z//sx;
            my $stop_ident = $tps_row->{StopIdentifier};

            if ( $stop_ident eq $prevstop ) {    # same stop
                next TPS if ( not $place ) or ( $place eq $prevplace );

                # skip stop entirely unless place is changed

                $all_relation_objs[-1]->set_place($place);

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

                foreach (@intermediate_relation_objs) {
                    $_->set_next_place->( $pattern_unique_id, $place );
                }
                @intermediate_relation_objs = ();
            }

            my $relation_obj = Actium::Flagspecs::Stop::PatternRelation->new(
                {   place             => $place,
                    is_at_place       => $is_at_place,
                    pattern_unique_id => $pattern_obj->unique_id,
                    stop_obj          => $stop_obj,
                }
            );

            foreach
              my $connection ( split( /\n/sx, $stops_row_r->{Connections} ) )
            {
                $relation_obj->mark_at_connection($connection);
            }

            push @all_relation_objs,          $relation_obj;
            push @intermediate_relation_objs, $relation_obj;

            $stop_obj->add_relation($pattern_obj);
            $stop_obj->set_route($route);
            $pattern_obj->add_stop($stop_ident);

        } ## tidy end: for my $tps_row (@tps_rows)

        $all_relation_objs[-1]->set_last_stop($pattern_unique_id);

        # connections and Transbay info

        transbay_and_connections( $route, @all_relation_objs );

        # Place lists

        my $placelist = $pattern_obj->placelist;
        if ( exists $placelist_obj_of{$placelist} ) {
            $placelist_obj_of{$placelist}->add_pattern($pattern_obj);
        }
        else {

            $placelist_obj_of{$placelist} = Actium::Flagspecs::Placelist->new(
                placelist => $placelist,
                pattern_r => [$pattern_obj],
            );
        }

        # now we have cross-indexed the pattern ident
        # and its place listing

    } ## tidy end: while ( my $pat = $eachpat...)

    emit_done;

    return \%stop_obj_of, \%pattern_obj_of, \%placelist_obj_of;

} ## tidy end: sub build_stop_patterns

sub transbay_and_connections {
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
    } ## tidy end: for my $relation_obj ( ...)

    if ( $route ~~ @TRANSBAY_NOLOCALS ) {
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

    } ## tidy end: if ( $route ~~ @TRANSBAY_NOLOCALS)

    return;

} ## tidy end: sub transbay_and_connections

1;

__END__
