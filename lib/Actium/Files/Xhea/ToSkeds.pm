package Actium::Files::Xhea::ToSkeds 0.012;

use Actium::Preamble;
use Actium::Files::TabDelimited 'read_aoas';
use Actium::O::Dir;
use Actium::O::Time;
use Actium::O::Pattern;
use Actium::O::Pattern::Block;
use Actium::O::Pattern::Group;
use Actium::O::Pattern::Stop;
use Actium::O::Pattern::Trip;

const my @required_tables => (qw/ppat block trip trip_pattern trip_stop/);

sub xheatab2skeds {

    my $tabcry = cry("Loading xhea tab files...");

    my %params = u::validate(
        @_,
        {   skeds_folder    => 1,
            xhea_tab_folder => 1,
            actiumdb        => 1,
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
        actiumdb     => $params{actiumdb},
        fieldnames   => $fieldnames_of_r,
        values       => $values_of_r
    );

} ## tidy end: sub xheatab2skeds

sub xhea2skeds {

    my $xhea2skedscry = cry('Converting Xhea to schedules');

    my %params = u::validate(
        @_,
        {   skeds_folder => 1,
            actiumdb     => 1,
            fieldnames   => 1,
            values       => 1,
        }
    );

    my $skeds_folder    = $params{skeds_folder};
    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};
    my $actiumdb        = $params{actiumdb};

    my $blocks_by_id_r = _get_blocks(
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r,
    );

    my ( $pattern_by_id_r, $patterns_by_linedir_r, $patgroup_by_lgdir_r )
      = _get_patterns(
        actiumdb   => $actiumdb,
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r
      );

    _get_trips(
        blocks     => $blocks_by_id_r,
        patterns   => $pattern_by_id_r,
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r,
    );

    _add_place_patterns_to_patterns(
        fieldnames          => $fieldnames_of_r,
        patterns_by_linedir => $patterns_by_linedir_r,
        values              => $values_of_r
    );

    my $dumpcry = cry('Dumping patterns and trips');
    open my $dump_out, '>', '/tmp/xheaout.6';
    say $dump_out u::dumpstr( $patgroup_by_lgdir_r );
    close $dump_out;
    $dumpcry->done;

    #\my @skeds
    my $trip_collections  # debug
      = _make_skeds( patgroups => $patgroup_by_lgdir_r, actiumdb => $actiumdb )
      ;
    
    my $tdumpcry = cry('Dumping trip collections');
    open my $tdump_out, '>', '/tmp/xheaout.t6';
    say $tdump_out u::dumpstr( $trip_collections) ;
    close $tdump_out;
    $tdumpcry->done; 
    

    $xhea2skedscry->done;

} ## tidy end: sub xhea2skeds

#####################
### GET BLOCKS

sub _get_blocks {

    my %params = u::validate(
        @_,
        {   fieldnames => 1,
            values     => 1,
        }
    );

    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};

    my %blocks_by_id;

    _records_in_turn(
        cry        => 'Processing blocks ',
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r,
        table      => 'block',
        callback   => sub {
            \my %field = shift;

            my $block_id = $field{blk_number};

            my $block = Actium::O::Pattern::Block->new(
                block_id      => $block_id,
                vehicle_group => $field{blk_vehicle_group},
                vehicle_type  => $field{blk_vehicle_type},
            );

            $blocks_by_id{$block_id} = $block;

        }

    );

    return \%blocks_by_id;
} ## tidy end: sub _get_blocks

#####################
### GET PATTERNS

