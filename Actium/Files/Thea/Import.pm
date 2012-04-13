# /Actium/Files/Thea/Import.pm

# Takes the THEA files and imports them so Actium can use them.

# Subversion: $Id: TheaImport.pm 163 2012-03-17 00:06:54Z aaronpriven@gmail.com $

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Files::Thea::Import 0.002;

use Actium::Term ':all';
use Actium::Folders::Signup;
use Text::Trim;
use Actium::Files::TabDelimited 'read_tab_files';
use Actium::Time ('timenum');
use Actium::Sked::Days;

use Actium::Union('ordered_union_columns');

use Actium::Constants;

use English '-no_match_vars';
use List::Util ('min');
use List::MoreUtils (qw<each_arrayref>);

use constant { P_DIRECTION => 0, P_STOPS   => 1, P_PLACES => 2 };
use constant { T_DAYS      => 0, T_VEHICLE => 1, T_TIMES  => 2 };

use Sub::Exporter -setup => { exports => ['thea_import'] };

my %dircode_of_thea = (
    Northbound       => 'NB',
    Southbound       => 'SB',
    Eastbound        => 'EB',
    Westbound        => 'WB',
    Counterclockwise => 'CC',
    Clockwise        => 'CW',
    A                => 'A',    # sigh
    B                => 'B',
    '1'              => 'D1',
);
my %required_headers = (
    trippatterns => [
        qw<tpat_route tpat_id tpat_direction
          tpat_in_serv tpat_via tpat_trips_match>
    ],
    trippatternstops => [
        qw<stp_511_id tpat_stp_rank tpat_stp_plc tpat_stp_tp_sequence>,
        'item tpat_id', 'item tpat_route',
    ],
    trips => [
        qw<trp_int_number trp_route trp_pattern trp_is_in_service
          trp_blkng_day_digits trp_event>
    ],
    tripstops => [qw<trp_int_number tstp_position tstp_passing_time>],
);

sub thea_import {

    my $signup     = shift;
    my $theafolder = shift;

    my ( $patterns_r, $pat_routeids_of_routedir_r, $upattern_of_r,
        $uindex_of_r ) = _get_patterns($theafolder);

    my $trips_of_routeid_r = _get_trips($theafolder);

    my $trips_of_routedir_r
      = _assemble_trips( $patterns_r, $pat_routeids_of_routedir_r,
        $trips_of_routeid_r, $uindex_of_r );

    # figure out what to do about days...

    _output_debugging_patterns( $signup, $patterns_r,
        $pat_routeids_of_routedir_r, $upattern_of_r, $uindex_of_r,
        $trips_of_routeid_r, $trips_of_routedir_r );

} ## tidy end: sub thea_import

sub _assemble_trips {
    my $patterns_r                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $trips_of_routeid_r         = shift;
    my $uindex_of_r                = shift;

    my %trips_of_routedir;

    emit 'Assembling trips';

    foreach my $routedir ( sort keys $pat_routeids_of_routedir_r ) {

        emit_over $routedir;

        my @unified_trips;
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };

        foreach my $routeid (@routeids) {

            foreach my $trip_r ( @{ $trips_of_routeid_r->{$routeid} } ) {

                my $unified_trip_r = [];
                $unified_trip_r->[T_DAYS]    = $trip_r->[T_DAYS];
                $unified_trip_r->[T_VEHICLE] = $trip_r->[T_VEHICLE];

                my @times = @{ $trip_r->[T_TIMES] };

                my @unified_times;

                for my $old_column_idx ( 0 .. $#times ) {

                    my $new_column_idx
                      = $uindex_of_r->{$routeid}[$old_column_idx];

                    $unified_times[$new_column_idx] = $times[$old_column_idx];

                }

                $unified_trip_r->[T_TIMES] = \@unified_times;

                push @unified_trips, $unified_trip_r;

            } ## tidy end: foreach my $trip_r ( @{ $trips_of_routeid_r...})

        } ## tidy end: foreach my $routeid (@routeids)

        $trips_of_routedir{$routedir} = _sort_trips( \@unified_trips );

        emit_over ".";

    } ## tidy end: foreach my $routedir ( sort...)

    # so the idea here is to go through each trip, and create a new
    # trip struct in trips_of_routedir that has the various information,
    # putting the times in the correct column as in uindex_of_r

    emit_done;

    return \%trips_of_routedir;

} ## tidy end: sub _assemble_trips

