package Actium::Files::Xhea::ToSkeds 0.012;

use Actium::Preamble;
use Actium::Files::TabDelimited 'read_aoas';
use Actium::O::Dir;
use Actium::O::Time;
use Actium::O::Pattern;
use Actium::O::Pattern::Stop;

const my @required_tables => (qw/trip trip_pattern trip_stop trip_tp/);

sub xheatab2skeds {

    my $tabcry = cry("Loading xhea tab files...");

    my %params = u::validate(
        @_,
        {   skeds_folder    => 1,    # mandatory
            xhea_tab_folder => 1,
        }
    );
    my $skeds_folder    = $params{skeds_folder};
    my $xhea_tab_folder = $params{xhea_tab_folder};

    my @files = map {"$_.txt"} @required_tables;
    my ( $fieldnames_of_file_r, $values_of_file_r )
      = read_aoas( files => \@files, folder => $xhea_tab_folder );
    my ( $fieldnames_of_r, $values_of_r );

    foreach my $file ( keys %$fieldnames_of_file_r ) {
        my $table = $file =~ s/\.txt\z//r;
        $fieldnames_of_r->{$table} = $fieldnames_of_file_r->{$file};
        $values_of_r->{$table}     = $values_of_file_r->{$file};
    }

    $tabcry->done;

    return xhea2skeds(
        skeds_folder => $skeds_folder,
        fieldnames   => $fieldnames_of_r,
        values       => $values_of_r
    );

} ## tidy end: sub xheatab2skeds

sub xhea2skeds {

    my $xhea2skedscry = cry('Converting Xhea to schedules');

    my %params = u::validate(
        @_,
        {   skeds_folder => 1,    # mandatory
            fieldnames   => 1,
            values       => 1,
        }
    );

    my $skeds_folder    = $params{skeds_folder};
    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};

    my $pattern_of_r = _get_patterns( $fieldnames_of_r, $values_of_r );

    my $trip_r = _get_trips(
        patterns   => $pattern_of_r,
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r
    );

    _add_stops_to_patterns( $pattern_of_r, $trip_r );

    $xhea2skedscry->done;
    my $dumpcry = cry('Dumping patterns and trips');
    $dumpcry->prog('patterns...');

    open my $out, '>', '/tmp/xheaout_patterns.2';
    say $out u::dumpstr($pattern_of_r);
    close $out;
    $dumpcry->prog('trips...');
    open $out, '>', '/tmp/xheaout_trips.2';
    say $out u::dumpstr($trip_r);
    close $out;
    $dumpcry->done;

} ## tidy end: sub xhea2skeds

sub _get_patterns {

    my $fieldnames_of_r = shift;
    my $values_of_r     = shift;

    my %pattern_of;

    records_in_turn(
        cry        => 'Processing trip patterns',
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r,
        table      => 'trip_pattern',
        callback   => sub {
            \my %field = shift;
            return unless $field{tpat_in_serv};

            my $line       = $field{tpat_route};
            my $identifier = $field{tpat_id};
            my $uniqid     = "$line.$identifier";

            my $dir_obj = Actium::O::Dir::->instance( $field{tpat_direction} );

            $pattern_of{$uniqid} = Actium::O::Pattern->new(
                line       => $line,
                identifier => $identifier,
                direction  => $dir_obj,
                vdc        => $field{tpat_veh_display},
                via        => $field{tpat_via},
            );
        }
    );

    return \%pattern_of;

} ## tidy end: sub _get_patterns

{
    const my %tripfield_of_day => qw(
      1  trp_operates_mon
      2  trp_operates_tue
      3  trp_operates_wed
      4  trp_operates_thu
      5  trp_operates_fri
      6  trp_operates_sat
      7  trp_operates_sun
    );

    sub _trip_days {

        \my %field = shift;
        my @days;

        foreach my $day ( keys %tripfield_of_day ) {
            push @days, $day if $field{ $tripfield_of_day{$day} };
        }

        return join( $EMPTY, sort @days );

    }

}

