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
    is  => 'ro',
    traits    => ['Hash'],
    isa => 'Hashref',
    default   => sub { {} },
    handles => { _set_routecount => 'set' ,
                 routes => 'keys' ,
                 count_of_route => 'get' ,
                 has_route => 'exists' ,
    },
        
);

has 'district' => {
   is => 'rw' ,
   isa => 'Str' ,
};

has 'side' => {
   is => 'rw' ,
   isa => 'Str' ,
};

has 'pattern_relation_r' => {
   is => 'bare',
   isa => 'ArrayRef[Actium::Flagspecs::Stop::PatternRelation]',
   default => sub { [] } ,
   handles => {
       pattern_relations => 'elements',
       add_pattern_relation => 'push' ,
   },
 
};

sub add_route {
    my $self = shift;
    my $route = shift;
    
    if ($self->has_route($route)) {
        my $count = $self->count_of_route($route);
        $self->_set_routecount($route, $count + 1);
    }
    else {
        $self->set_routecount($route, 1);
    }
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
