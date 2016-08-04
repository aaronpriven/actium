package Actium::O::Pattern::Group 0.012;

use Actium::Moose;

use Actium::Types (qw/ActiumDir/);
use Actium::O::Dir;
use Actium::O::Days;
use Actium::O::Pattern;
use Actium::O::Sked::Trip;
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
    default => sub { [] },
    traits  => ['Hash'],
    handles => {
        patterns     => 'values',
        _set_pattern => 'set',
        _pat_ids     => 'keys',
        _pattern     => 'get',
    },
);

sub add_pattern {
    my $self    = shift;
    my $pattern = shift;
    my $pat_id  = $pattern->unique_id;
    $self->_set_pattern( $pat_id => $pattern );
    return;

}

has 'places_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    writer  => '_set_places_r',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        places   => 'elements',
    },
);

u::immut;


### debugging use only
has 'upattern_r' => (
    is  => 'rw',
    isa => 'Str',
);

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

sub sked {
    my $self = shift;
    $self->_order_stops;
    
    #my @places = $self->places;

    my @sked_trip_objs = $self->_sked_trip_objs;
    

}

    
    

sub _sked_trip_objs {
    my $self = shift;

    my @skedtrips;
    foreach my $pattern ( $self->patterns ) {
        foreach my $trip ( $pattern->trips ) {

            my $days = $trip->days;
            $days =~ s/7/7H/;    # dumb way of dealing with holidays, but...

            my $days_obj = Actium::O::Dir->instance( $trip->days );

            my @times = map { $_->timenum } $trip->times;

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
                days           => Actium::O::Days::->instance( $trip->days ),
                stoptime_r     => \@times,
              );

        }

    } ## tidy end: foreach my $pattern ( $self...)

    return @skedtrips;

} ## tidy end: sub _sked_trip_objs

sub _order_stops {
    my $self = shift;

    my %stop_set_of;

    my @pat_ids = $self->_pat_ids;

    foreach my $pat_id (@pat_ids) {
        my $pattern = $self->_pattern($pat_id);
        $stop_set_of{$pat_id} = [ $pattern->stops_and_places ];
    }

    my %returned = ordered_union_columns(
        sethash    => \%stop_set_of,
        tiebreaker => $stop_tiebreaker,
    );

    foreach my $pat_id (@pat_ids) {
        \my @union_indexes = $returned{columns_of}{$pat_id};
        my $pattern = $self->_pattern($pat_id);
        $pattern->set_union_indexes_r( \@union_indexes );
        # union_indexes_r is only for debugging purposes now

        foreach my $trip ( $pattern->trips ) {
            my @stops = $trip->stops;
            my @unified_stops;

            for my $old_column_idx ( 0 .. $#stops ) {
                my $new_column_idx = $union_indexes[$old_column_idx];
                $unified_stops[$new_column_idx] = $stops[$old_column_idx];
            }
            $trip->_set_stop_objs_r( \@unified_stops );

        }

        $pattern->set_union_indexes_r( $returned{columns_of}{$pat_id} );
    } ## tidy end: foreach my $pat_id (@pat_ids)

    # $self->upattern_r and $pattern->union_indexes_r are
    # no longer used but is left in for debugging purposes
    
    my @union = $returned{union}->@* ;
    
    $self->set_upattern_r( join( ':', @union ) );
    
    my @places;
    foreach my $stop_and_place (@union) {
        my ($stop, $place, $rank) = split(/\./, $stop_and_place);
        push @places , $place if $place;
    }
    
    $self->_set_places_r(\@places);
    

} ## tidy end: sub _order_stops

u::immut;

1;
