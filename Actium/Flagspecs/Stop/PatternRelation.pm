#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Stop/PatternRelation.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Stop::PatternRelation 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'pattern_unique_id' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'is_at_place' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    handles => { 'set_at_place' => 'set', },
);

has 'is_last_stop' => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
    handles => { 'set_last_stop' => 'set', },
);

has 'place' => (
    is  => 'rw',
    isa => 'Str',
);

has 'nextplace' => (
    is  => 'rw',
    isa => 'Str',
);

has 'connections' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    traits  => '[Array]',
    default => sub { [] },
    handles => {
        connections    => 'elements',
        add_connection => 'push',
    },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
