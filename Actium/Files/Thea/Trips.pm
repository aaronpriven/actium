# /Actium/Files/Thea/Trips.pm

# The part of the theaImport routine that reads the trips files

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Files::Thea::Import 0.002;

use Actium::Term;
use Actium::Constants;
use Actium::Sked::Days;
use Actium::Time('timenum');
use Actium::Sked::Trip;
use List::Util;

use Sub::Exporter -setup => { exports => ['thea_trips'] };

use constant {
    T_DAYS           => 0,
    T_VEHICLE        => 1,
    T_TIMES          => 2,
    T_DAYSEXCEPTIONS => 3,
    T_PATTERN        => 4,
    T_ROUTE          => 5,
    T_TYPE           => 6,
    T_DAYDIGITS      => 7,
};

sub thea_trips {

    my $theafolder                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $uindex_of_r                = shift;

    my $tripstructs_of_routeid_r = _load_trips_from_file($theafolder);

    my $tripstructs_of_routedir_r
      = _pad_trip_columns( $pat_routeids_of_routedir_r,
        $tripstructs_of_routeid_r, $uindex_of_r );

    my $trip_objs_of_r = _make_trip_objs($tripstructs_of_routedir_r);

    $trip_objs_of_r = _merge_trip_objs($trip_objs_of_r);

}

my %required_headers = (
    trips => [
        qw<trp_int_number trp_route trp_pattern trp_is_in_service
          trp_blkng_day_digits trp_event>
    ],
    tripstops => [qw<trp_int_number tstp_position tstp_passing_time>],
);

