#!/ActivePerl/bin/perl

#/Actium/Flagspecs/Pattern.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Pattern 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Constants;

use Actium::Util ('jk');

has 'route' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'dir_obj' => (
    required => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => 'Actium::Sked::Dir',
    handles  => {direction => 'dircode'},
);

has 'identifier' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'unique_id' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => 1,
    builder => '_build_unique_id',
);

sub _build_unique_id {
    my $self = shift;
    return jk( $self->route, $self->dircode, $self->identifier );
}

has 'stops_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        stops    => 'elements',
        add_stop => 'push',
        stoplist => ['join' , $KEY_SEPARATOR ],
    },
);

has 'places_r' => (
   is => 'bare',
   isa => 'ArrayRef[Str]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        places    => 'elements',
        add_place => 'push',
        placelist => ['join' , $KEY_SEPARATOR ],
    },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
