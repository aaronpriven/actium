#!/ActivePerl/bin/perl

#/Actium/O/Patterns/Stop/PatternRelation.pm

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::O::Patterns::Stop::PatternRelation 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'pattern_unique_id' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'stop_obj' => (
    required => 1,
    is       => 'ro',
    isa      => 'Actium::O::Patterns::Stop',
    weak_ref => 1,
);

has 'is_at_place' => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { 'set_at_place' => 'set', },
);

has 'is_dropoff_only' => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { 'set_dropoff_only' => 'set', },
);


has 'is_transbay_only' => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { 'set_transbay_only' => 'set', },
);

has 'is_last_stop' => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { 'set_last_stop' => 'set', },
);

has 'place' => (
    is  => 'rw',
    isa => 'Str',
);

has 'next_place' => (
    is  => 'rw',
    isa => 'Str',
);

# connections *at this stop* (e.g., at a BART station, BART)
has 'connections_here' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        connections_here   => 'elements',
        mark_at_connection => 'push',
    },
);

# connections this pattern will eventually hit in the future
# (e.g., *before* a BART station, BART)
has 'connections_to' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    traits  => ['Array'],
    default => sub { [] },
    handles => {
        connections_to     => 'elements',
        mark_connection_to => 'push',
    },
);

has 'going_transbay' => (
    is      => 'ro',
    isa     => 'Bool',
    traits  => ['Bool'],
    default => 0,
    handles => { set_going_transbay => 'set', },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
