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
use List::MoreUtils ('uniq');

#use List::Compare::Functional qw(is_LdisjointR get_unique get_complement);
use List::Compare;

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

    my $trips_of_routedir_r
      = _make_trip_objs( $pat_routeids_of_routedir_r, $tripstructs_of_routeid_r,
        $uindex_of_r );

    my $trips_of_sked_r = _get_trips_of_sked($trips_of_routedir_r);

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

sub _make_trip_objs {
    my $pat_routeids_of_routedir_r = shift;
    my $trips_of_routeid_r         = shift;
    my $uindex_of_r                = shift;

    my %trips_of_routedir;

    # so the idea here is to go through each trip, and create a new
    # trip struct in trips_of_routedir that has the various information,
    # putting the times in the correct column as in uindex_of_r.

    # Then we turn them into objects, and sort the objects.

    emit 'Padding out blank columns of trips';

    foreach my $routedir ( sort keys $pat_routeids_of_routedir_r ) {

        emit_over $routedir;

        my @unified_trips;
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };

        foreach my $routeid (@routeids) {

            foreach my $trip_r ( @{ $trips_of_routeid_r->{$routeid} } ) {

                my $unified_trip_r = [ @{$trip_r} ];
                # copy everything

                my @times = @{ $trip_r->[T_TIMES] };

                my @unified_times;

                for my $old_column_idx ( 0 .. $#times ) {

                    my $new_column_idx
                      = $uindex_of_r->{$routeid}[$old_column_idx];

                    $unified_times[$new_column_idx] = $times[$old_column_idx];

                }

                $unified_trip_r->[T_TIMES] = \@unified_times;

                push @unified_trips, _tripstruct_to_tripobj($unified_trip_r);

            } ## tidy end: foreach my $trip_r ( @{ $trips_of_routeid_r...})

        } ## tidy end: foreach my $routeid (@routeids)

        $trips_of_routedir{$routedir}
          = Actium::Sked::Trip->stoptimes_sort( \@unified_trips );

    } ## tidy end: foreach my $routedir ( sort...)

    emit_done;

    return \%trips_of_routedir;

} ## tidy end: sub _make_trip_objs

sub _tripstruct_to_tripobj {
    my $tripstruct = shift;

    return Actium::Sked::Trip->new(
        {   days           => $tripstruct->[T_DAYS],
            vehicletype    => $tripstruct->[T_VEHICLE],
            stoptimes      => $tripstruct->[T_TIMES],
            daysexceptions => $tripstruct->[T_DAYSEXCEPTIONS],
            type           => $tripstruct->[T_TYPE],
            pattern        => $tripstruct->[T_PATTERN],
            routenum       => $tripstruct->[T_ROUTE],
            # DAYSDIGITS - no attribute in Actium::Sked::Trips,
            # but incorporated in days
        }
    );

}

sub _get_trips_of_sked {

    my $trips_of_routedir_r = shift;

    foreach my $routedir ( keys $trips_of_routedir_r ) {

        # first, this separates them out by individual days.
        # then, it reassembles them in groups.
        # The reason for this is that sometimes we end up getting
        # weird sets of days across the schedules we receive
        # (e.g., same trips Fridays and Saturdays)
        # and it's easier to do it this way if that's the case.

        my $trips_of_day_r
          = _get_trips_by_day( $trips_of_routedir_r->{$routedir} );

        my $trips_of_skedday = _assemble_skeddays($trips_of_day_r);

        ...;

    }

} ## tidy end: sub _get_trips_of_sked

