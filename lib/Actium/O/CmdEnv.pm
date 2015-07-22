package Actium::O::CmdEnv 0.010;

# Configuration and environment of command line programs
# Probably needs a better name

use Actium::Moose;
use FindBin (qw($Bin));
use Actium::O::Files::Ini;

sub _build_config {
    my $self       = shift;
    my $systemname = $self->system_name;

    ## no critic (RequireExplicitInclusion)
    # bug in RequireExplicitInclusion
    my $config = Actium::O::Files::Ini::->new(".$systemname.ini");
    ## use critic

    return $config;

}

has config => (
    is      => 'ro',
    isa     => 'Actium::O::Files::Ini',
    builder => '_build_config',
    lazy    => 1,
);

has bin => (
    isa     => 'Actium::O::Folder',
    is      => 'ro',
    builder => '_build_bin',
);

has [qw/subcommand system_name module/] => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

has crier => (
    is       => 'ro',
    required => 1,
    isa      => 'Actium::O::Crier',
);

sub _build_bin {
    require Actium::O::Folder;
    return Actium::O::Folder::->new($Bin);
}

has sysenv_r => (
    traits  => ['Hash'],
    isa     => 'HashRef[Str]',
    is      => 'bare',
    builder => '_build_sysenv',
    lazy    => 1,
    handles => { sysenv => 'get', },
);

sub _build_sysenv {
    return {%ENV};
}

has argv_r => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    is      => 'bare',
    writer  => '_set_argv_r',
    default => sub { [] },
    handles => {
        argv     => 'elements',
        argv_idx => 'get',
    },
);

has options_r => (
    traits  => ['Hash'],
    isa     => 'HashRef',
    is      => 'bare',
    writer  => '_set_options_r',
    default => sub { {} },
    handles => { option => 'get', _set_option => 'set' },
);

sub be_quiet {
    
    my $self = shift;
    $self->crier->set_maxdepth(0);
    $self->_set_option('quiet', 1);

}

1;
