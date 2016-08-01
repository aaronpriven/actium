package Actium::O::Pattern 0.012;

# used by Xhea:::ToSkeds

use Actium::Moose;

use Actium::Types (qw/DirCode ActiumDir/);
use Actium::O::Dir;
use Actium::O::Pattern::Stop;

has 'line' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has [qw/vdc via/] => (
    is => 'ro',
);

has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => ['dircode'],
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
    return u::joinkey( $self->line, $self->dircode, $self->identifier );
}

has 'stop_objs_r' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Pattern::Stop]',
    writer => '_set_stop_objs_r',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        stop_objs    => 'elements',
    },
);

u::immut;

1;