sub _sort_trips {

    my @trips = @{ +shift };

    my $common_stop = _common_stop(@trips);

    if ( defined $common_stop ) {

        # sort trips with a common stop

        @trips = map { $_->[2] }
          sort { $a->[0] <=> $b->[0] or $a->[1] <=> $b->[1] }
          map {
            [   timenum( $_->[T_TIMES][$common_stop] ),    # 0
                _get_avg_time( $_->[T_TIMES] ),            # 1
                $_,                                        # 2
            ]
          } @trips;
        # a schwartzian transform with two criteria --
        # either the common stop, or if those times are the same,
        # the average.

    }
    else {
        # sort trips without a common stop for all of them

        @trips = sort {

            my $common = _common_stop( $a, $b );

            defined $common
              ?

              ( timenum( $a->[T_TIMES][$common] )
                  <=> timenum( $b->[T_TIMES][$common] )
                  or _get_avg_time( $a->[T_TIMES] )
                  <=> _get_avg_time( $b->[T_TIMES] )
              )

              :

              ( _get_avg_time( $a->[T_TIMES] )
                  <=> _get_avg_time( $b->[T_TIMES] ) );

            # if these two trips have a common stop, sort first
            # on those common times, and then by the average.

            # if they don't, just sort by the average.

        } @trips;

    } ## tidy end: else [ if ( defined $common_stop)]

    return \@trips;

} ## tidy end: sub _sort_trips

