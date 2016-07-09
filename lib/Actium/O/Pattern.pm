package Actium::O::Pattern 0.011;

use 5.012;
use warnings;

use Moose; ### DEP ###
use MooseX::StrictConstructor; ### DEP ###
use Moose::Util::TypeConstraints; ### DEP ###

use namespace::autoclean; ### DEP ###

use Actium::Constants;
use Actium::Types (qw/DirCode HastusDirCode ActiumDir/);
use Actium::O::Dir;
use Actium::Util ('joinkey');

has 'route' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'dir_obj' => (
    required => 1,
    coerce => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => ['dircode' ],
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

sub id {
   my $self = shift;
   return $self->unique_id;
}

sub _build_unique_id {
    my $self = shift;
    return joinkey( $self->route, $self->dircode, $self->identifier );
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
