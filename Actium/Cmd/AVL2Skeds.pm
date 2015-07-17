package Actium::Cmd::AVL2Skeds 0.010;

# This is one of the most important programs: it produces the skeds files from
# the avl files.

use Actium::Preamble;

use sort ('stable');

use List::MoreUtils (qw<all each_arrayref>);    ### DEP ###
use File::Copy;                                 ### DEP ###
use Array::Transpose;                           ### DEP ###
use Actium::Util (':all');
use Actium::Term ('sayq');
use Actium::Constants;
use Actium::Union('ordered_union');
use Actium::Time           ('timenum');
use Actium::DaysDirections (':all');
use Actium::Cmd::Config::Signup ('signup');

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        [ 'rawonly!', 'Only create "rawskeds" and not "skeds".' ],
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env)
    );
}

sub HELP {

    my $helptext = <<'EOF';
avl2skeds. Reads stored AVL data and makes skeds files.
Try "perldoc avl2skeds" for more information.
EOF

    say $helptext;
    return;

}

my %skeds_pairs_of;
my %skeds_lines_of;
my %skeds_specdays_of;
my %sked_order_of;
my %sked_of;
my %tp9_of;
my %tp4_of;
my @averaged_keys;
my %sked_override_order_of;

sub START {

    my $class = shift;
    my $env   = shift;

    my $quiet   = $env->option('quiet');
    my $rawonly = $env->option('rawonly');

    my $signup = signup($env);
    chdir $signup->path();

    # retrieve data

    my $rawskedsdir = $signup->subfolder('rawskeds');

    if ( not $rawonly ) {
        my $skedsdir    = $signup->subfolder('skeds');
        my $rawskedsdir = $signup->subfolder('rawskeds');
    }

    {    # scoping
         # the reason to do this is to release the %{$avldata_r} structure, so Affrus
         # doesn't have to display it when it's not being used. Of course it saves
         # memory, too

        my $avldata_r = $signup->retrieve('avl.storable');

        make_skeds_pairs_of_hash($avldata_r);
        make_tp9s($avldata_r);

    }

    load_timepoint_overrides();

    # definition of fields in %skeds_pairs_of;
    # $skeds_pairs_of{$linegroup_dir_days}[$trip]{TIME} = $time;
    # $skeds_pairs_of{$linegroup_dir_days}[$trip]{PLACE} = $place;

    # trim the thing down to the first item, for testing DEBUG
    #{
    #my ($one, $two) = each %skeds_pairs_of;
    #%skeds_pairs_of = ($one => $two);
    #}

    #iterates over each schedule
    my $count = 0;
    my $prev  = $EMPTY_STR;

    print "Processing line:";

    for my $this_sked_key ( sort keys %skeds_pairs_of ) {

        my $line = $this_sked_key;
        $line =~ s/$KEY_SEPARATOR.*//;

        unless ($quiet) {
            if ( $line ne $prev ) {
                print "\n" unless $count % 18;
                $count++;
                printf( '%4s', $line );
                $prev = $line;
            }
        }

        make_place_ordering($this_sked_key);

        make_sked($this_sked_key);

        # so:
        # $sked_of{$key}[$trip]{TIMES}[$tpnum] = a time
        # $sked_of{$key}[$trip]{LINE} = line number
        # $sked_of{$key}[$trip]{SPECDAYS} = special days

        modify_duplicate_places($this_sked_key);

        sort_rows($this_sked_key);

        remove_duplicate_rows($this_sked_key);

    } ## tidy end: for my $this_sked_key (...)

    merge_days( 'MO',   'TWT', 'MTWT' );
    merge_days( 'MTWT', 'FR',  'WD' );
    merge_days( 'TWT',  'FR',  'TWTF' );
    merge_days( 'SA',   'SU',  'WE' );
    merge_days( 'WD',   'SA',  'WA' );
    merge_days( 'WD',   'SU',  'WU' );
    merge_days( 'WD',   'WE',  'DA' );
    merge_days( 'FR',   'SA',  'FS' );

    for my $this_sked_key ( keys %sked_of ) {
        write_sked( $this_sked_key, 'skeds' ) unless $rawonly;
        write_sked( $this_sked_key, 'rawskeds' );
    }

    sayq("\n\nAveraged keys:");

    sayq( "   ", keyreadable($_) ) for (@averaged_keys);

    copy_exceptions($quiet) unless $rawonly;

    sayq("\nEnd.");

    return;

} ## tidy end: sub START