sub _get_trips {

    my %params = u::validate(
        @_,
        {   patterns   => 1,
            fieldnames => 1,
            values     => 1,
        }
    );

    my $pattern_of_r    = $params{patterns};
    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};

    my %trip_struct_of;

    records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing trips',
        values     => $values_of_r,
        table      => 'trip',
        callback   => sub {
            \my %field = shift;

            my $days       = _trip_days( \%field );
            my $int_number = $field{trp_int_number};
            my $pattern_id = $field{tpat_route} . '.' . $field{trp_pattern};

            return unless exists $pattern_of_r->{$pattern_id};  # not in service

            $trip_struct_of{$int_number} = {
                days             => $days,
                int_number       => $int_number,
                schedule_daytype => $field{trp_schedule_type},
                pattern_id       => $pattern_id,
                event_and_status => $field{trp_event_and_status},
                op_except        => $field{trp_has_op_except},
            };

            return;

        },
    );

    records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing trip stops',
        values     => $values_of_r,
        table      => 'trip_stop',
        callback   => sub {
            \my %field = shift;

            my $int_number = $field{trp_int_number};
            return unless exists $trip_struct_of{$int_number};  # not in service

            my $time = Actium::O::Time::->from_str( $field{tstp_passing_time} );

            $trip_struct_of{$int_number}{stop}[ $field{tstp_position} - 1 ] = {
                # convert 1-based to 0-based counting
                time             => $time,
                h_stp_511_id     => $field{stp_511_id},
                tstp_place       => $field{tstp_place},
            };

            return;

        },
    );

    records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing trip timepoints',
        values     => $values_of_r,
        table      => 'trip_tp',
        callback   => sub {
            \my %field = shift;

            my $int_number = $field{trp_int_number};
            return unless exists $trip_struct_of{$int_number};  # not in service

            my $time = Actium::O::Time::->from_str( $field{ttp_passing_time} );
            my $next_time
              = Actium::O::Time::->from_str( $field{ttp_pass_time_next} );
            my $prev_time
              = Actium::O::Time::->from_str( $field{ttp_pass_time_prev} );

            $trip_struct_of{$int_number}{place}[ $field{ttp_position} - 1 ] = {
                # convert 1-based to 0-based counting
                ttp_time      => $time,
                ttp_next_time => $next_time,
                ttp_prev_time => $prev_time,
                %field{
                    qw( ttp_is_arrival ttp_is_departure ttp_is_public
                      ttp_next       ttp_place        ttp_prev
                      ),
                }
            };

            return;

        },
    );

    my @trip_structs = values %trip_struct_of;

    my $stop_place_cry = cry('Combining stops and places');

    foreach \my %trip_struct (@trip_structs) {
        \my @places = $trip_struct{place};
        my $stop_idx = 0;
        foreach \my %place (@places) {
            my $place = $place{ttp_place};
            while ( $trip_struct{stop}[$stop_idx]{tstp_place} ne $place ) {
                $stop_idx++;
            }

            foreach my $key ( keys %place ) {
                next if $key eq 'ttp_place' or $key eq 'ttp_time';
                # duplicates tstp_place and 'time' from tstp_passing_time
                $trip_struct{stop}[$stop_idx]{$key} = $place{$key};
            }
            # merge info into stops struct.
            # Should be OK, all have ttp_ in front of their names

        }
        delete $trip_struct{place};

    } ## tidy end: foreach \my %trip_struct (@trip_structs)

    $stop_place_cry->done;

    return \@trip_structs;

} ## tidy end: sub _get_trips

sub records_in_turn {

    my %params = u::validate(
        @_,
        {   table      => 1,
            fieldnames => 1,
            values     => 1,
            callback   => 1,
            cry        => 0,
        }
    );

    my $table           = $params{table};
    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};
    my $callback        = $params{callback};
    my $crytext         = $params{cry};
    my $cry;

    if ($crytext) {
        $cry = cry($crytext);
    }

    my @headers = @{ $fieldnames_of_r->{$table} };
    my @records = @{ $values_of_r->{$table} };

    foreach \my @record(@records) {
        my %field;
        @field{@headers} = @record;

        $callback->( \%field );
    }

    $cry->done;

    return;

} ## tidy end: sub records_in_turn

const my @stopfields => qw(
  h_stp_511_id
  tstp_place
  ttp_is_arrival
  ttp_is_departure
  ttp_is_public
  ttp_prev
  ttp_next
);

