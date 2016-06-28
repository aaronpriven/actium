package Actium::O::Cmd::Option 0.011;

use Actium::Moose;

has spec => (
    isa      => 'Str',
    is       => 'ro',
    required => 1,
);

sub BUILD {
    my $self = shift;
    my $spec = $self->spec;

    my $allnames = $spec =~ s/( [\w ? \- | ] + ) .*/$1/rsx;
    my @aliases  = split( /[|]/s, $allnames );
    my $name     = shift @aliases;

    $self->_set_name($name);
    $self->_set_aliases( \@aliases );

}

has name => (
    isa    => 'Str',
    is     => 'ro',
    writer => '_set_name',
);

has alias_r => (
    traits  => ['Array'],
    isa     => 'ArrayRef[Str]',
    is      => 'bare',
    writer  => '_set_aliases',
    default => sub { [] },
    handles => { aliases => 'elements', },
);

has description => (
    required => 1,
    isa      => 'Str',
    is       => 'ro',
);

has default => (
    is => 'ro',
);

has callback => (
    isa      => 'CodeRef',
    is       => 'ro',
    required => 0,
);

sub allnames {
    my $self = shift;
    return ( $self->name, $self->aliases );
}

u::immut;

1;