############# end of main program #######################

sub load_timepoint_overrides {

    open my $tpofile, '<', 'timepointorder.txt'
      or die "Can't open timepointorder.txt: $!";

    while ( my $tpo = <$tpofile> ) {
        chomp $tpo;
        my ( $sked, @timepoints ) = split( /\t/, $tpo );

        # convert tp9s to tp4s
        foreach (@timepoints) {
            $_ = $tp4_of{$_} if $tp4_of{$_};
        }

        my ( $line, $dircode, $days ) = split( /_/, $sked );

        my @skeds;
        push @skeds, jk( $line, $dircode, $days );

        if ( $days eq 'WE' or $days eq 'DA' ) {
            push @skeds, jk( $line, $dircode, 'SA' );
            push @skeds, jk( $line, $dircode, 'SU' );
        }
        if ( $days eq 'DA' ) {
            push @skeds, jk( $line, $dircode, 'WD' );
        }

        $sked_override_order_of{$_} = \@timepoints for @skeds;

    } ## tidy end: while ( my $tpo = <$tpofile>)

} ## tidy end: sub load_timepoint_overrides

sub modify_duplicate_places {
    # modify duplicate tp names and rearrange columns

    my $key = shift;

    # rearrange columns so arrivals always are first
    # and departures are second

  TRIP:
    for my $trip ( @{ $sked_of{$key} } ) {

        my $lastplaceidx = $#{ $trip->{TIMES} };

      PLACE:
        for my $placeidx ( 1 .. $lastplaceidx - 1 ) {
            next PLACE
              if $sked_order_of{$key}[$placeidx] ne
              $sked_order_of{$key}[ $placeidx - 1 ];
            my $thistime = $trip->{TIMES}[$placeidx];
            my $prevtime = $trip->{TIMES}[ $placeidx - 1 ];
            next PLACE if $thistime ne $EMPTY_STR and $prevtime ne $EMPTY_STR;

            # now we know we have only one time between the two columns.
            # Put it in the second column if there are more times; otherwise
            # put it in the first one.

            $thistime = $thistime || $prevtime;

            if (join( $EMPTY_STR,
                    @{ $trip->{TIMES} }[ $placeidx + 1 .. $lastplaceidx ] ) eq
                $EMPTY_STR
              )
            {
                # if all the times after this one are blank

                # put it in the first column
                $trip->{TIMES}[$placeidx] = $EMPTY_STR;
                $trip->{TIMES}[ $placeidx - 1 ] = $thistime;
            }
            else {
                # put it in the second column
                $trip->{TIMES}[ $placeidx - 1 ] = $EMPTY_STR;
                $trip->{TIMES}[$placeidx] = $thistime;
            }

        } ## tidy end: PLACE: for my $placeidx ( 1 .....)
    } ## tidy end: TRIP: for my $trip ( @{ $sked_of...})

    # add equals-signs and numbers
    my %seen;
    for my $place ( @{ $sked_order_of{$key} } ) {
        if ( $seen{$place} ) {
            $seen{$place}++;
            $place .= "=$seen{$place}";
        }
        else {
            $seen{$place} = 1;
        }
    }

} ## tidy end: sub modify_duplicate_places