sub _get_trips_by_day {

    my $trips_r = shift;
    my %trips_of_day;

    foreach my $trip ( @{$trips_r} ) {
        my @days = split( //, $trip->daycode );
        foreach my $day (@days) {
            push @{ $trips_of_day{$day} }, $trip;
        }
    }
    return \%trips_of_day;
}

sub _assemble_skeddays {
    my $trips_of_day_r = shift;
    my @days           = sort keys $trips_of_day_r;
    my ( %skedday_of_day, %chars_of_skedday, %trips_of_skedday );

    # Go through list of days. Compare the first one to the subsequent ones.
    # If any of the subsequent ones are identical to the first day, mark them
    # as such, and put them as part of the original list.

    foreach my $i ( 0 .. $#days ) {
        my $outer_day = $days[$i];
        next if $skedday_of_day{$outer_day};
        my @found_days = $outer_day;

        my $found_trips_r = $trips_of_day_r->{$outer_day};

        for my $j ( $i + 1 .. $#days ) {
            my $inner_day = $days[$j];
            next if $skedday_of_day{$inner_day};

            my $inner_trips_r = $trips_of_day_r->{$inner_day};
            my $outer_trips_r = $trips_of_day_r->{$outer_day};

            if ( my $merged_trips_r
                = _merge_if_appropriate( $outer_trips_r, $inner_trips_r ) )
            {
                push @found_days, $inner_day;
                $found_trips_r = $merged_trips_r;
            }
        }

        my $skedday = join( $EMPTY_STR, @found_days );
        $skedday_of_day{$_}         = $skedday foreach @found_days;
        $chars_of_skedday{$skedday} = \@found_days;
        $trips_of_skedday{$skedday} = $found_trips_r;

    } ## tidy end: foreach my $i ( 0 .. $#days)

    # so now we know that $skedday_of_day{$_} is the appropriate
    # skedday for all days in @days

} ## tidy end: sub _assemble_skeddays

sub _merge_if_appropriate {

    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    # first, check to see if all the trips themselves are the same object.
    # This will frequently be the case

    return $outer_trips_r
      if _trips_are_identical( $outer_trips_r, $inner_trips_r );
      
    ## now check if times are the same even if trips are not
    ## identical (as with Saturday/Sunday). First, make lists of times

    my @outer_times = map { $_->stoptimes_comparison_str } @{$outer_trips_r};
    my @inner_times = map { $_->stoptimes_comparison_str } @{$inner_trips_r};
    
    # Then compare them using List::Compare

    my $compare = List::Compare->new(
        {   lists    => [ \@outer_times, \@inner_times ],
            unsorted => 1,
        }
    );

    my $only_outer = scalar( $compare->get_unique );
    my $only_inner = scalar( $compare->get_complement );
    
    # if all the trips have identical times, then merge them

    if ( $only_inner == 0 and $only_outer == 0 ) {
        
        my @merged_trips;
        for my $i ( 0 .. $#outer_times ) {

            push @merged_trips,
              $outer_trips_r->[$i]->merge_trips( $inner_trips_r->[$i] )
              ;

        }
        
        return \@merged_trips;

    }
    
    
    # merge close-but-not-identical here?
    # 
    
    
    my $in_both    = scalar( $compare->intersection );
    
    
    # no merging
    
    return;

} ## tidy end: sub _merge_if_appropriate

sub _trips_are_identical {
    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    return if $#{$outer_trips_r} != $#{$inner_trips_r};

    for my $i ( 0 .. $#{$outer_trips_r} ) {
        return unless $outer_trips_r->[$i] == $inner_trips_r->[$i];
    }

    return 1;

}

__END__
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    my @current_days = @original_days;
    my $current_skedday = shift @current_days;
    my @future_days;
    
    while (@current_days) {
     
            my $current_day         = shift @current_days;
            my @previous_skedtrips = @{ $trips_of_day_r->{$current_skedday} };
            my @these_trips      = @{ $trips_of_day_r->{$this_day} };

            if ( my $new_trips_r = _merge_identical_triplists( \@previous_trips, \@these_trips ) ) {

                # merge $day_to_compare and $this_day
                # in $trips_of_day_r

                delete $trips_of_day_r->{$previous_day};
                delete $trips_of_day_r->{$this_day};
                $previous_day .= $this_day;
                $trips_of_day_r->{$previous_day} = $new_trips_r;

            } 
            else {
             push @not_compared , $this_day;
            }
       }
       
       @to_compare = @not_compared;
       
    }
             
              
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    while (@days) {
        
        foreach my $i ( 0 .. $#days ) {

        } ## tidy end: foreach my $i ( 0 .. $#days)
        
         # none were identical, so save this one in $trips_of_skedday

        $trips_of_skedday{$day_to_compare} = $trips_of_day_r->{$day_to_compare};
        
    } ## tidy end: while (@days)

} ## tidy end: sub _assemble_skeddays

