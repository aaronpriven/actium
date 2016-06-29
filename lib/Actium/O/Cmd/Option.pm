package Actium::O::Cmd::Option 0.011;

use Actium::Moose;

# it will look for, in this order:

# command-line option
# environment variable
# configuration file
# fallback value specified
# prompt the user

# but each one has to be requested.
# It will never get to the prompt if a fallback value is specified,
# so no point in asking for both

around BUILDARGS => sub {
    my $class = shift;
    my $orig  = shift;

    my %params = u::validate(
        @_,
        {   cmdenv         => { type    => 'Actium::O::Cmd' },
            envvar         => 0,
            config_section => { default => '_' },
            config_key     => 0,
            fallback       => 0,

            description     => 1,
            display_default => { type => $PV_TYPE{BOOLEAN}, default => 0 },

            spec       => 0,
            callback   => 0,
            prompt     => 0,
            no_command => 0,
            prompthide => { type => $PV_TYPE{BOOLEAN}, default => 0 },
        }
    );

    # Establish default, if any
    my $cmdenv      = $params{cmdenv};
    my $description = $params{description};
    my $default;

    if ( exists $params{envvar} ) {
        my $envvar      = $params{env};
        my $system_name = $cmdenv->system_name;
        $envvar =~ s/\A(?:${system_name}_)*/${system_name}_/;
        $envvar  = uc($envvar);
        $default = $cmdenv->sysenv($envvar);

    }

    if ( not defined $default and exists $params{config_key} ) {
        $default = $cmdenv->config->value(
            section => $params{config_section},
            key     => $params{config_key}
        );
    }

    if (    $default eq $EMPTY
        and $params{spec} =~ m/\A [ \w ? \- | ]+ [+!]?/x )
    {
        $default = 1;
    }
         # set default to 1 for simple options - those with no argument spec,
         # or + or ! argument specs

    if ( not defined $default and exists $params{fallback} ) {
        $default = $params{fallback};
    }

    if ( defined $default and $params{display_default} ) {
        $description .= qq{. If not specified, will use $default};
    }

    my %init_args = (
        %params{qw/spec callback prompt no_command/},
        description => $description
    );

    $init_args{default} = $default if defined $default;

    return $class->$orig(%init_args);

};

has spec => (
    isa      => 'Str',
    is       => 'ro',
    required => 0,
);

has [qw/no_command prompthide/] => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
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

has default => ( is => 'ro', );

has callback => (
    isa => 'CodeRef',
    is  => 'ro',
);

sub allnames {
    my $self = shift;
    return ( $self->name, $self->aliases );
}

u::immut;

1;