sub _add_stops_to_patterns {
    \my %pattern_by_id = shift;
    my $trips_r = shift;

    my $cry = cry('Adding stops and places to patterns');

    my %seen_pattern;

    foreach \my %trip_struct (@$trips_r) {

        my $pattern_id = $trip_struct{pattern_id};
        my @stop_objs;

        foreach \my %stop ( $trip_struct{stop}->@* ) {

            if ( not $seen_pattern{$pattern_id} ) {
                my %stop_values = %stop{@stopfields};
                for ( keys %stop_values ) {
                    delete $stop_values{$_}
                      if not defined $stop_values{$_}
                      or $stop_values{$_} eq $EMPTY;
                }
                push @stop_objs, Actium::O::Pattern::Stop->new(%stop_values);
            }

            delete @stop{@stopfields};
            # Remove duplicate info

        }

        if ( not $seen_pattern{$pattern_id} ) {

            # move duplicate info to pattern from stops
            my $pattern = $pattern_by_id{$pattern_id};

            $pattern->_set_stop_objs_r( \@stop_objs );

            $seen_pattern{$pattern_id}++;
        }

    } ## tidy end: foreach \my %trip_struct (@$trips_r)

    $cry->done;

    return;

} ## tidy end: sub _add_stops_to_patterns

1;

__END__




my %dircode_of_xhea = (
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

    trippatternstops => [
        qw<stp_511_id tpat_stp_rank tpat_stp_plc tpat_stp_tp_sequence>,
        'item tpat_id', 'item tpat_route',
    ],
    places => [
        qw[plc_identifier      plc_description
          plc_reference_place plc_district plc_number],
    ],
    trips => [
        qw<trp_int_number trp_route trp_pattern trp_is_in_service
          trp_blkng_day_digits trp_event>
    ],
    tripstops => [qw<trp_int_number tstp_position tstp_passing_time>],
);

sub xhea2skeds {

    my %params = u::validate(
        @_,
        {   signup          => 1,
            xhea_tab_folder => 1,
        }
    );

    my $signup          = $params{signup};
    my $xhea_tab_folder = $params{xhea_tab_folder};

    my ( $patterns_r, $pat_lineids_of_lgdir_r, $upattern_of_r, $uindex_of_r )
      = _get_patterns($xhea_tab_folder);

    my $trips_of_skedid_r
      = xhea_trips( $xhea_tab_folder, $pat_lineids_of_lgdir_r, $uindex_of_r );

    my $places_info_of_r = _load_places($xhea_tab_folder);

    my @skeds
      = _make_skeds( $trips_of_skedid_r, $upattern_of_r, $places_info_of_r );

    _output_debugging_patterns( $signup, $patterns_r, $pat_lineids_of_lgdir_r,
        $upattern_of_r, $uindex_of_r, \@skeds );

    _output_skeds( $signup, \@skeds );

    return @skeds;

} ## tidy end: sub xhea2skeds

my $stop_tiebreaker = sub {

    # tiebreaks by using the average rank of the timepoints involved.

    my @lists = @_;
    my @avg_ranks;

    foreach my $i ( 0, 1 ) {

        my @ranks;
        foreach my $stop ( @{ $lists[$i] } ) {
            my ( $stopid, $placeid, $placerank ) = split( /:/s, $stop );
            if ( defined $placerank ) {
                push @ranks, $placerank;
            }
        }
        return 0 unless @ranks;
        # if either list has no timepoints, return 0 indicating we can't break
        # the tie

        $avg_ranks[$i] = u::sum(@ranks) / @ranks;

    }

    return $avg_ranks[0] <=> $avg_ranks[1];

};

const my @requiredheaders_trippatterns => (
    qw<tpat_route tpat_id tpat_direction
      tpat_in_serv tpat_via tpat_trips_match>
);

const my @requiredheaders_tpstops => (
    qw<stp_511_id tpat_stp_rank tpat_stp_plc tpat_stp_tp_sequence>,
    'item tpat_id', 'item tpat_route',
);