sub merge_days {
    my @merging;
    my $merged;
    ( $merging[0], $merging[1], $merged ) = @_;

  SKED:
    foreach my $skedkey ( keys %sked_of ) {
        my ( $linegroup, $dircode, $days )
          = split( /$KEY_SEPARATOR/, $skedkey );

        next SKED if $days ne $merging[0];
        my $secondkey = jk( $linegroup, $dircode, $merging[1] );
        next SKED if ( not exists( $sked_of{$secondkey} ) );

        # so now we know that the first day and second day exist.

        next SKED
          if join( $EMPTY_STR, @{ $sked_order_of{$skedkey} } ) ne
          join( $EMPTY_STR, @{ $sked_order_of{$secondkey} } );
        # skip it if timepoints aren't all the same

        next SKED
          if scalar @{ $sked_of{$skedkey} } ne scalar @{ $sked_of{$secondkey} };
        # skip it if number of trips aren't the same

        for my $idx ( 0 .. $#{ $sked_of{$skedkey} } ) {
            next SKED
              if $sked_of{$skedkey}[$idx]{LINE} ne
              $sked_of{$secondkey}[$idx]{LINE};
            next SKED
              if $sked_of{$skedkey}[$idx]{SPECDAYS} ne
              $sked_of{$secondkey}[$idx]{SPECDAYS};
            next SKED
              if join( $EMPTY_STR, @{ $sked_of{$skedkey}[$idx]{TIMES} } ) ne
              join( $EMPTY_STR, @{ $sked_of{$secondkey}[$idx]{TIMES} } );

        }

        # so at this point, all is identical.

        my $newkey = jk( $linegroup, $dircode, $merged );
        $sked_of{$newkey}       = $sked_of{$skedkey};
        $sked_order_of{$newkey} = $sked_order_of{$skedkey};
        delete $sked_of{$skedkey};
        delete $sked_of{$secondkey};
        delete $sked_order_of{$skedkey};
        delete $sked_order_of{$secondkey};

    } ## tidy end: SKED: foreach my $skedkey ( keys ...)

    return;

} ## tidy end: sub merge_days

sub get_avg {
    my @elems = map { timenum($_) }
      grep {$_} @{ +shift };    # get timenums of elems that are true
    return ( List::Util::sum(@elems) / scalar @elems );
}

sub remove_duplicate_rows {

    my $key  = shift;
    my $sked = $sked_of{$key};

    my $row = 0;

    until ( $row >= $#{$sked} ) {

        $row++;

        next if $sked->[$row]{LINE} ne $sked->[ $row - 1 ]{LINE};
   #      next if $sked->[$row]{SPECDAYS} ne $sked->[$row-1]{SPECDAYS};
   # special days deliberately omitted - not sure whether that's correct or not,
   # given that no special days information comes through

        next
          if join( $EMPTY_STR, @{ $sked->[$row]{TIMES} } ) ne
          join( $EMPTY_STR, @{ $sked->[ $row - 1 ]{TIMES} } );

        splice( @{$sked}, $row, 1 );    # delete this row

    }

} ## tidy end: sub remove_duplicate_rows

sub sort_rows {
    my $key = shift;

    my $sked = $sked_of{$key};

    my $sortby = -1;

    # need to build new thing

    my @matrix;

    foreach my $trip ( @{$sked} ) {
        push @matrix, $trip->{TIMES};
    }

    my $transposed = transpose( \@matrix );

  SORTBY:
    for my $i ( 0 .. $#{$transposed} ) {
        if ( all { our $_; $_ } ( @{ $transposed->[$i] } ) ) {
            $sortby = $i;
            last SORTBY;
        }
    }

    if ( $sortby == -1 ) {

        push @averaged_keys, $key;

        # First sort by the first one in common, then by the average
        # of the times. I think this works. Yay!

        # -- old obsolete averaging code --
        #	   @{$sked} =
        #         map  { $_ -> [1] }
        #	      sort { $a->[0] <=> $b->[0] }
        #	      map  { [ get_avg($_->{TIMES}) , $_ ] } @{$sked};

        @{$sked} = sort {
            my $ea = each_arrayref( $a->{TIMES}, $b->{TIMES} );
            # Establishes an iterator, like "each" over hashes.
            while ( my ( $a_time, $b_time ) = $ea->() ) {
             # so $a_time and $b_time are paired entries of each array, in turn.

                if ( $a_time and $b_time ) {   # if there are two times present,
                    my $comparison = timenum($a_time) <=> timenum($b_time);
                    return $comparison if $comparison;
                    #return the comparison of the two times,
                    # if there is a difference and there are two times present
                }
            }

            return get_avg( $a->{TIMES} ) <=> get_avg( $b->{TIMES} );
            # none in common; return the average
        } @{$sked};

    } ## tidy end: if ( $sortby == -1 )
    else {
        @{$sked} = map { $_->[1] }
          sort { $a->[0] <=> $b->[0] }
          map { [ timenum( $_->{TIMES}[$sortby] ), $_ ] } @{$sked};
    }

    # schwartzian transform. The second "map" creates a new anonymous array:
    # item 0 is the item to sort by, item 1 is ref to structure.
    # the "sort" sorts by the thing to sort by (item 0).
    # then the first "map" builds a list of all the original structs
    # (item 1 of the anonymous array).

    # assigning to @{$sked} assigns to array pointed to by
    # $sked_of{$key} since they are the same reference

    return;

} ## tidy end: sub sort_rows

