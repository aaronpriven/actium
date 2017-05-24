package Actium::O::Cmd::Option 0.011;

use Actium ('class_nomod');

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
    my $orig  = shift;
    my $class = shift;

    my %params = u::validate(
        @_,
        {   cmdenv         => { isa     => 'Actium::O::Cmd' },
            envvar         => 0,
            config_section => { default => '_' },
            config_key     => 0,
            fallback       => 0,

            description     => 1,
            display_default => { type => $PV_TYPE{BOOLEAN}, default => 0 },

            order    => { type => $PV_TYPE{SCALAR} },
            spec     => 1,
            callback => 0,
            prompt   => 0,
            no_command => { type => $PV_TYPE{BOOLEAN}, default => 0 },
            prompthide => { type => $PV_TYPE{BOOLEAN}, default => 0 },
        }
    );

    # Establish default, if any
    my $cmdenv      = $params{cmdenv};
    my $description = $params{description};
    my $default;

    if ( exists $params{envvar} ) {
        my $envvar      = $params{envvar};
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

    if (    defined $default
        and $default eq $EMPTY
        and $params{spec} =~ m/\A [ \w ? \- | ]+ (?: [+!] | \z)/x )
    {
        $default = 1;
    }
    # set default to 1 for simple options - those with no argument spec,
    # or + or ! argument specs

    if ( not defined $default and exists $params{fallback} ) {
        $default = $params{fallback};
    }

    if ( defined($default) and $params{display_default} ) {
        $description .= qq{. If not specified, will use "$default"};
    }

    my %init_args;

    foreach my $param (qw(spec prompthide callback prompt no_command order)) {
        $init_args{$param} = $params{$param} if exists $params{$param};
    }

    $init_args{description} = $description;

    $init_args{default} = $default if defined $default;

    return $class->$orig(%init_args);

};

sub BUILD {
    my $self = shift;
    my $spec = $self->spec;

    my $allnames = $spec =~ s/( [\w ? \- | ] + ) .*/$1/rsx;
    my @aliases  = split( /[|]/s, $allnames );
    my $name     = shift @aliases;

    $self->_set_name($name);
    $self->_set_aliases( \@aliases );

}

has spec => (
    isa      => 'Str',
    is       => 'ro',
    required => 0,
);

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

has order => (
    required => 1,
    isa      => 'Int',
    is       => 'ro',
);

has [qw/no_command prompthide/] => (
    isa     => 'Bool',
    is      => 'ro',
    default => 0,
);

has prompt => (
    isa => 'Str',
    is  => 'ro',
);

has [qw/default fallback/] => ( is => 'ro' );

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

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

