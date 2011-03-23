#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Stop.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::Flagspecs::Stop;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'stop_ident' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'routes_r' => (
    is  => 'rw',
    traits    => ['Hash'],
    isa => 'Hashref',
    default   => sub { {} },
    handles => { set_route => 'set' ,
                 routes => 'keys' ,
                 get_route => 'get' ,
                 has_route => 'exists' ,
    },
        
);

has 'boxes_r' => (
    is => 'rw' ,
    traits    => ['Hash'],
    isa => 'Hashref[Actium::Flagspecs::Box]',
    default   => sub { {} },
    handles => { set_box => 'set' ,
                 routedirs => 'keys' ,
                 get_box => 'get' ,
                 has_routedir => 'exists' ,
    },
);

sub add_route {
    my $self = shift;
    my $route = shift;
    
    if ($self->has_route($route)) {
        my $count = $self->get_route($route);
        $self->set_route($route, $count + 1);
    }
    else {
        $self->set_route($route, 1);
    }
}


__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