sub make_sked {
    my $key      = shift;
    my @trips    = @{ $skeds_pairs_of{$key} };
    my @lines    = @{ $skeds_lines_of{$key} };
    my @specdays = @{ $skeds_specdays_of{$key} };

    #    Go through each trip.
    #    Go through each place on that trip.
    #    Add time from that place to an array of times of that trip,
    #    with blank ones for all the places in the order that aren't
    #    there on that trip.

    my @alltrips = ();

    foreach my $trip_idx ( 0 .. $#trips ) {

        my $trip_r   = $trips[$trip_idx];
        my $line     = $lines[$trip_idx];
        my $specdays = $specdays[$trip_idx];

        my @expanded_trip;
        my $current_idx = 0;
        my $final_idx   = $#{$trip_r};
        # $current_idx and $final_idx refer to the non-expanded trip.

        # what this does is go through the ordered places. If this trip
        # has a time for a place, it pushes that entry to the end of
        # @expanded_trip; if not, it pushes the empty string

      PLACE:
        foreach my $place_to_process ( @{ $sked_order_of{$key} } ) {

            # pad out the trips until
            if ( $current_idx > $final_idx ) {
                push @expanded_trip, $EMPTY_STR;
                next PLACE;
            }

            my $current_place = $trip_r->[$current_idx]{PLACE};
            my $current_time  = $trip_r->[$current_idx]{TIME};

            if ( $place_to_process eq $current_place ) {
                $current_idx++;
                push @expanded_trip, $current_time;
            }
            else {
                push @expanded_trip, $EMPTY_STR;
            }

        } ## tidy end: PLACE: foreach my $place_to_process...

   # so now @expanded_trip contains that trip, with blanks inserted as necessary

        push @alltrips,
          { LINE => $line, SPECDAYS => $specdays, TIMES => \@expanded_trip };
    } ## tidy end: foreach my $trip_idx ( 0 .....)

    $sked_of{$key} = \@alltrips;

    return;

} ## tidy end: sub make_sked

sub write_sked {
    my $key = shift;
    my $dir = shift;

    my $filename = keyreadable($key);

    open my $out, '>', "$dir/$filename.txt" or die "$dir/$filename.txt: $!";

    print $out $filename, "\n";
    print $out "Note Definitions:\t\n";

    say $out jt( 'SPEC DAYS', 'NOTE', 'VT', 'RTE NUM',
        map { tp9($_) } ( @{ $sked_order_of{$key} } ) );

    foreach my $trip ( @{ $sked_of{$key} } ) {
        my @times = @{ $trip->{TIMES} };
        #if ($dir ne 'rawskeds') {
        tr/bx/pa/ for @times;    # old format can't handle b, a times
                                 #}
        say $out jt( $trip->{SPECDAYS}, $EMPTY_STR, $EMPTY_STR, $trip->{LINE},
            @times );
    }

    close $out;

} ## tidy end: sub write_sked

sub make_place_ordering {
    my $key   = shift;
    my @trips = @{ $skeds_pairs_of{$key} };

    my %trip_tps_seen;

    # go through each trip, and for each variant of the place
    # order, put that variant in the %trip_tps_seen (keyed
    # to a stringification of the trip).
    foreach my $trip (@trips) {

        #make the list of places in @places
        my @places = ();
        foreach my $place_time_pair_r ( @{$trip} ) {
            push( @places, $place_time_pair_r->{PLACE} );
        }

        # %trip_tps_seen contains unique place lists
        $trip_tps_seen{ jk(@places) } = \@places;

    }

    # run ordered_union on each of the values of %trips_tps_seen
    # so basically this keeps creating more and more unions until there's
    # only one left

    if ( $sked_override_order_of{$key} ) {
        $sked_order_of{$key}
          = ordered_union( $sked_override_order_of{$key},
            values %trip_tps_seen );

        if (join( $EMPTY_STR, @{ $sked_override_order_of{$key} } ) ne
            join( $EMPTY_STR, @{ $sked_order_of{$key} } ) )
        {
            warn
"\nTimepoints in timepointorder.txt not the same as final result for "
              . keyreadable($key) . "\n\n";
        }
    }
    else {
        $sked_order_of{$key} = ordered_union( values %trip_tps_seen );
    }

    return;

} ## tidy end: sub make_place_ordering

