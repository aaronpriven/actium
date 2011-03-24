#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Box.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::Flagspecs::Box;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

has 'route_dir' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);


__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
