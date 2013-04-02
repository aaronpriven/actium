#!/ActivePerl/bin/perl

#/Actium/Pattern/Stop.pm

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::Patterns::Stop 0.001;

use Moose;
use MooseX::StrictConstructor;

has 'id' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'routes_r' => (
    is      => 'ro',
    traits  => ['Hash'],
    isa     => 'HashRef[Bool]',
    default => sub { {} },
    handles => {
        _set_route => 'set',
        routes    => 'keys',
        has_route => 'exists',
    },
);

sub set_route {
    my $self = shift;
    my $route = shift;
    $self->_set_route($route, 1);
}

has 'district' => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has 'side' => (
    is  => 'ro',
    isa => 'Str',
    required => 1,
);

has '_relation_list_of_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Patterns::Stop::PatternRelation]]',
    default => sub { {} },
    traits => ['Hash'],
    handles => {
        _relation_list_r_of     => 'get',
        _set_relation_list_r_of => 'set',
        _has_relation_list_r    => 'exists',
        _relation_list_ids      => 'keys',
    },
);

sub add_relation {
    my $self              = shift;
    my $relation_obj      = shift;
    my $pattern_unique_id = $relation_obj->pattern_unique_id;

    if ( $self->_has_relation_list_r($pattern_unique_id) ) {
        push @{ $self->_relation_list_r_of($pattern_unique_id) }, $relation_obj;
    }
    else {
        $self->_set_relation_list_r_of( $pattern_unique_id, [$relation_obj] );
    }
    return;
}

sub first_relation_of {
    my $self              = shift;
    my $pattern_unique_id = shift;
    return $self->_relation_list_r_of($pattern_unique_id)->[0];
}

sub first_relations {
    my $self = shift;
    my @results;
    return map { $self->first_relation_of($_) } $self->_relation_list_ids;
}

sub relations_of {
    my $self              = shift;
    my $pattern_unique_id = shift;
    return @{ $self->_relation_list_r_of($pattern_unique_id) };
}

sub relations {
    my $self = shift;
    my @results;
    foreach my $pattern_unique_id ( $self->_relation_list_ids ) {
        push @results, @{ $self->_relation_list_r_of($pattern_unique_id) };
    }
    return @results;
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)
1;