sub make_tp9s {

    my %avldata = %{ +shift };

    while ( my ( $place, $place_r ) = each %{ $avldata{PLC} } ) {
        my $number = sprintf( '%-8s', $place_r->{Number} );
        $number =~ tr/,/./;    # FileMaker doesn't like commas
        my $first = substr( $number, 0, 4 );
        my $second = substr( $number, 4 );
        $first =~ s/\s+$//;
        $second =~ s/\s+$//;
        $first =~ s/^\s+//;
        $second =~ s/^\s+//;
        my $tp9 = "$first $second";
        $tp9_of{$place} = $tp9;
        $tp4_of{$tp9} = $place unless $place =~ /-[AD12]\z/;
    }

    # known duplicate tp9s are given as tp4s instead
    foreach (qw/HDMA HIML BRJR BRMD/) {
        # change %tp4_of entries
        my $old_tp9 = $tp9_of{$_};
        delete $tp4_of{$old_tp9} if $old_tp9;
        $tp4_of{$_} = $_;
        $tp9_of{$_} = $_;
    }

} ## tidy end: sub make_tp9s

sub tp9 {

    my $tp4 = shift;
    my $number;
    my $tp9;

    if ( $tp4 =~ /=\d+\z/ ) {
        ( $tp4, $number ) = split( /=/, $tp4 );
        #   return "$tp9_of{$tp4}=$number";
    }

    # figure out what to return if no valid value

    if ( exists( $tp9_of{$tp4} ) ) {
        $tp9 = $tp9_of{$tp4};
    }
    else {
        $tp9 = "$tp4 ----";
    }

    if ($number) {
        $tp9 .= "=$number";
    }

    return $tp9;

} ## tidy end: sub tp9