sub _get_patterns {
    my $xhea_tab_folder = shift;
    my %patterns;
    my %pat_lineids_of_lgdir;

    my $load_cry = cry('Loading and assembling XHEA patterns');

    my $read_cry = cry('Reading XHEA trippattern files');

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};
        # skip if this trip isn't in service, or if it has no active trips
        # tpat_trips_match is unreliable!!!

        my $tpat_line = $value_of_r->{tpat_route};
        my $tpat_id   = $value_of_r->{tpat_id};

        my $lineid = $tpat_line . "_$tpat_id";
        return if exists $patterns{$lineid};    # duplicate

        my $tpat_direction = $value_of_r->{tpat_direction};
        my $direction      = $dircode_of_xhea{$tpat_direction};
        if ( not defined $direction ) {
            $direction = $tpat_direction;
            $read_cry->text("Unknown direction: $tpat_direction");
        }
        my $lgdir = linegroup_of( ${tpat_line} ) . "_$direction";

        push @{ $pat_lineids_of_lgdir{$lgdir} }, $lineid;

        $patterns{$lineid}[P_DIRECTION] = $direction;
        $patterns{$lineid}[P_VDC] = $value_of_r->{tpat_veh_display} // $EMPTY;
        $patterns{$lineid}[P_VIA] = $value_of_r->{tpat_via} // $EMPTY;

        return;

    };

    read_tab_files(
        {   globpatterns     => ['*trip_pattern.txt'],
            folder           => $xhea_tab_folder,
            required_headers => \@requiredheaders_trippatterns,
            callback         => $patfile_callback,
        }
    );

    $read_cry->done;

    my $tps_cry = cry('Reading XHEA trippatternstops files');

    my $patstopfile_callback = sub {
        my $value_of_r = shift;

        my $tpat_line = $value_of_r->{'item tpat_route'};
        my $tpat_id   = $value_of_r->{'item tpat_id'};

        my $lineid = $tpat_line . "_$tpat_id";

        return unless exists $patterns{$lineid};

        my @stop = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @stop, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$lineid}[P_STOPS][$tpat_stp_rank] = \@stop;

        $patterns{$lineid}[P_PLACES]{$tpat_stp_tp_sequence} = $tpat_stp_plc
          if $tpat_stp_tp_sequence;

        return;

    };

    read_tab_files(
        {   globpatterns     => ['*trippatternstops.txt'],
            folder           => $xhea_tab_folder,
            required_headers => $required_headers{'trippatternstops'},
            callback         => $patstopfile_callback,
        }
    );

    $tps_cry->done;

    my $unipatcry = cry('Making unified patterns for each direction');

    my ( %upattern_of, %uindex_of );

    foreach my $lgdir ( keys %pat_lineids_of_lgdir ) {

        my @lineids = @{ $pat_lineids_of_lgdir{$lgdir} };

        my %stop_set_of_lineid;
        foreach my $lineid (@lineids) {

            next unless $patterns{$lineid}[P_STOPS];

            # skip making the pattern if there aren't any stops for that
            # pattern

            my @stop_set;
            foreach my $stop ( @{ $patterns{$lineid}[P_STOPS] } ) {
                push @stop_set, join( ':', @{$stop} );
            }
            $stop_set_of_lineid{$lineid} = \@stop_set;
        }

        my %returned = ordered_union_columns(
            sethash    => \%stop_set_of_lineid,
            tiebreaker => $stop_tiebreaker,
        );

        $upattern_of{$lgdir} = $returned{union};

        foreach my $lineid (@lineids) {
            $uindex_of{$lineid} = $returned{columns_of}{$lineid};
        }

    } ## tidy end: foreach my $lgdir ( keys %pat_lineids_of_lgdir)

    $unipatcry->done;

    $load_cry->done;

    return \%patterns, \%pat_lineids_of_lgdir, \%upattern_of, \%uindex_of;

} ## tidy end: sub _get_patterns

sub _load_places {
    my $xhea_tab_folder = shift;
    my %place_info_of;

    my $cry = cry('Reading XHEA place files');

    my $place_callback = sub {
        my $value_of_r   = shift;
        my $this_place_r = [];

        $this_place_r->[PL_DESCRIP]   = $value_of_r->{plc_description};
        $this_place_r->[PL_REFERENCE] = $value_of_r->{plc_reference_place};
        $this_place_r->[PL_CITYCODE]  = $value_of_r->{plc_district};
        $this_place_r->[PL_PLACE8]    = $value_of_r->{plc_number};
        $place_info_of{ $value_of_r->{plc_identifier} } = $this_place_r;

        return;
    };

    read_tab_files(
        {   globpatterns     => ['*places.txt'],
            folder           => $xhea_tab_folder,
            required_headers => $required_headers{'places'},
            callback         => $place_callback,
        }
    );

    $cry->done;

    return \%place_info_of;

} ## tidy end: sub _load_places