{

    my %line_cache;

    my $linegroup_cr = sub {
        my $line = shift;
        my $linegroup = $line_cache{$line}{LineGroup} || $line;
    };

    sub _get_patterns {

        my %params = u::validate(
            @_,
            {   actiumdb   => 1,
                fieldnames => 1,
                values     => 1,
            }
        );

        my $fieldnames_of_r = $params{fieldnames};
        my $values_of_r     = $params{values};
        %line_cache = $params{actiumdb}->line_cache;

        my ( %pattern_by_id, %patterns_by_linedir, %patgroup_by_lgdir );

        _records_in_turn(
            cry        => 'Processing trip patterns',
            fieldnames => $fieldnames_of_r,
            values     => $values_of_r,
            table      => 'trip_pattern',
            callback   => sub {
                \my %field = shift;
                return unless $field{tpat_in_serv};

                my $line       = $field{tpat_route};
                my $linegroup  = $linegroup_cr->($line);
                my $identifier = $field{tpat_id};
                my $uniqid     = "$line.$identifier";

                my $dir_obj
                  = Actium::O::Dir::->instance( $field{tpat_direction} );

                my $pattern = Actium::O::Pattern->new(
                    line       => $line,
                    linegroup  => $linegroup,
                    identifier => $identifier,
                    direction  => $dir_obj,
                    vdc        => $field{tpat_veh_display},
                    via        => $field{tpat_via},
                );
                $pattern_by_id{ $pattern->unique_id } = $pattern;

                push $patterns_by_linedir{ $pattern->linedir }->@*, $pattern;

                my $lgdir = $pattern->lgdir;
                if ( not exists $patgroup_by_lgdir{$lgdir} ) {
                    $patgroup_by_lgdir{$lgdir}
                      = Actium::O::Pattern::Group->new(
                        linegroup => $linegroup,
                        direction => $dir_obj,
                      );
                }

                $patgroup_by_lgdir{$lgdir}->add_pattern($pattern);

            }
        );

        return ( \%pattern_by_id, \%patterns_by_linedir, \%patgroup_by_lgdir );

    } ## tidy end: sub _get_patterns

}

#####################
### GET TRIPS

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
            blocks     => 1,
            values     => 1,
        }
    );

    \my %pattern_by_id = $params{patterns};
    \my %block_by_id   = $params{blocks};
    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};

    my ( %trip_by_internal, %pattern_id_of_trip_number );

    _records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing trips',
        values     => $values_of_r,
        table      => 'trip',
        callback   => sub {
            \my %field = shift;

            my $days       = _trip_days( \%field );
            my $int_number = $field{trp_int_number};
            my $pattern_id = $field{tpat_route} . '.' . $field{trp_pattern};

            return unless exists $pattern_by_id{$pattern_id};
            # not in service

            my $block = $block_by_id{ $field{trp_block} };

            my $trip = Actium::O::Pattern::Trip->new(
                days             => $days,
                int_number       => $int_number,
                schedule_daytype => $field{trp_schedule_type},
                pattern_id       => $pattern_id,
                event_and_status => $field{trp_event_and_status},
                op_except        => $field{trp_has_op_except},
                block_id         => $field{trp_block},
                vehicle_group    => $block->vehicle_group,
                vehicle_type     => $block->vehicle_type,
            );

            $pattern_by_id{$pattern_id}->add_trip($trip);

            $trip_by_internal{$int_number}          = $trip;
            $pattern_id_of_trip_number{$int_number} = $pattern_id;

            return;

        },
    );

    _records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing trip stops',
        values     => $values_of_r,
        table      => 'trip_stop',
        callback   => sub {
            \my %field = shift;

            my $int_number = $field{trp_int_number};
            return unless exists $trip_by_internal{$int_number};
            # not in service

            my $trip       = $trip_by_internal{$int_number};
            my $pattern_id = $pattern_id_of_trip_number{$int_number};
            my $pattern    = $pattern_by_id{$pattern_id};

            my $time = Actium::O::Time::->from_str( $field{tstp_passing_time} );
            my $stop_position = $field{tstp_position} - 1;
            # convert 1-based to 0-based counting

            $trip->set_stoptime( $stop_position, $time );

            my $pattern_stop = $pattern->stop_obj($stop_position);
            if ( not defined $pattern_stop ) {

                my %stop_spec = ( h_stp_511_id => $field{stp_511_id} );
                $stop_spec{tstp_place} = $field{tstp_place}
                  if $field{tstp_place};
                my $stop_obj = Actium::O::Pattern::Stop->new(%stop_spec);
                $pattern->set_stop_obj( $stop_position, $stop_obj );

            }

            return;

        },
    );

### NONE OF THESE DATA ARE WORTH COLLECTING ####

