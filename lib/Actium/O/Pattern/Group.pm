package Actium::O::Pattern::Group 0.012;

use Actium::Moose;

use Actium::Types (qw/ActiumDir/);
use Actium::O::Dir;
use Actium::O::Pattern;

# CLASS METHOD
sub build_lgdir {
    my $invocant = shift;
    my ( $linegroup, $dircode );
    if ( u::blessed $invocant) {
        $linegroup = $invocant->linegroup;
        $dircode   = $invocant->dircode;
    }
    else {
        $linegroup = shift;
        my $dir = shift;

        if ( u::blessed $dir) {
            $dircode = $dir->dircode;
        }
        else {
            $dircode = $dir;
        }
    }

    return "$linegroup.$dircode";
} ## tidy end: sub build_lgdir

# OBJECT METHODS AND ATTRIBUTES

has 'linegroup' => (
    required => 1,
    is       => 'ro',
    isa      => 'Str',
);

has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => ['dircode'],
);

has 'lgdir' => (
    is      => 'ro',
    lazy    => 1,
    builder => 'build_lgdir',
    isa     => 'Str',
);

sub id {
    my $self = shift;
    return $self->lgdir;
}

has 'patterns_obj' => (
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Pattern]',
    default => sub { [] },
    traits  => ['Array'],
    handles => {
        patterns    => 'elements',
        add_pattern => 'push',
    },
);

has 'upattern_r' => (
    is      => 'rw',
    isa     => 'Str',
);

u::immut;

1;