sub _make_skeds {
    my $trips_of_skedid_r = shift;
    my $upattern_of_r     = shift;
    my $places_r          = shift;

    my @skeds;

    my $cry = cry("Making Actium::O::Sked objects");

    foreach my $skedid ( sortbyline keys %{$trips_of_skedid_r} ) {

        $cry->over($skedid);

        my ( $lg, $dir, $days ) = split( /_/s, $skedid );
        my $lgdir    = "${lg}_$dir";
        my $upattern = $upattern_of_r->{$lgdir};
        my ( @stops, @place4s, @stopplaces );

        foreach my $stop ( @{$upattern} ) {
            my ( $stopid, $placeid, $placerank ) = split( /:/s, $stop );

            push @stops, $stopid;

            if ($placeid) {
                push @stopplaces, $placeid;
                my $reference_place = $places_r->{$placeid}[PL_REFERENCE];
                $placeid = $reference_place if $reference_place;
                push @place4s, $placeid;
            }
            else {
                push @stopplaces, $EMPTY_STR;
            }

        }

        my @place8s = map { $places_r->{$_}[PL_PLACE8] } @place4s;

        my $sked_attributes_r = {
            linegroup   => $lg,
            place4_r    => \@place4s,
            place8_r    => \@place8s,
            stopid_r    => \@stops,
            stopplace_r => \@stopplaces,
            direction   => Actium::O::Dir->instance($dir),
            days        => Actium::O::Days->instance($days),
            trip_r      => $trips_of_skedid_r->{$skedid},
        };

        my $sked = Actium::O::Sked->new($sked_attributes_r);

        push @skeds, $sked;

    } ## tidy end: foreach my $skedid ( sortbyline...)

    $cry->done;

    return @skeds;

} ## tidy end: sub _make_skeds

sub xhea_trips {

    my $cry = cry("Loading XHEA trips into trip objects");

    my $xheafolder             = shift;
    my $pat_lineids_of_lgdir_r = shift;
    my $uindex_of_r            = shift;

    my $tripstructs_of_lineid_r = _load_trips_from_file($xheafolder);

    my $trips_of_lgdir_r
      = _make_trip_objs( $pat_lineids_of_lgdir_r, $tripstructs_of_lineid_r,
        $uindex_of_r );

    my $trips_of_sked_r = _get_trips_of_sked($trips_of_lgdir_r);

    $cry->done;

    return $trips_of_sked_r;

} ## tidy end: sub xhea_trips