sub _common_stop {

    # returns undef if there's no stop in common, or
    # the stop to sort by if there is one

    my @trips = @_;
    my $common_stop;
    my $last_to_search = min( map { $#{ $_->[T_TIMES] } } @trips );

  SORTBY_STOP:
    for my $stop ( 0 .. $last_to_search ) {
      SORTBY_TRIP:
        for my $trip (@trips) {
            next SORTBY_STOP if not defined $trip->[T_TIMES][$stop];
        }
        $common_stop = $stop;
        last SORTBY_STOP;
    }

    return $common_stop;

} ## tidy end: sub _common_stop

sub _get_avg_time {
    my @elems = map { timenum($_) }
      grep { defined $_ } @{ +shift };  # get timenums of elems that are defined
    return ( List::Util::sum(@elems) / scalar @elems );
}

sub _output_debugging_patterns {
    my $signup                     = shift;
    my $patterns_r                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $upattern_of_r              = shift;
    my $uindex_of_r                = shift;
    my $trips_of_routeid_r         = shift;
    my $trips_of_routedir_r        = shift;

    my $subfolder = $signup->subfolder('thea_debug');

    my $rdfh = $subfolder->open_write('thea_unifiedtrips.txt');

    foreach my $routedir ( sort keys $trips_of_routedir_r ) {

        say $rdfh "\n$routedir";
        foreach my $trip ( @{ $trips_of_routedir_r->{$routedir} } ) {

            my @times = @{ $trip->[T_TIMES] };
            foreach (@times) {
                $_ = '--' unless defined;
                $_ = sprintf( "%-5s", $_ );
            }

            say $rdfh join( "\t",
                $trip->[T_DAYS]->as_sortable,
                $trip->[T_VEHICLE], join( " ", @times ) );
        }

    }

    close $rdfh or die "Can't close thea_unifiedtrips.txt: $OS_ERROR";

    my $tfh = $subfolder->open_write('thea_trips.txt');

    foreach my $routeid ( keys $trips_of_routeid_r ) {
        say $tfh "\n$routeid";
        foreach my $trip ( @{ $trips_of_routeid_r->{$routeid} } ) {
            say $tfh join( "\t",
                $trip->[T_DAYS]->as_sortable,
                $trip->[T_VEHICLE], join( " ", @{ $trip->[T_TIMES] } ) );
        }
    }

    close $tfh or die "Can't close thea_trips.txt: $OS_ERROR";

    my $ufh = $subfolder->open_write('thea_upatterns.txt');

    foreach my $routedir ( keys $pat_routeids_of_routedir_r ) {
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };
        say $ufh "\n$routedir\t",
          join( "\t", @{ $upattern_of_r->{$routedir} } );
        foreach my $routeid (@routeids) {
            say $ufh '"', $routeid, '"';
            say $ufh join( "\t", @{ $uindex_of_r->{$routeid} } );
        }
    }

    close $ufh or die "Can't close thea_upatterns.txt: $OS_ERROR";

    my $fh = $subfolder->open_write('thea_patterns.txt');

    foreach my $routeid ( sort keys $patterns_r ) {

        my $direction = $patterns_r->{$routeid}[P_DIRECTION];

        my @stopinfos = @{ $patterns_r->{$routeid}[P_STOPS] };
        my @stops;
        foreach my $stopinfo (@stopinfos) {
            my $text = shift $stopinfo;
            if ( scalar @$stopinfo ) {
                my $plc = shift $stopinfo;
                my $seq = shift $stopinfo;
                $text .= ":$plc:$seq";
            }
            push @stops, $text;

        }
        my $stops = join( " ", @stops );

        my %places = %{ $patterns_r->{$routeid}[ P_PLACES() ] };
        my @places;

        foreach my $seq ( sort { $a <=> $b } keys %places ) {
            push @places, "$seq:$places{$seq}";
        }
        my $places = join( " ", @places );

        say $fh "$routeid\t$direction\n$stops\n$places\n";

    } ## tidy end: foreach my $routeid ( sort ...)

    close $fh or die "Can't close thea_patterns.txt: $OS_ERROR";

} ## tidy end: sub _output_debugging_patterns

#my %is_a_valid_trip_type = { Regular => 1, Opportunity => 1 };

sub _get_trips {
    my $theafolder = shift;
    emit 'Reading THEA trip files';

    my %trip_of_tnum;
    my %tnums_of_routeid;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $routeid
          = $value_of_r->{trp_route} . ':' . $value_of_r->{trp_pattern};

        push @{ $tnums_of_routeid{$routeid} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $days_obj = _make_days_obj( $value_of_r->{trp_blkng_day_digits},
            $value_of_r->{trp_event} );

        $trip_of_tnum{$tnum}[T_DAYS] = $days_obj;

    };

    read_tab_files(
        {   globpatterns     => ['*trips.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trips'},
            callback         => $trip_callback,
        }
    );

    emit_done;

    emit 'Reading THEA trip stop (time) files';

    my $tripstops_callback = sub {
        my $value_of_r = shift;
        my $tnum       = $value_of_r->{trp_int_number};

        return unless exists $trip_of_tnum{$tnum};

        $trip_of_tnum{$tnum}[T_TIMES][ $value_of_r->{tstp_position} - 1 ]
          = $value_of_r->{tstp_passing_time};

    };

    read_tab_files(
        {   globpatterns     => ['*tripstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'tripstops'},
            callback         => $tripstops_callback,
        }
    );

    emit_done;

    my %trips_of_routeid;
    foreach my $routeid ( keys %tnums_of_routeid ) {
        foreach my $tnum ( @{ $tnums_of_routeid{$routeid} } ) {
            push @{ $trips_of_routeid{$routeid} }, $trip_of_tnum{$tnum};
        }
    }

    return \%trips_of_routeid;

} ## tidy end: sub _get_trips

sub _make_days_obj {

    my $day_digits = shift;
    my $trp_event  = shift;

    $day_digits =~ s/0/7H/;
    # Thea uses 0 instead of 7 for Sunday, as Hastus Standard AVL did.
    $day_digits = join( '', sort ( split( //, $day_digits ) ) );
    # sort $theaday by characters - putting 7 at end

    my $schooldaycode
      = $trp_event eq 'SD' ? 'D'
      : $trp_event eq 'SH' ? 'H'
      :                      'B';

    return Actium::Sked::Days->new( $day_digits, $schooldaycode );
}

sub _get_patterns {
    my $theafolder = shift;
    my %patterns;
    my %pat_routeids_of_routedir;

    emit 'Reading THEA trippattern files';

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};
        # skip if this trip isn't in service, or if it has no active trips

        my $tpat_route = $value_of_r->{tpat_route};
        my $tpat_id    = $value_of_r->{tpat_id};

        my $routeid = "$tpat_route:$tpat_id";
        return if exists $patterns{$routeid};    # duplicate

        my $tpat_direction = $value_of_r->{tpat_direction};
        my $direction      = $dircode_of_thea{$tpat_direction};
        if ( not defined $direction ) {
            $direction = $tpat_direction;
            emit_text("Unknown direction: $tpat_direction");
        }
        my $routedir = "$tpat_route:$direction";

        push @{ $pat_routeids_of_routedir{$routedir} }, $routeid;

        $patterns{$routeid}[ P_DIRECTION() ] = $direction;

        return;

    };

    read_tab_files(
        {   globpatterns     => ['*trippatterns.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatterns'},
            callback         => $patfile_callback,
        }
    );

    emit_done;

    emit 'Reading THEA trippatternstops files';

    my $patstopfile_callback = sub {
        my $value_of_r = shift;

        my $tpat_route = $value_of_r->{'item tpat_route'};
        my $tpat_id    = $value_of_r->{'item tpat_id'};

        my $routeid = "$tpat_route:$tpat_id";

        return unless exists $patterns{$routeid};

        my @stop = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @stop, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$routeid}[ P_STOPS() ][$tpat_stp_rank] = \@stop;

        $patterns{$routeid}[ P_PLACES() ]{$tpat_stp_tp_sequence} = $tpat_stp_plc
          if $tpat_stp_tp_sequence;

    };

    read_tab_files(
        {   globpatterns     => ['*trippatternstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatternstops'},
            callback         => $patstopfile_callback,
        }
    );

    emit_done;

    emit 'Making unified patterns for each direction';

    my ( %upattern_of, %uindex_of );

    foreach my $routedir ( keys %pat_routeids_of_routedir ) {

        my @routeids = @{ $pat_routeids_of_routedir{$routedir} };

        my %stop_set_of_routeid;
        foreach my $routeid (@routeids) {
            my @set;
            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
                push @set, join( ':', @{$stop} );
            }
            $stop_set_of_routeid{$routeid} = \@set;
        }

        #        my @stop_sets;
        #        foreach my $routeid (@routeids) {
        #            my @set;
        #            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
        #                push @set, join( ':', @{$stop} );
        #            }
        #            push @stop_sets, \@set;
        #        }

        my %returned = ordered_union_columns(
            sethash => \%stop_set_of_routeid,
            #            sets => \@stop_sets,
            #            ids  => \@routeids,
        );

        $upattern_of{$routedir} = $returned{union};

        foreach my $routeid (@routeids) {
            $uindex_of{$routeid} = $returned{columns_of}{$routeid};
        }

    } ## tidy end: foreach my $routedir ( keys...)

    emit_done;

    return \%patterns, \%pat_routeids_of_routedir, \%upattern_of, \%uindex_of;

} ## tidy end: sub _get_patterns

1;

__END__
