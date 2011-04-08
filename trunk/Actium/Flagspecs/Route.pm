#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Route.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Route 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Util ('jk');

around BUILDARGS => sub {
    return positional( \@_, 'route' );
};

has 'route' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

#has 'patterns_r' => (
#    is      => 'bare',
#    isa     => 'ArrayRef[Actium::Flagspecs::Pattern]',
#    handles => {
#        _push_pattern => 'push',
#        patterns    => 'elements',
#    },
#);
#
#
#sub add_pattern {
# 
# my $self = shift;
# my $pattern_obj = shift;
# $self->_push_pattern($pattern_obj);
# 
# 
# 
#}

#has 'pattern_of_placelist_r' => (
#    is      => 'ro',
#    traits  => ['Hash'],
#    isa     => 'HashRef[ArrayRef[Actium::Flagspecs::Pattern]]',
#    default => sub { {} },
#    handles => {
#        placelists  => 'keys',
#        pattern_of_placelist => 'get',
#        has_placelist => 'exists',
#    },
# 
#);
 
 
 
has 'pattern_of_placelist_r' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Actium::Flagspecs::Stop::PatternRelation]]',
    default => sub { {} },
    traits => ['Hash'],
    handles => {
        _pattern_list_r_of     => 'get',
        _set_pattern_list_r_of => 'set',
        _has_pattern_list_r    => 'exists',
        _pattern_list_ids      => 'keys',
    },
);

sub add_pattern {
    my $self              = shift;
    my $pattern_obj      = shift;
    my $pattern_unique_id = $pattern_obj->pattern_unique_id;

    if ( $self->has_pattern_list_r($pattern_unique_id) ) {
        push @{ $self->pattern_list_r_of($pattern_unique_id) }, $pattern_obj;
    }
    else {
        $self->_set_pattern_list_r_of( $pattern_unique_id, [$pattern_obj] );
    }
    return;
}

#sub first_pattern_of {
#    my $self              = shift;
#    my $pattern_unique_id = shift;
#    return $self->_pattern_list_r_of($pattern_unique_id)->[0];
#}
#
#sub first_patterns {
#    my $self = shift;
#    my @results;
#    return map { $self->first_pattern_of($_) } $self->_pattern_list_ids;
#}

sub patterns_of {
    my $self              = shift;
    my $pattern_unique_id = shift;
    return @{ $self->_pattern_list_r_of($pattern_unique_id) };
}

sub patterns {
    my $self = shift;
    my @results;
    foreach my $pattern_unique_id ( $self->_pattern_list_ids ) {
        push @results, @{ $self->_pattern_list_r_of($pattern_unique_id) };
    }
    return @results;
}
 
   


__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
