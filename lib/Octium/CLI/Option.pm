package Octium::CLI::Option 0.011;

use Actium ('class');
use Octium;

# it will look for, in this order:

# command-line option
# environment variable
# configuration file
# fallback value specified
# prompt the user

# but each one has to be requested.
# It will never get to the prompt if a fallback value is specified,
# so no point in asking for both

#<<< 

around BUILDARGS ( 
   $orig, $class:
   Octium::CLI :$cmdenv!,
   Str :$envvar,
   Str :$config_section = '_',
   Str :$config_key,
   :$fallback,
   Bool :$display_default = 0,
   slurpy %params,
) {
    
#>>> 

    # Establish default, if any
    my $default;

    if ( defined $envvar ) {
        my $system_name = $cmdenv->system_name;
        $envvar =~ s/\A(?:${system_name}_)*/${system_name}_/;
        $envvar  = uc($envvar);
        $default = $cmdenv->sysenv($envvar);
    }

    if ( not defined $default and defined $config_key ) {
        $default = $cmdenv->config->value(
            section => $config_section,
            key     => $config_key
        );
    }

    if (    defined $default
        and $default eq $EMPTY
        and $params{spec} =~ m/\A [ \w ? \- | ]+ (?: [+!] | \z)/x )
    {
        $default = 1;
    }
    # set default to 1 for simple options found in environment or config file
    # - those with no argument spec, or + or ! argument specs

    if ( not defined $default and defined $fallback ) {
        $default = $fallback;
    }

    if (    defined($default)
        and $display_default
        and exists $params{description} )
    {
        $params{description} .= qq{. If not specified, will use "$default"};
    }
    # There should always be a description, but I want Moose to give that
    # error, not add a check for it here

    $params{default} = $default if defined $default;

    return $class->$orig(%params);

}    ## tidy end: around BUILDARGS

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

Octium::immut;

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