sub _load_trips_from_file {
    my $theafolder = shift;
    emit 'Reading THEA trip files';

    my %trip_of_tnum;
    my %tnums_of_routeid;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $route   = $value_of_r->{trp_route};
        my $pattern = $value_of_r->{trp_pattern};

        my $routeid = $route . ':' . $pattern;

        push @{ $tnums_of_routeid{$routeid} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $event = $value_of_r->{trp_event};

        my $daydigits = $value_of_r->{trp_blkng_day_digits};

        my $days_obj = _make_days_obj( $daydigits, $event );

        $trip_of_tnum{$tnum}[T_DAYSEXCEPTIONS] = $event;

        $trip_of_tnum{$tnum}[T_PATTERN]   = $pattern;
        $trip_of_tnum{$tnum}[T_ROUTE]     = $route;
        $trip_of_tnum{$tnum}[T_TYPE]      = $value_of_r->{trp_type};
        $trip_of_tnum{$tnum}[T_DAYDIGITS] = $daydigits;

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

} ## tidy end: sub _load_trips_from_file

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

sub _pad_trip_columns {
    my $pat_routeids_of_routedir_r = shift;
    my $trips_of_routeid_r         = shift;
    my $uindex_of_r                = shift;

    my %trips_of_routedir;

    emit 'Padding out blank columns of trips';

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

} ## tidy end: sub _pad_trip_columns

sub _sort_trips {
    # sorts. Once sorted, puts trips with the same days together.

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

    #### MERGE IDENTICAL TRIPS (INCLUDING ACROSS DAYS)
    # obsolete - now merge trip objects, not raw trips

    #my @newtrips = _merge_raw_trips(@trips);
    #return \@newtrips;

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

sub _make_trip_objs {
    my $tripstructs_of_routedir_r = shift;

    my %tripobjs_of;

    foreach my $routedir ( keys %{$tripstructs_of_routedir_r} ) {

        my @trip_objs;

        foreach my $tripstruct ( @{ $tripstructs_of_routedir_r->{$routedir} } )
        {

            push @trip_objs, Actium::Sked::Trip->new(
                {   days           => $tripstruct->[T_DAYS],
                    vehicletype    => $tripstruct->[T_VEHICLE],
                    stoptimes      => $tripstruct->[T_TIMES],
                    daysexceptions => $tripstruct->[T_DAYSEXCEPTIONS],
                    type           => $tripstruct->[T_TYPE],
                    pattern        => $tripstruct->[T_PATTERN],
                    routenum       => $tripstruct->[T_ROUTE],
                    # DAYSDIGITS - no attribute in Actium::Sked::Trips
                }
            );

        }

        $tripobjs_of{$routedir} = \@trip_objs;

    } ## tidy end: foreach my $routedir ( keys...)

    return \%tripobjs_of;

} ## tidy end: sub _make_trip_objs

sub _merge_trip_objs {
    my $trip_objs_of_r = shift;

    foreach my $routedir ( keys %{$trip_objs_of_r} ) {

        my @trips = @{ $trip_objs_of_r->{$routedir} };

        my @merged = shift @trips;

        while (@trips) {
            my $thistrip = shift @trips;
            my $prevtrip = $merged[-1];

            if ( $thistrip->stoptimes_comparison_str ne
                $prevtrip->stoptimes_comparison_str )
            {

                push @merged, $thistrip;
                next;

            }

            $merged[-1]
              = Actium::Sked::Trip->merge_trips( $thistrip, $prevtrip )
              ;

        }
        
    # so now all trips have been merged into @merged
    # Now divide them into weekday/saturday/sunday or whatever
    # seems most likely.
    
    # haven't figured out how to do this yet...
    
        
        #$trip_objs_of_r->{$routedir} = \@something;

    } ## tidy end: foreach my $routedir ( keys...)
   
    # return the result

    return $trip_objs_of_r;

} ## tidy end: sub _merge_trip_objs

1;

__END__


sub _merge_raw_trips {
    # obsolete, since we will be merging not raw trips but trip objects

    my @trips = @_;

    my @newtrips = shift @trips;

  TRIP_TO_MERGE:
    while (@trips) {
        my $thistrip = shift @trips;
        my $prevtrip = $newtrips[-1];

        if (jk( @{ $thistrip->[T_TIMES] } ) ne jk( @{ $prevtrip->[T_TIMES] } ) )
        {
            push @newtrips, $thistrip;
            next TRIP_TO_MERGE;
        }

        my $times = $thistrip->[T_TIMES];

        my $days = Actium::Sked::Days->union( $thistrip->[T_DAYS],
            $prevtrip->[T_DAYS] );

        my $this_vehicle = $thistrip->[T_VEHICLE];
        my $prev_vehicle = $prevtrip->[T_VEHICLE];
        my $vehicle;

        if ( $this_vehicle eq $prev_vehicle ) {
            $vehicle = $this_vehicle;
        }
        else {
            $vehicle = _merge_conflicting(
                [ $thistrip->[T_DAYS], $this_vehicle ],
                [ $prevtrip->[T_DAYS], $prev_vehicle ]
            );
        }

        my @newtrip;
        $newtrip[T_TIMES]   = $times;
        $newtrip[T_DAYS]    = $days;
        $newtrip[T_VEHICLE] = $vehicle;

        $newtrips[-1] = \@newtrip;

    } ## tidy end: while (@trips)

    return \@newtrips;

} ## tidy end: sub _merge_raw_trips

sub _merge_conflicting {
    # takes conflicting string values and puts them in a single string
    # That string always begins with $KEY_SEPARATOR

    # fix this to treat the old one specially

    my @day_and_strings = @_;

    # @day_and_strings is an anonymous array. First value is
    # an Actium::Sked::Days object. Second value is a string value

    # It is possible that the string value passed to _merge_conflicting
    # is the result of a previous merge, so this next bit de-merges
    # the parts that were previously merged.

    my @to_merge;

    foreach my $day_and_string (@day_and_strings) {
        if ( $day_and_string->[1] !~ /^$KEY_SEPARATOR/ ) {
            push @to_merge, $day_and_string;
        }
        else {
            my @previously_merged = grep { $_ ne $EMPTY_STR }
              split( /$KEY_SEPARATOR/, $day_and_string->[1] );
            foreach my $string (@previously_merged) {
                my ( $daypart, $valuepart ) = split( / /, $string, 2 );
                push @to_merge,
                  [ Actium::Sked::Days->new_from_string($daypart), $valuepart ];
            }
        }
    }

    # so to_merge consists of day objects and non-merged strings

    my %days_of;

    foreach my $day_and_string (@to_merge) {
        my ( $day, $string ) = @{$day_and_string};
        if ( not exists $days_of{$string} ) {
            $days_of{$string} = $day;
        }
        else {
            $days_of{$string}
              = Actium::Sked::Days->union( $days_of{$string}, $day );
        }
    }

    my $merged = $EMPTY_STR;
    foreach my $string ( keys %days_of ) {
        $merged .= $KEY_SEPARATOR . $days_of{$string}->as_string . " $string";
    }

    return $merged;

} ## tidy end: sub _merge_conflicting




1;

