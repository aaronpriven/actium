package Octium::Pattern::Group 0.012;

use Actium ('class');
use Octium;

use Octium::Types (qw/ActiumDir/);
use Octium::Dir;
use Octium::Days;
use Actium::Time;
use Octium::Pattern;
use Octium::Sked::Trip;
use Octium::Sked;
use Octium::Sked::TripCollection;
use Octium::Set ('ordered_union_columns');

# OBJECT METHODS AND ATTRIBUTES

has 'linegroup' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => ['dircode'],
);

has 'lgdir' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_lgdir',
    isa     => 'Str',
);

sub _build_lgdir {
    my $self = shift;
    return $self->dir_obj->linedir( $self->linegroup );
}

sub id {
    my $self = shift;
    return $self->lgdir;
}

has 'patterns_obj' => (
    is      => 'bare',
    isa     => 'HashRef[Octium::Pattern]',
    default => sub { {} },
    traits  => ['Hash'],
    handles => {
        patterns     => 'values',
        _set_pattern => 'set',
        _pattern_ids => 'keys',
        _pattern     => 'get',
    },
);

sub add_pattern {
    my $self       = shift;
    my $pattern    = shift;
    my $pattern_id = $pattern->unique_id;
    $self->_set_pattern( $pattern_id => $pattern );
    return;

}

for (qw(stopid place)) {
    has "${_}s_r" => (
        is      => 'ro',
        isa     => 'ArrayRef[Str]',
        writer  => "_set_${_}s_r",
        default => sub { [] },
        traits  => ['Array'],
        handles => { "${_}s" => 'elements', },
    );
}

has stopplaces_r => (
    is      => 'ro',
    isa     => 'ArrayRef[Maybe[Str]]',
    writer  => "_set_stopplaces_r",
    default => sub { [] },
    traits  => ['Array'],
    handles => { stopplaces => 'elements', },
);

sub skeds {
    my $self     = shift;
    my $actiumdb = shift;

    $self->_order_stops;

    my @skeds;

    \my %trip_collection_by_days = $self->_sked_trip_collections;

    my @place4s    = map { $actiumdb->dereference_place($_) } $self->places;
    my @stopplaces = map { $actiumdb->dereference_place($_) } $self->stopplaces;
    my @place8s    = map { $actiumdb->place8($_) } @place4s;

    foreach my $days ( keys %trip_collection_by_days ) {
        my $trip_collection = $trip_collection_by_days{$days};

        # those are [@place4s] and not \@place4s (etc.)
        # because this is a loop and we want each schedule to get its own
        # new reference.

        push @skeds,
          Octium::Sked->new(
            place4_r    => [@place4s],
            place8_r    => [@place8s],
            stopplace_r => [@stopplaces],
            stopid_r    => [ $self->stopids_r->@* ],
            linegroup   => $self->linegroup,
            direction   => $self->dir_obj,
            trip_r      => [ $trip_collection->trips_r->@* ],
            days        => Octium::Days->instance( $days, 'B' ),
          );

    }

    my $lgdir = $self->lgdir;

    return @skeds;

}

sub _sked_trip_collections {
    my $self = shift;

    my @skedtrips;
    foreach my $pattern ( $self->patterns ) {
        foreach my $trip ( $pattern->trips ) {

            my $days = $trip->days;
            $days =~ s/7/7H/;    # dumb way of dealing with holidays, but...

            my $schooldays = 'B';
            my $event      = $trip->event_and_status;
            if ( $event =~ /^SD[A-Z]*on/ ) {
                $schooldays = 'D';
                $event      = '';
            }

            my $days_obj = Octium::Days->instance( $days, $schooldays );

            my @times = map { $_->timenum } $trip->stoptimes;

            # combine xhea's vehicle group and vehicle type into
            # one field. (Currently only vehicle group is used)

            my @vehicle_info = grep { $_ or $_ eq '0' }
              ( $trip->vehicle_group, $trip->vehicle_type );

            my $vehicletype
              = @vehicle_info ? join( ":", @vehicle_info ) : $EMPTY;

            push @skedtrips, Octium::Sked::Trip->new(
                blockid => $trip->block_id,
                pattern => $pattern->identifier,
                daysexceptions => $event,             # $trip->event_and_status,
                vehicledisplay => $pattern->vdc,
                via            => $pattern->via,
                vehicletype    => $vehicletype,
                line           => $pattern->line,
                internal_num   => $trip->int_number,
                type       => $trip->schedule_daytype,
                days       => $days_obj,
                stoptime_r => \@times,
            );

        }

    }

    my $all_trips_collection
      = Octium::Sked::TripCollection->new( trips_r => \@skedtrips );

    return $all_trips_collection->trips_by_day;

}

my $stop_tiebreaker = sub {
    # tiebreaks by using the average rank of the timepoints involved.

    my @lists = @_;
    my @avg_ranks;

    foreach my $i ( 0, 1 ) {

        my @ranks;
        foreach my $stop ( @{ $lists[$i] } ) {
            my ( $stopid, $placeid, $placerank ) = split( /\t/, $stop );
            if ( defined $placerank ) {
                push @ranks, $placerank;
            }
        }
        return 0 unless @ranks;
        # if either list has no timepoint ranks,
        # return 0 indicating we can't break the tie

        $avg_ranks[$i] = Actium::sum(@ranks) / @ranks;

    }

    return $avg_ranks[0] <=> $avg_ranks[1];

};

my $undef_time = Actium::Time->from_num(undef);

sub _order_stops {
    my $self = shift;

    my %stop_set_of;

    foreach my $pattern ( $self->patterns ) {
        my $pattern_id = $pattern->unique_id;
        my @stops_and_places;
        foreach my $stop ( $pattern->stop_objs ) {
            my $stop_and_place = $stop->h_stp_511_id;
            if ( $stop->has_place ) {
                $stop_and_place .= "\t" . $stop->tstp_place;
                if ( $stop->has_place_rank ) {
                    $stop_and_place .= "\t" . $stop->place_rank;
                }
            }
            push @stops_and_places, $stop_and_place;
        }
        $stop_set_of{$pattern_id} = \@stops_and_places;
    }

    my %returned = ordered_union_columns(
        sethash    => \%stop_set_of,
        tiebreaker => $stop_tiebreaker,
    );

    foreach my $pattern_id ( $self->_pattern_ids ) {
        \my @union_indexes = $returned{columns_of}{$pattern_id};
        my $pattern = $self->_pattern($pattern_id);
        $pattern->set_union_indexes_r( \@union_indexes );

        foreach my $trip ( $pattern->trips ) {
            my @stops = $trip->stoptimes;
            my @unified_stops;

            for my $old_column_idx ( 0 .. $#stops ) {
                my $new_column_idx = $union_indexes[$old_column_idx];
                $unified_stops[$new_column_idx] = $stops[$old_column_idx];
            }

            foreach my $i ( 0 .. $#unified_stops ) {
                $unified_stops[$i] = $undef_time
                  if not defined $unified_stops[$i];
            }

            $trip->_set_stoptime_r( \@unified_stops );

        }

    }

    my @union = $returned{union}->@*;

    my ( @places, @stopids, @stopplaces );
    foreach my $stop_and_place (@union) {
        my ( $stop, $place, $rank ) = split( /\t/, $stop_and_place );
        push @stopids, $stop;
        if ($place) {
            push @places,     $place;
            push @stopplaces, $place;
        }
        else {
            push @stopplaces, undef;
        }
    }

    $self->_set_stopids_r( \@stopids );
    $self->_set_places_r( \@places );
    $self->_set_stopplaces_r( \@stopplaces );

    return;

}

Actium::immut;

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