1;

__END__


# all this stuff is not used anymore but is here in case I want to mine the 
# code for something


sub _merge_identical_trips {
    my $trips_of_routedir_r = shift;

    foreach my $routedir ( keys %{$trips_of_routedir_r} ) {

        my @trips = @{ $trips_of_routedir_r->{$routedir} };

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
              = Actium::Sked::Trip->merge_trips( $thistrip, $prevtrip );

        }

        $trips_of_routedir_r->{$routedir} = \@merged;

    } ## tidy end: foreach my $routedir ( keys...)

    return $trips_of_routedir_r;

} ## tidy end: sub _merge_identical_trips

sub _break_out_days {
    my $trips_of_routedir_r = shift;
    my %trips_of_skedid;

    foreach my $routedir ( keys %{$trips_of_routedir_r} ) {

        my @trips = @{ $trips_of_routedir_r->{$routedir} };

        my %sked_days_of = _days_of_trips(@trips);

        foreach my $trip (@trips) {
            my @sked_days_sets = @{ $sked_days_of{ $trip->daycode } };
            foreach my $sked_days (@sked_days_sets) {
                # incomplete -- must also un-merge the merged days
                ...;
                my $skedid = $routedir . "_$sked_days";
                push @{ $trips_of_skedid{$skedid} }, $trip;
            }
        }

    }

    # return the result

    return \%trips_of_skedid;

} ## tidy end: sub _break_out_days

sub _days_of_trips {
    my @trips = @_;

    my %seendays;
    $seendays{ $_->daycode }++ foreach @trips;

    my @daycodes = sort { $seendays{$a} <=> $seendays{$b} } keys %seendays;

    my %skeddays_of;
    $skeddays_of{$_} = [$_] foreach @daycodes;
        
    while ( @daycodes > 1 and my @indices = _get_first_intersection( @daycodes ) ) {
     
        my (@thesecodes, @counts);
        
        for my $i (@indices) {
         
            # remove these from the lists, to be added back later
            ...;
            
            $thesecodes[$i] = splice( @daycodes, $i,  1 ) ;
            $counts[$i] = $seendays{$thesecodes[$i]};
            delete $seendays{$thesecodes[$i]};
        }
        
        if ($counts[0] < 4 and $counts[0] * 5 < $counts[1] 
            and _less_frequent_one_is_subset (@thesecodes)  ) {
           # if the code with the lower count is less than 4,
           # and it is less than 20% of the code with the higher count,
           # and one is a subset of the other
           
           # merge lower days into higher days
           
           

           $skeddays_of{$thesecodes[0]} = $thesecodes[1];
           # ^^^ broken -- what if one or the other is merged?
           ...;
           
           $seendays{$thesecodes[1]} = $counts[0] + $counts[1];
           push @daycodes, $thesecodes[1]; # returns it to the list
           
        }
        else {
           
           # divide higher days into portions
           ...;
        }
        
        @daycodes = sort { $seendays{$a} <=> $seendays{$b}}  @daycodes;
        
    }
    
    return %skeddays_of;

} ## tidy end: sub _days_of_trips

sub _get_first_intersection {
    my @daycodes = @_;

    for my $i ( 0 .. $#daycodes ) {
        for my $j ( $i .. $#daycodes ) {
            return ( $i, $j )
              if _has_an_intersection( $daycodes[$i], $daycodes[$j] );
        }
    }
    return;    # no intersection
}

sub _has_an_intersection {
    my ($first, $second) = @_;
    return is_LdisjointR( [ _chars_of($first) , _chars_of($second) ] ) 
}

sub _chars_of {
    my $string = shift;
    state %cache;
    return $cache{$string} //= [ split( //, $string ) ];
}

sub _less_frequent_one_is_subset {
   my @arrays = map { [_chars_of($_)] } @_;
   my $only_in_first = scalar(get_unique ( @arrays ));
   
   return 1 if $only_in_first == 0;
   # so we know first one is a subset of the other
   
   return;
}

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