sub _load_trips_from_file {
    my $xheafolder = shift;
    my $cry        = cry('Reading XHEA trip files');

    my %trip_of_tnum;
    my %tnums_of_lineid;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $line    = $value_of_r->{trp_route};
        my $pattern = $value_of_r->{trp_pattern};

        my $lineid = $line . '_' . $pattern;

        push @{ $tnums_of_lineid{$lineid} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $event = $value_of_r->{trp_event};

        my $daydigits = $value_of_r->{trp_blkng_day_digits};

        if ( $daydigits =~ s/0/7/sg ) {
            $daydigits = j( sort split( //s, $daydigits ) );
        }

        my $days_obj = _make_days_obj( $daydigits, $event );

        $trip_of_tnum{$tnum}[T_DAYSEXCEPTIONS] = $event;

        $trip_of_tnum{$tnum}[T_PATTERN] = $pattern;
        $trip_of_tnum{$tnum}[T_LINE]    = $line;
        $trip_of_tnum{$tnum}[T_TYPE]    = $value_of_r->{trp_type};
        $trip_of_tnum{$tnum}[T_DAYS]    = $days_obj;
        $trip_of_tnum{$tnum}[T_INTNUM]  = $tnum;

    };

    read_tab_files(
        {   globpatterns     => ['*trips.txt'],
            folder           => $xheafolder,
            required_headers => $required_headers{'trips'},
            callback         => $trip_callback,
        }
    );

    $cry->done;

    my $tripstop_cry = cry('Reading XHEA trip stop (time) files');

    my $tripstops_callback = sub {
        my $value_of_r = shift;
        my $tnum       = $value_of_r->{trp_int_number};

        return unless exists $trip_of_tnum{$tnum};

        $trip_of_tnum{$tnum}[T_TIMES][ $value_of_r->{tstp_position} - 1 ]
          = $value_of_r->{tstp_passing_time};

    };

    read_tab_files(
        {   globpatterns     => ['*tripstops.txt'],
            folder           => $xheafolder,
            required_headers => $required_headers{'tripstops'},
            callback         => $tripstops_callback,
        }
    );

    $cry->done;

    my %trips_of_lineid;
    foreach my $lineid ( keys %tnums_of_lineid ) {
        foreach my $tnum ( @{ $tnums_of_lineid{$lineid} } ) {
            push @{ $trips_of_lineid{$lineid} }, $trip_of_tnum{$tnum};
        }
    }

    return \%trips_of_lineid;

} ## tidy end: sub _load_trips_from_file

sub _make_days_obj {

    my $day_digits = shift;
    my $trp_event  = shift;

    $day_digits =~ s/0/7H/s;
    # Thea uses 0 instead of 7 for Sunday, as Hastus Standard AVL did.
    # TODO - Figure out more universal way of determining holidays

    $day_digits = j( sort ( split( //s, $day_digits ) ) );
    # sort $xheaday by characters - putting 7 at end

    my $schooldaycode
      = $trp_event eq 'SD' ? 'D'
      : $trp_event eq 'SH' ? 'H'
      :                      'B';

    return Actium::O::Days->instance( $day_digits, $schooldaycode );
}

sub _make_trip_objs {
    my $pat_lineids_of_lgdir_r = shift;
    my $trips_of_lineid_r      = shift;
    my $uindex_of_r            = shift;

    my %trips_of_lgdir;

    # so the idea here is to go through each trip, and create a new
    # trip struct in trips_of_lgdir that has the various information,
    # putting the times in the correct column as in uindex_of_r.

    # Then we turn them into objects, and sort the objects.

    my $cry
      = cry('Making Trip objects (padding out columns, merging double trips)');

    foreach my $lgdir ( sortbyline keys %{$pat_lineids_of_lgdir_r} ) {

        $cry->over($lgdir);

        my $trip_objs_r;
        my @lineids = @{ $pat_lineids_of_lgdir_r->{$lgdir} };

        foreach my $lineid (@lineids) {

            foreach my $trip_r ( @{ $trips_of_lineid_r->{$lineid} } ) {

                my $unified_trip_r = [ @{$trip_r} ];
                # copy everything

                my @times = @{ $trip_r->[T_TIMES] };

                my @unified_times;

                for my $old_column_idx ( 0 .. $#times ) {

                    my $new_column_idx
                      = $uindex_of_r->{$lineid}[$old_column_idx];

                    $unified_times[$new_column_idx] = $times[$old_column_idx];

                }

                $unified_trip_r->[T_TIMES] = \@unified_times;

                push @{$trip_objs_r}, _tripstruct_to_tripobj($unified_trip_r);

            } ## tidy end: foreach my $trip_r ( @{ $trips_of_lineid_r...})

        } ## tidy end: foreach my $lineid (@lineids)
        $trip_objs_r = Actium::O::Sked::Trip->stoptimes_sort( @{$trip_objs_r} );

        $trip_objs_r = Actium::O::Sked::Trip->merge_trips_if_same(
            {   trips => $trip_objs_r,
                methods_to_compare =>
                  [qw <stoptimes_comparison_str sortable_days>]
            }
        );
        # merges double trips -- some trips (mostly school trips) have so many
        # passengers we send two buses out. Scheduling system has to have these
        # twice, but we only want to display them once

        $trips_of_lgdir{$lgdir} = $trip_objs_r;

    } ## tidy end: foreach my $lgdir ( sortbyline...)

    $cry->done;

    return \%trips_of_lgdir;

} ## tidy end: sub _make_trip_objs

sub _tripstruct_to_tripobj {
    my $tripstruct = shift;

    return Actium::O::Sked::Trip->new(
        {   days           => $tripstruct->[T_DAYS],
            vehicletype    => $tripstruct->[T_VEHICLE],
            stoptime_r     => $tripstruct->[T_TIMES],
            daysexceptions => $tripstruct->[T_DAYSEXCEPTIONS],
            type           => $tripstruct->[T_TYPE],
            pattern        => $tripstruct->[T_PATTERN],
            line           => $tripstruct->[T_LINE],
            internal_num   => $tripstruct->[T_INTNUM],
            # DAYSDIGITS - no attribute in Actium::O::Sked::Trip,
            # but incorporated in days
        }
    );

}

sub _get_trips_of_sked {

    my $trips_of_lgdir_r = shift;
    my %trips_of_sked;

    my $cry = cry("Assembling trips into schedules by day");

    foreach my $lgdir ( sortbyline keys %{$trips_of_lgdir_r} ) {

        $cry->over($lgdir);

        # first, this separates them out by individual days.
        # then, it reassembles them in groups.
        # The reason for this is that sometimes we end up getting
        # weird sets of days across the schedules we receive
        # (e.g., same trips Fridays and Saturdays)
        # and it's easier to do it this way if that's the case.

        #my $trips_of_day_r
        #  = _get_trips_by_day( $trips_of_lgdir_r->{$lgdir} );

        my $trips_r = $trips_of_lgdir_r->{$lgdir};

        my %trips_of_day;

        foreach my $trip ( @{$trips_r} ) {
            my @days = split( //s, $trip->daycode );
            foreach my $day (@days) {
                push @{ $trips_of_day{$day} }, $trip;
            }
        }

        my $trips_of_skedday_r = _assemble_skeddays( \%trips_of_day );

        for my $skedday ( keys %{$trips_of_skedday_r} ) {

            my $skedid = "${lgdir}_$skedday";
            $trips_of_sked{$skedid} = $trips_of_skedday_r->{$skedday};

        }

    } ## tidy end: foreach my $lgdir ( sortbyline...)

    $cry->done;

    return \%trips_of_sked;

} ## tidy end: sub _get_trips_of_sked

sub _assemble_skeddays {
    my $trips_of_day_r = shift;
    my @days           = sort keys %{$trips_of_day_r};
    my ( %already_found_day, %trips_of_skedday );

    # Go through list of days. Compare the first one to the subsequent ones.
    # If any of the subsequent ones are identical to the first day, mark them
    # as such, and put them as part of the original list.

    foreach my $i ( 0 .. $#days ) {
        my $outer_day = $days[$i];
        next if $already_found_day{$outer_day};
        my @found_days = $outer_day;

        my $found_trips_r = $trips_of_day_r->{$outer_day};

        for my $j ( $i + 1 .. $#days ) {
            my $inner_day = $days[$j];
            next if $already_found_day{$inner_day};

            my $inner_trips_r = $trips_of_day_r->{$inner_day};

            if ( my $merged_trips_r
                = _merge_if_appropriate( $found_trips_r, $inner_trips_r ) )
            {
                push @found_days, $inner_day;
                $found_trips_r = $merged_trips_r;
                $already_found_day{$inner_day} = $outer_day;
            }
        }

        # so @found_days now has all the days that are identical to
        # the outer day

        my $skedday = j(@found_days);
        $trips_of_skedday{$skedday} = $found_trips_r;

    } ## tidy end: foreach my $i ( 0 .. $#days)

    return \%trips_of_skedday;

} ## tidy end: sub _assemble_skeddays

const my $MAXIMUM_DIFFERING_TIMES  => 4;
const my $MINIMUM_TIMES_MULTIPLIER => 5;

sub _merge_if_appropriate {

    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    my $outer_count = scalar @{$outer_trips_r};
    my $inner_count = scalar @{$inner_trips_r};

    # Are the quantities so different that there's no point comparing them?

    my $difference = abs( $outer_count - $inner_count );

    return if $difference > $MAXIMUM_DIFFERING_TIMES;

    # check to see if all the trips themselves are the same object.
    # This will frequently be the case

    return $outer_trips_r
      if ( not $difference
        and _trips_are_identical( $outer_trips_r, $inner_trips_r ) );

    ## now check if times are the same even if trips are not
    ## identical (as with Saturday/Sunday). First, make lists of times

    my @outer_times = map { $_->stoptimes_comparison_str } @{$outer_trips_r};
    my @inner_times = map { $_->stoptimes_comparison_str } @{$inner_trips_r};

    # Then compare them using List::Compare

    my $compare = List::Compare->new(
        {   lists       => [ \@outer_times, \@inner_times ],
            unsorted    => 1,
            accelerated => 1,
        }
    );

    my $only_in_either = scalar( $compare->get_symmetric_difference );

    # if all the trips have identical times, then merge them

    if ( not $only_in_either ) {

        my @merged_trips;
        for my $i ( 0 .. $#outer_times ) {

            push @merged_trips,
              $outer_trips_r->[$i]->merge_trips( $inner_trips_r->[$i] );

        }

        return \@merged_trips;

    }

    # if they are *almost* identical -- that is, 4 or fewer differing
    # times, and the number of times is at least 5 times the number of
    # differing ones, then merge them

    # In weird situations where, for example, you have several different sets --
    # -- 30 trips that are every day, plus two separate ones on Monday,
    # two separate ones on Tuesday, two separate ones on Wednesday,
    # etc. -- this will give inconsistent results, with Monday's
    # and Tuesday's trips combined but Wednesday's not.
    # To do that you'd need to compare them all to each other simultaneously,
    # which code I am not prepared to write at this point.

    my $in_both = ( u::max( $inner_count, $outer_count ) ) - $only_in_either;

    if (    $only_in_either <= $MAXIMUM_DIFFERING_TIMES
        and $in_both > ( $MINIMUM_TIMES_MULTIPLIER * $only_in_either ) )
    {
        my $trips_to_merge_r
          = Actium::O::Sked::Trip->stoptimes_sort( @{$outer_trips_r},
            @{$inner_trips_r} );

        return Actium::O::Sked::Trip->merge_trips_if_same(
            {   trips              => $trips_to_merge_r,
                methods_to_compare => ['stoptimes_comparison_str'],
            }
        );

    }

    # no merging

    return;

} ## tidy end: sub _merge_if_appropriate

sub _trips_are_identical {
    my $outer_trips_r = shift;
    my $inner_trips_r = shift;

    for my $i ( 0 .. $#{$outer_trips_r} ) {
        return unless $outer_trips_r->[$i] == $inner_trips_r->[$i];
    }

    return 1;

}

###################
##### OUTPUT ######
###################

sub _output_skeds {
    # should be moved to a SkedCollection object

    use autodie;
    my $signup  = shift;
    my $skeds_r = shift;

    my $objfolder = $signup->subfolder('s/json_obj');
    $objfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'json',
        EXTENSION => 'json',
    );

    my $xlsxfolder = $signup->subfolder('s/xlsx');
    $xlsxfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'xlsx',
        EXTENSION => 'xlsx',
    );

    my $spacedfolder = $signup->subfolder('s/spaced');
    $spacedfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'spaced',
        EXTENSION => 'txt',
    );

    Actium::O::Sked->write_prehistorics( $skeds_r, $signup );

} ## tidy end: sub _output_skeds

sub _output_debugging_patterns {

    use autodie;
    ## no critic (RequireCheckedSyscalls)

    my $signup                 = shift;
    my $patterns_r             = shift;
    my $pat_lineids_of_lgdir_r = shift;
    my $upattern_of_r          = shift;
    my $uindex_of_r            = shift;
    my $skeds_r                = shift;

    my $debugfolder = $signup->subfolder('xhea_debug');

    my $dumpfolder = $debugfolder->subfolder('dump');
    $dumpfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'dump',
        EXTENSION => 'dump',
    );

    my $ufh = $debugfolder->open_write('xhea_upatterns.txt');

    foreach my $lgdir ( sortbyline keys %{$pat_lineids_of_lgdir_r} ) {
        my @lineids = @{ $pat_lineids_of_lgdir_r->{$lgdir} };
        say $ufh "\n$lgdir";
        say $ufh join( "\t", @{ $upattern_of_r->{$lgdir} } );
        foreach my $lineid (@lineids) {
            say $ufh $lineid;
            say $ufh join( "\t", @{ $uindex_of_r->{$lineid} } );

            my @stopinfos = @{ $patterns_r->{$lineid}[P_STOPS] };
            my @stops;
            foreach my $stopinfo (@stopinfos) {
                my $text = shift @{$stopinfo};
                if ( scalar @{$stopinfo} ) {
                    my $plc = shift @{$stopinfo};
                    my $seq = shift @{$stopinfo};
                    $text .= ":$plc:$seq";
                }
                push @stops, $text;

            }
            my $stops = join( "\t", @stops );

            my %places = %{ $patterns_r->{$lineid}[ P_PLACES() ] };
            my @places;

            foreach my $seq ( sort { $a <=> $b } keys %places ) {
                push @places, "$seq:$places{$seq}";
            }
            my $places = join( "\t", @places );

            say $ufh "$stops\n$places";

        } ## tidy end: foreach my $lineid (@lineids)

    } ## tidy end: foreach my $lgdir ( sortbyline...)

    close $ufh or die "Can't close xhea_upatterns.txt: $OS_ERROR";

    ##use critic

} ## tidy end: sub _output_debugging_patterns

1;

__END__

BUGS AND LIMITATIONS

Still to do: linegroup combining
