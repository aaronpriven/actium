#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Placelist.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Placelist 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Util ('jk');

has 'placelist' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'patterns_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Flagspecs::Pattern]',
    handles => {
        add_pattern => 'push',
        patterns    => 'elements',
    },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
