#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Stop.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Stop 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'stop_ident' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'count_of_routes_r' => (
    is      => 'ro',
    traits  => ['Hash'],
    isa     => 'Hashref',
    default => sub { {} },
    handles => {
        _set_routecount => 'set',
        routes          => 'keys',
        count_of_route  => 'get',
        has_route       => 'exists',
    },

);

has 'district' => {
    is  => 'rw',
    isa => 'Str',
};

has 'side' => {
    is  => 'rw',
    isa => 'Str',
};

has 'pattern_relation_of_r' => {
    is      => 'bare',
    isa     => 'HashRef[Actium::Flagspecs::Stop::PatternRelation]',
    default => sub { [] },
    handles => {
        pattern_relations        => 'values',
        _pattern_relation_of     => 'get',
        _set_pattern_relation_of => 'set',
        _has_pattern_relation    => 'exists',
    },

};

##############
## Pattern Relation delegates... only it has to check that it exists first

sub set_at_place {
    my $self              = shift;
    my $pattern_unique_id = shift;
    if ( $self->_has_pattern_relation($pattern_unique_id) ) {
        $self->pattern_relation_of($pattern_unique_id)->set_at_place;
    }
}

sub set_last_stop {
    my $self              = shift;
    my $pattern_unique_id = shift;
    if ( $self->_has_pattern_relation($pattern_unique_id) ) {
        $self->pattern_relation_of($pattern_unique_id)->set_last_stop;
    }
}

sub set_place {
    my $self              = shift;
    my $pattern_unique_id = shift;
    my $place             = shift;
    if ( $self->_has_pattern_relation($pattern_unique_id) ) {
        $self->pattern_relation_of($pattern_unique_id)->set_place($place);
    }
}

sub set_next_place {
    my $self              = shift;
    my $pattern_unique_id = shift;
    my $place             = shift;
    if ( $self->_has_pattern_relation($pattern_unique_id) ) {
        $self->pattern_relation_of($pattern_unique_id)->set_next_place($place);
    }
}

sub add_pattern_relation {
    my $self              = shift;
    my $relation_obj      = shift;
    my $pattern_unique_id = $relation_obj->pattern_unique_id;
    _set_pattern_relation_of( $pattern_unique_id, $relation_obj );
    return;
}

sub add_route {
    my $self  = shift;
    my $route = shift;

    if ( $self->has_route($route) ) {
        my $count = $self->count_of_route($route);
        $self->_set_routecount( $route, $count + 1 );
    }
    else {
        $self->set_routecount( $route, 1 );
    }
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)
1;
