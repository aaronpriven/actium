package Octium::Import::Xhea::ToSkeds 0.012;

use Actium;
use Octium;
use Octium::Storage::TabDelimited 'read_aoas';
use Octium::Dir;
use Actium::Time;
use Octium::Pattern;
use Octium::Pattern::Block;
use Octium::Pattern::Group;
use Octium::Pattern::Stop;
use Octium::Pattern::Trip;
use Octium::Sked::Collection;

use Params::Validate;

const my @required_tables => (qw/ppat block trip trip_pattern trip_stop/);

sub xheatab2skeds {

    my $tabcry = env->cry("Loading xhea tab files...");

    my %params = validate(
        @_,
        {   signup   => 1,
            actiumdb => 1,
        }
    );
    my $signup = $params{signup};

    my $xhea_tab_folder = $signup->subfolder( 'xhea', 'tab' );

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
        signup     => $signup,
        actiumdb   => $params{actiumdb},
        fieldnames => $fieldnames_of_r,
        values     => $values_of_r
    );

}

sub xhea2skeds {

    my $xhea2skedscry = env->cry('Converting Xhea to schedules');

    my %params = validate(
        @_,
        {   signup     => 1,
            actiumdb   => 1,
            fieldnames => 1,
            values     => 1,
        }
    );

    my $signup          = $params{signup};
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

    #        my $dumpfile = '/tmp/xheaout.7';
    #        my $dumpcry = env->cry("Dumping patterns and trips to $dumpfile");
    #        open my $dump_out, '>', $dumpfile;
    #        say $dump_out Actium::dumpstr($patgroup_by_lgdir_r);
    #        close $dump_out;
    #        $dumpcry->done;

    my $skedscry = env->cry('Making schedules');

    my $skedcollection = _make_skeds(
        signup    => $signup,
        patgroups => $patgroup_by_lgdir_r,
        actiumdb  => $actiumdb
    );

    $skedscry->done;

    $skedcollection->output_skeds_all;

    $xhea2skedscry->done;

}

#####################
### GET BLOCKS

sub _get_blocks {

    my %params = validate(
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

            my $block = Octium::Pattern::Block->new(
                block_id      => $block_id,
                vehicle_group => $field{blk_vehicle_group} // $EMPTY,
                vehicle_type  => $field{blk_vehicle_type} // $EMPTY,
            );

            $blocks_by_id{$block_id} = $block;

        }

    );

    return \%blocks_by_id;
}

#####################
### GET PATTERNS

{

    my %line_cache;

    my $linegroup_cr = sub {
        my $line      = shift;
        my $linegroup = $line_cache{$line}{LineGroup} || $line;
    };

    sub _get_patterns {

        my %params = validate(
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

                my $dir_obj = Octium::Dir::->instance( $field{tpat_direction} );

                my $pattern = Octium::Pattern->new(
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
                    $patgroup_by_lgdir{$lgdir} = Octium::Pattern::Group->new(
                        linegroup => $linegroup,
                        direction => $dir_obj,
                    );
                }

                $patgroup_by_lgdir{$lgdir}->add_pattern($pattern);

            }
        );

        return ( \%pattern_by_id, \%patterns_by_linedir, \%patgroup_by_lgdir );

    }

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

    my %params = validate(
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

            say "not defined: block in $int_number" if not defined $block;

            my $event = $field{trp_event_and_status};

            #$event = $EMPTY if $event =~ /\A [A-Z]* on \z/x;
            # delete SCHOOOLon type events

            my $trip = Octium::Pattern::Trip->new(
                days             => $days,
                int_number       => $int_number,
                schedule_daytype => $field{trp_schedule_type},
                pattern_id       => $pattern_id,
                event_and_status => $event,
                #event_and_status => $field{trp_event_and_status},
                op_except     => $field{trp_has_op_except},
                block_id      => $field{trp_block},
                vehicle_group => $block->vehicle_group,
                vehicle_type  => $block->vehicle_type,
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

            my $time = Actium::Time::->from_str( $field{tstp_passing_time} );
            my $stop_position = $field{tstp_position} - 1;
            # convert 1-based to 0-based counting

            $trip->set_stoptime( $stop_position, $time );

            my $pattern_stop = $pattern->stop_obj($stop_position);
            if ( not defined $pattern_stop ) {

                my %stop_spec = ( h_stp_511_id => $field{stp_511_id} );
                $stop_spec{tstp_place} = $field{tstp_place}
                  if $field{tstp_place};
                my $stop_obj = Octium::Pattern::Stop->new(%stop_spec);
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
    #                my $place_obj = Octium::Pattern::Place->new(
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
    #    my $stop_place_cry = env->cry('Combining stops and places');
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

}

########################
### GET PLACE PATTERNS

sub _add_place_patterns_to_patterns {
    my %params = validate(
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
            my $direction = Octium::Dir->instance( $field{direction} );
            my $linedir   = $direction->linedir( $field{line} );
            $ppat_of_linedir{$linedir}->[$rank] = $place;
            return;
        },
    );

    my $ppat_stop_cry = env->cry('Adding place pattern ranks to pattern stops');

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

                unless ( defined $ppat_place ) {
                    $ppat_stop_cry->wail("Linedir: $linedir");
                    $ppat_stop_cry->wail( "This stop: " . $stop->id );
                    $ppat_stop_cry->wail("Stop place $stop_place");
                    $ppat_stop_cry->wail("PPat rank: $ppat_rank");
                    $ppat_stop_cry->wail( "Pattern: " . $pattern->id );
                    foreach my $new_stop ( $pattern->stop_objs ) {
                        $ppat_stop_cry->wail( "Stop: " . $new_stop->id );
                    }

                    use DDP;
                    p $pattern;
                    $ppat_stop_cry->wail('');
                    $ppat_stop_cry->wail('----');
                    p @ppat_entries;
                    $ppat_stop_cry->wail('');
                    exit;
                }
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
    }

    $ppat_stop_cry->done;
    return;

}

####################
### READ RECORDS

sub _records_in_turn {

    my %params = validate(
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
        $cry = env->cry($crytext);
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

}

#################
##### MAKE SKEDS

sub _make_skeds {

    my %params = validate(
        @_,
        {   actiumdb  => 1,
            patgroups => 1,
            signup    => { default => Octium::env->signup },
        }
    );

    \my %patgroup_by_lgdir = $params{patgroups};

    my @skeds;
    foreach my $lgdir ( Actium::sortbyline keys %patgroup_by_lgdir ) {
        next if $lgdir =~ /^399/;
        # 399 is not a real line
        env->last_cry->over( $lgdir, " " );
        my $patgroup = $patgroup_by_lgdir{$lgdir};
        push @skeds, $patgroup->skeds( $params{actiumdb} );
    }
    env->last_cry->over(".");

    return Octium::Sked::Collection->new(
        name   => 'received',
        skeds  => \@skeds,
        signup => $params{signup}
    );
    #return \@skeds;

}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

