package Actium::O::Pattern::Group 0.012;

use Actium::Moose;

use Actium::Types (qw/ActiumDir/);
use Actium::O::Dir;
use Actium::O::Days;
use Actium::O::Pattern;
use Actium::O::Sked::Trip;
use Actium::O::Sked;
use Actium::O::Sked::TripCollection;
use Actium::Union ('ordered_union_columns');

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
    isa     => 'HashRef[Actium::O::Pattern]',
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

### debugging use only
#has 'upattern_r' => (
#    is  => 'rw',
#    isa => 'Str',
#);

sub skeds {
    my $self     = shift;
    my $actiumdb = shift;

    $self->_order_stops;

    my @skeds;

    \my %trip_collection_by_days = $self->_sked_trip_collections;

    my @place8s = map { $actiumdb->place8($_) } $self->places;

    foreach my $days ( keys %trip_collection_by_days ) {
        my $trip_collection = $trip_collection_by_days{$days};

        push @skeds,
          Actium::O::Sked->new(
            place4_r    => $self->places_r,
            place8_r    => \@place8s,
            stopplace_r => $self->stopplaces_r,
            stopid_r    => $self->stopids_r,
            linegroup   => $self->linegroup,
            direction   => $self->dir_obj,
            trip_r      => $trip_collection->trips_r,
            days        => Actium::O::Days->instance( $days, 'B' ),
          );

    }

    return @skeds;

} ## tidy end: sub skeds

sub _sked_trip_collections {
    my $self = shift;

    my @skedtrips;
    foreach my $pattern ( $self->patterns ) {
        foreach my $trip ( $pattern->trips ) {

            my $days = $trip->days;
            $days =~ s/7/7H/;    # dumb way of dealing with holidays, but...
            my @days = split( //, $trip->days );
            my $days_obj = Actium::O::Days->instance( $days, 'B' );

            my @times = map { $_->timenum } $trip->stoptimes;

            push @skedtrips,
              Actium::O::Sked::Trip->new(
                blockid        => $trip->block_id,
                pattern        => $pattern->identifier,
                daysexceptions => $trip->event_and_status,
                vehicledisplay => $pattern->vdc,
                via            => $pattern->via,
                vehicletype    => $trip->vehicle_type,
                line           => $pattern->line,
                internal_num   => $trip->int_number,
                type           => $trip->schedule_daytype,
                days           => $days_obj,
                stoptime_r     => \@times,
              );

        } ## tidy end: foreach my $trip ( $pattern...)

    } ## tidy end: foreach my $pattern ( $self...)

    my $all_trips_collection
      = Actium::O::Sked::TripCollection->new( trips_r => \@skedtrips );

    return $all_trips_collection->trips_by_day;
} ## tidy end: sub _sked_trip_collections

my $stop_tiebreaker = sub {

    # tiebreaks by using the average rank of the timepoints involved.

    my @lists = @_;
    my @avg_ranks;

    foreach my $i ( 0, 1 ) {

        my @ranks;
        foreach my $stop ( @{ $lists[$i] } ) {
            my ( $stopid, $placeid, $placerank ) = split( /\./s, $stop );
            if ( defined $placerank ) {
                push @ranks, $placerank;
            }
        }
        return 0 unless @ranks;
        # if either list has no timepoint ranks,
        # return 0 indicating we can't break the tie

        $avg_ranks[$i] = u::sum(@ranks) / @ranks;

    }

    return $avg_ranks[0] <=> $avg_ranks[1];

};

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

     #        foreach my $trip ( $pattern->trips ) {
     #            my @stops = $trip->stoptimes;
     #            my @unified_stops;
     #
     #            for my $old_column_idx ( 0 .. $#stops ) {
     #                my $new_column_idx = $union_indexes[$old_column_idx];
     #                $unified_stops[$new_column_idx] = $stops[$old_column_idx];
     #            }
     #            $trip->_set_stoptime_r( \@unified_stops );
     #
     #        }
     #

    }

    my @union = $returned{union}->@*;

    #$self->set_upattern_r( join( ':', @union ) );

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

} ## tidy end: sub _order_stops

u::immut;

1;