#    _records_in_turn(
#        fieldnames => $fieldnames_of_r,
#        cry        => 'Processing trip places',
#        values     => $values_of_r,
#        table      => 'trip_tp',
#        callback   => sub {
#            \my %field = shift;
#
#            my $int_number = $field{trp_int_number};
#            return unless exists $trip_by_internal{$int_number};
#            # not in service
#            my $trip       = $trip_by_internal{$int_number};
#            my $pattern_id = $pattern_id_of_trip_number{$int_number};
#            my $pattern    = $pattern_by_id{$pattern_id};
#
#            my $ttp_position = $field{ttp_position} - 1;
#            # convert 1-based to 0-based counting
#
#            my $pattern_place = $pattern->place_obj($ttp_position);
#
#            if ( not defined $pattern_place ) {
#
#                my $place_obj = Actium::O::Pattern::Place->new(
#                    %field{
#                        qw( ttp_place ttp_is_arrival
#                          ttp_is_departure ttp_is_public )
#                    }
#                );
#                $pattern->set_place_obj( $ttp_position, $place_obj );
#
#            }
#
#            return;
#
#        },
#    );
#
#    my $stop_place_cry = cry('Combining stops and places');
#
#    foreach my $pattern ( values %pattern_by_id ) {
#
#        my @place_objs = $pattern->place_objs;
#        my $stop_idx   = 0;
#        foreach my $place_obj (@place_objs) {
#            my $place      = $place_obj->ttp_place;
#            my $stop_place = $pattern->stop_obj($stop_idx)->tstp_place;
#            while ( not defined $stop_place or $stop_place ne $place ) {
#                $stop_idx++;
#                $stop_place = $pattern->stop_obj($stop_idx)->tstp_place;
#            }
#
#            $pattern->stop_obj($stop_idx)->set_place_obj($place_obj);
#
#        }
#
#    }
#
#    $stop_place_cry->done;

return;

} ## tidy end: sub _get_trips

########################
### GET PLACE PATTERNS

sub _add_place_patterns_to_patterns {
    my %params = u::validate(
        @_,
        {   fieldnames          => 1,
            patterns_by_linedir => 1,
            values              => 1,
        }
    );

    my $fieldnames_of_r = $params{fieldnames};
    my $values_of_r     = $params{values};
    \my %patterns_by_linedir = $params{patterns_by_linedir};

    my %ppat_of_linedir;

    _records_in_turn(
        fieldnames => $fieldnames_of_r,
        cry        => 'Processing place patterns',
        values     => $values_of_r,
        table      => 'ppat',
        callback   => sub {
            \my %field = shift;
            my ( $place, $rank ) = @field{qw/place rank/};
            my $direction = Actium::O::Dir->instance( $field{direction} );
            my $linedir   = $direction->linedir( $field{line} );
            $ppat_of_linedir{$linedir}->[$rank] = $place;
            return;
        },
    );

    my $ppat_stop_cry = cry('Adding place pattern ranks to pattern stops');

    foreach my $linedir ( keys %ppat_of_linedir ) {
        \my @ppat_entries = $ppat_of_linedir{$linedir};

      PATTERN:
        foreach my $pattern ( $patterns_by_linedir{$linedir}->@* ) {
            my $ppat_rank = 0;
          STOP:
            foreach my $stop ( $pattern->stop_objs ) {
                next STOP unless $stop->has_place;
                my $stop_place = $stop->tstp_place;
                my $ppat_place = $ppat_entries[$ppat_rank];
                while ( $stop_place ne $ppat_place
                    and $ppat_rank < $#ppat_entries )
                {
                    $ppat_rank++;
                    $ppat_place = $ppat_entries[$ppat_rank];
                }
                next PATTERN if $ppat_place ne $stop_place;
                $stop->set_place_rank($ppat_rank);
                $ppat_rank++;
            }

        }
    } ## tidy end: foreach my $linedir ( keys ...)

    $ppat_stop_cry->done;
    return;

} ## tidy end: sub _add_place_patterns_to_patterns

####################
### READ RECORDS

sub _records_in_turn {

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

} ## tidy end: sub _records_in_turn

#################
##### MAKE SKEDS

sub _make_skeds {

    my %params = u::validate(
        @_,
        {   actiumdb  => 1,
            patgroups => 1,
        }
    );

    \my %patgroup_by_lgdir = $params{patgroups};

    my @skeds;
    foreach my $patgroup ( values %patgroup_by_lgdir ) {
        push @skeds, $patgroup->skeds( $params{actiumdb} );
    }

    return \@skeds;

}

1;

__END__


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