sub make_skeds_pairs_of_hash {

    my %avldata = %{ +shift };

    # separate trips out by which line and direction they're in
  TRIP:
    while ( my ( $trip_number, $trip_of_r ) = each %{ $avldata{TRP} } ) {
        my %tripinfo_of = %{$trip_of_r};
        next TRIP unless $tripinfo_of{IsPublic};

        my $line = $tripinfo_of{RouteForStatistics};
        next TRIP if $line eq '399';    # supervisor order

        my $specdays = $tripinfo_of{SpecDays} || $EMPTY_STR;

        my $hasidays = $tripinfo_of{OperatingDays} =~ s/\*//gr;

        my $days = day_of_hasi($hasidays) || $hasidays;

        if ( $days eq 'TT' or $days eq 'TF' or $days eq 'MZ' ) {
            $specdays = $days;
            $days     = 'WD';
        }

        my $pattern = $tripinfo_of{Pattern};
        my $patkey = jk( $line, $pattern );
        if ( not exists $avldata{PAT}{$patkey} ) {
            next TRIP;
        }

        my $dirval = $avldata{PAT}{$patkey}{DirectionValue};
        if ( $dirval eq $EMPTY_STR ) {
            next TRIP;
        }
        my $dir_code = dir_of_hasi($dirval);

        my @pairs = ();
      TIMEIDX:
        foreach my $timeidx ( 0 .. $#{ $tripinfo_of{PTS} } ) {
            my $place = $avldata{PAT}{$patkey}{TPS}[$timeidx]{Place};
            next TIMEIDX unless $place;

            #remove -A and -D from places. not useful for us.

            $place =~ s/-[AD12]$//;

            next TIMEIDX if $place eq 'OARC';
            # the only private timepoint currently is OARC (aka OAKL AIRR).
            # If we need more, we can add a routine here

            my $time = $tripinfo_of{PTS}[$timeidx];
            $time =~ s/^0//;
            push @pairs, { PLACE => $place, TIME => $time };
        }

        my $linegroup = linegroup($line);

        my @days;

        # Alter days for 800 and 801
        if ( $line eq '800' or $line eq '801' ) {
            my $initial_time = $pairs[0]{TIME};
            if ( $initial_time =~ /\d+ x/x )
            {    # if first time is an "x" time (am next day)
                $_->{TIME} =~ tr/x/a/ foreach @pairs;
                for ($days) {
                    if ( $_ eq 'SU' ) {
                        @days = 'MO';
                        next;
                    }
                    if ( $_ eq 'SA' ) {
                        @days = 'SU';
                        next;
                    }
                    if ( $_ eq 'WD' ) {
                        @days = qw(TWT FR SA);
                        next;
                    }
                }
            }
            elsif ( $initial_time =~ /\d+ p/x )
            {    # if first time is an "p" time (pm that day)
                $_->{TIME} =~ tr/px/ba/ foreach @pairs;
                for ($days) {
                    if ( $_ eq 'SU' ) {
                        @days = 'SA';
                        next;
                    }
                    if ( $_ eq 'SA' ) {
                        @days = 'FR';
                        next;
                    }
                    if ( $_ eq 'WD' ) {
                        @days = qw(SU MO TWT);
                        next;
                    }
                }
            }
            elsif ( $days eq 'WD' ) {
                @days = qw(MO TWT FR);
            }
            else {
                @days = ($days);
            }

        } ## tidy end: if ( $line eq '800' or...)
        else {
            @days = ($days);
        }

        foreach my $thesedays (@days) {
            my $key = jk( $linegroup, $dir_code, $thesedays );
            push( @{ $skeds_lines_of{$key} },    $line );
            push( @{ $skeds_specdays_of{$key} }, $specdays );
            push( @{ $skeds_pairs_of{$key} }, [@pairs] );
        }

    } ## tidy end: TRIP: while ( my ( $trip_number...))

} ## tidy end: sub make_skeds_pairs_of_hash

sub linegroup {
    my $line = shift;
    return $LINES_TO_COMBINE{$line} if exists $LINES_TO_COMBINE{$line};
    return $line;
}

sub copy_exceptions {

    my $quiet = shift;

### read exception skeds
# I've changed this so that now exceptions have to go in the signup directory.
# It turns out that each signup will have to have its own exceptions, although sometimes
# these can be copied from the old ones...

    my @skeds = sort glob 'exceptions/*.txt';

    sayq(
"\nAdding exceptional schedules (possibly overwriting previously processed ones)."
    );

    my $displaycolumns = 0;

    my $prevlinegroup = "";
    foreach my $file (@skeds) {
        next if $file =~ m/=/;    # skip file if it has a = in it

        unless ($quiet) {
            my $linegroup = $file;
            $linegroup =~ s#^exceptions/##;
            $linegroup =~ s/_.*//;

            unless ( $linegroup eq $prevlinegroup ) {
                $displaycolumns += length($linegroup) + 1;
                if ( $displaycolumns > 70 ) {
                    $displaycolumns = 0;
                    print "\n";
                }
                $prevlinegroup = $linegroup;
                print "$linegroup ";
            }

        }

        my $newfile = $file;
        $newfile =~ s#exceptions#skeds#;    # result is "skeds/filename"
        File::Copy::copy( $file, $newfile )
          or die "Can't copy $file to $newfile: $!";

    } ## tidy end: foreach my $file (@skeds)

} ## tidy end: sub copy_exceptions

=head1 NAME

avl2skeds - Make schedules from the avl stored data.

=head1 DESCRIPTION

avl2skeds reads the data written by readavl and turns it into schedule
files suitable for ACTium.

=head1 BUGS

Sometimes two different places will have the same long timepoint abbreviation, e.g., Hillsdale Mall
and Hilltop Mall are both HILL MALL, even though one is HIML and the other is HDMA. For this particular
example, it knows that HDMA should be changed to HDAL MALL . For everything else, it will be ambiguous.
Enter the four-digit abbreviation, not the longer one, in timepointorder.txt.

=head1 AUTHOR

Aaron Priven

=cut

