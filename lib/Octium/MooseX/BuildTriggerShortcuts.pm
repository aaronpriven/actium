package Octium::MooseX::BuildTriggerShortcuts 0.014;

use strict;
use warnings;

use Moose 1.99 ();    ### DEP ###
use Moose::Exporter;
use Moose::Util::MetaRole;
use Carp;

# use Octium::MooseX::BuildTriggerShortcuts::Role::Attribute;

my %metaroles = (
    class_metaroles => {
        attribute => ['Octium::MooseX::BuildTriggerShortcuts::Role::Attribute'],
    },
    role_metaroles => {
        applied_attribute =>
          ['Octium::MooseX::BuildTriggerShortcuts::Role::Attribute'],
    },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Octium::MooseX::BuildTriggerShortcuts::Role::Attribute 0.013;

use Moose::Role;
use Ref::Util('is_coderef');    ### DEP ###

before '_process_options' => sub {
    my $class = shift;
    my $name  = shift;
    my $opt   = shift;

    my ( $builderref, $buildername, $default_triggername );

    if ( $name =~ /\A_/ ) {
        $buildername         = "_build$name";
        $default_triggername = "_trigger$name";
    }
    else {
        $buildername         = "_build_$name";
        $default_triggername = "_trigger_$name";
    }

    if ( exists $opt->{trigger}
        and not is_coderef( $opt->{trigger} ) )
    {
        my $metamethod;
        if ( $opt->{trigger} eq '1' or $opt->{trigger} eq '_' ) {
            $metamethod = $class->meta->get_method($default_triggername);
            croak(  "Can't find default trigger "
                  . "method $default_triggername in $class" )
              if not defined $metamethod;
        }
        else {
            $metamethod = $class->meta->get_method( $opt->{trigger} );
            croak(
                "Can't find trigger method " . $opt->{trigger} . " in $class" )
              if not defined $metamethod;
        }
        $opt->{trigger} = $metamethod->body;
    }

    $opt->{builder} = $buildername
      if exists $opt->{builder}
      and ( $opt->{builder} eq '1' or $opt->{builder} eq '_' );

    if ( exists $opt->{lazy} ) {
        if ( is_coderef( $opt->{lazy} ) ) {
            $builderref = $opt->{lazy};
            $opt->{lazy} = 1;
        }
        elsif ( $opt->{lazy} eq '_' ) {
            $opt->{builder} //= $buildername;
            $opt->{lazy} = 1;
        }
    }

    if ( exists $opt->{builder} and is_coderef( $opt->{builder} ) ) {
        $builderref = $opt->{builder};
        $opt->{builder} = $buildername;
    }

    if ($builderref) {
        $class->meta->add_method( $opt->{builder} => $builderref );
    }

    #if ( ( exists $opt->{builder} or exists $opt->{default} )
    #    and not exists $opt->{init_arg} )
    #{
    #    $opt->{init_arg} = undef;
    #}
    #elsif ( exists $opt->{init_arg}
    #    and defined( $opt->{init_arg} )
    #    and $opt->{init_arg} eq '1' )
    #{
    #    $opt->{init_arg} = $name;
    #}

    # I don't understand why this doesn't work --
    # it complaints that there shouldn't be an init_arg... But other
    # options use it.

};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Octium::MooseX::BuildTriggerShortcuts - shortcuts in attributes for 
builder, lazy, and trigger

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Octium::MooseX::BuildTriggerShortcuts;
 
 has lazy_attribute => (
    is => 'ro',
    lazy => sub { some_expensive_operation() },
 );
 
 has built_attribute => (
    is => 'ro',
    builder => sub { some_other_operation() },
 );

 has triggered_attribute => (
    is => 'ro',
    trigger => sub { yet_another_operation() },
 );
 
=head1 DESCRIPTION

Octium::MooseX::BuildTriggerShortcuts allows several shortcuts in Moose
"has" attribute specifiers to allow easier specification of lazy,
built, or triggered attributes.

A coderef for a builder can be supplied in the "lazy" or "builder"
options to the "has" call, and a coderef for a trigger can be supplied
in the  "trigger" option to that call. They will use default builder
and trigger names, as shown below.

This allows the option and its builder to be specified together, as is
already possible using "default => sub {...}", but unlike "default",
named builders can have method modifiers applied or be overridden by a
subclass.

=head2 DEFAULT BUILDER AND TRIGGER NAME

The default name of the builder method will be "_build_attributename," 
and the default name of the trigger method trigger method will be 
"_trigger_attributename".

If the attribute name has an initial underscore, that underscore will
not be duplicated (resulting in "_build_attribute" not
"_build__attribute"). (So this will break if there are two attributes
whose names differ only by an initial underscore. Don't do that.)

=head1 OPTIONS TO 'HAS'

=over

=item C<lazy => sub { ... }> 

Unless a builder option is also provided, the coderef given is
installed in the class as the builder, using the default builder name
as given above. The attribute will be marked as lazy (as though "lazy
=> 1" had been specified).

If a builder option is supplied, and that option is a string (not a
coderef), then that string is used as the name instead of the default
builder name. The attribute will still be marked as lazy.

If a builder option is also provided, and that option is a coderef, the
coderef supplied in "lazy" is ignored, but the attribute is still
marked as lazy.

=item C<lazy => '_'> 

Unless a builder option is also provided, the attribute will be marked
as lazy, and the builder option will be set to the default builder name
(above).

If a builder option is also specified, then this is the same as (lazy
=> 1).

=item C<< builder => 1 >> or C<< builder => '_' >>

The default builder name (see above) is used for the builder.

=item C<builder => sub { ... }> 

The coderef given is installed in the class as the builder, using the
default builder name as given above.

=item C<< trigger => 1 >> or C<< trigger => '_' >> 

The default trigger name (see above) is used for the trigger.

=item C<trigger => sub { ... }> 

The coderef given is installed in the class as the trigger, using the
default trigger name as given above.

=item C<init_arg>

B<This isn't working right now.>

If either a builder or default is specified (whether explicitly or
through a coderef or underscore argument to "lazy"), the init_arg
option will be set to the undefined value, unless it is set explicitly.
 Providing the value  "1" to init_arg will restore the default value of
the attribute name.

=cut

=back

=head1 DEPENDENCIES

=over 

=item *

Moose 1.99 or higher

=item *

Ref::Util

=back

=head1 ACKNOWLEDGEMENTS

This module is an adaptaion of Dave Rolsky's
MooseX::SemiAffordanceAccessor.

=head1 SEE ALSO

MooseX::MungeHas, MooseX::AttributeShortcuts. These are more
complicated modules that do a lot of things in a single role. I have
preferred simple roles that do just one or two things without
interfering with other roles.

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
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

