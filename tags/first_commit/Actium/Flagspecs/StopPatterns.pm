# Actium/Flagspecs/StopPatterns.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::Flagspecs::StopPatterns;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Actium::Util qw(j jk jt);
use Actium::Constants;
use Actium::Term (':all');

use Carp;
use English('-no_match_vars');

use Readonly;

Readonly my @TRANSBAY_NOLOCALS => qw/FS L NX NX1 NX2 NX3 U W/;

Readonly my %SIDE_OF => (
    ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 98 99/ ) ),
    ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
);

1;
__END__ # remove when ready

sub build_place_and_stop_lists {
    
    my $hasi_db  = shift;
    my $stopdata = shift;
    
    my %routes;
    my %stop_obj_of;

    my ( $connections_col, $district_col )
      = $stopdata->column_order_of( 'Connections', 'calc_district_id' );

    emit 'Building lists of places and stops';

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE NOT IsInService = '' ORDER BY Route} );

    my $dbh = $hasi_db->dbh();
    my $tps_sth
      = $dbh->prepare('SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');

    my $prevroute = $EMPTY_STR;
  PAT:
    while ( my $pat = $eachpat->() ) {

        my $pat_ident = $pat->{Identifier};
        my $route     = $pat->{Route};
        if ( $route ne $prevroute ) {
            emit_over $route ;
            $prevroute = $route;
        }

        my @tps = @{
            $dbh->selectall_arrayref( $tps_sth, { Slice => {} },
                $pat->{PAT_id} )
          };

        my $routedir = jk( $route,    $pat->{DirectionValue} );
        my $pat_rdi  = jk( $routedir, $pat_ident );

        my @places;

        my $prevplace = $EMPTY_STR;
        my $prevstop  = $EMPTY_STR;
        my ( @intermediate_stops, @all_stops );

      TPS:

        for my $tps_row (@tps) {

            my $place = $tps_row->{Place};
            $place =~ s/-[AD12]\z//sx;
            my $stop_ident = $tps_row->{StopIdentifier};

            if ( $stop_ident eq $prevstop ) {    # same stop
                next TPS if ( not $place ) or ( $place eq $prevplace );

                # skip stop entirely unless place is changed

                $all_stops[-1]->{Place} = $place;

                # if place changed, make previous stop this new place

                push @places, $place;
                $prevplace = $place;

                next TPS;
            }

            if ( $place and $place ne $prevplace ) {    # different place
                push @places, $place;
                $prevplace = $place;
                $_->{AtPlace} = 1;

                foreach (@intermediate_stops) {
                    $_->{NextPlace} = $place;
                }
                @intermediate_stops = ();
            }

            my ($row) = $stopdata->rows_where( 'PhoneID', $stop_ident );

            my $patinfo = { Place => $prevplace };

            foreach my $connection ( split( /\n/sx, $row->[$connections_col] ) )
            {
                $patinfo->{Connections}{$connection} = 1;
            }

            my $district = $row->[$district_col];
            $district =~ s/\A 0//sx;
            $patinfo->{District} = $district;
            next TPS if $district =~ /\A D/sx;    # dummy stop
            my $side = $SIDE_OF{$district};
            if ( not $side ) {
                carp "Unknown district: $district";
                set_term_pos(0);
            }
            $patinfo->{Side} = $side;

            push @all_stops, $patinfo;
            my $already_in_pattern = 
               set_pats_of_stop( $stop_ident, $routedir, $pat_ident, $patinfo );
            #$pats_of_stop{$stop_ident}{$routedir}{$pat_ident} = $patinfo;
            $routes_of_stop{$stop_ident}{$route}++ unless $already_in_pattern;
            $routes{$route}++;
            push @{ $stops_of_pat{$pat_rdi} }, $stop_ident;
            push @intermediate_stops, $patinfo;    # if not $place;

            # references to the same anonymous hash

        } ## tidy end: for my $tps_row (@tps)
        $all_stops[-1]->{Last} = 1;

        # connections and Transbay info

        transbay_and_connections( $route, @all_stops );

        # Place lists

        my $placelist = jk(@places);

        push @{ $pats_of{$routedir}{$placelist} }, $pat_rdi;
        $placelist_of{$pat_rdi} = $placelist;

        # now we have cross-indexed the pattern ident
        # and its place listing

    } ## tidy end: while ( my $pat = $eachpat...)

    emit_done;

    return;

} ## tidy end: sub build_place_and_stop_lists








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
    } ## tidy end: for my $patinfo ( reverse...)

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

    } ## tidy end: if ( $route ~~ @TRANSBAY_NOLOCALS)

} ## tidy end: sub transbay_and_connections

1;