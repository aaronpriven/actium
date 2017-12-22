package Actium::MooseX::BuilderShortcut 0.014;

use strict;
use warnings;

use Moose 1.99 ();    ### DEP ###
use Moose::Exporter;
use Moose::Util::MetaRole;
use Carp;

# use Actium::MooseX::BuildTriggerShortcuts::Role::Attribute;

my %metaroles = (
    class_metaroles => {
        attribute => ['Actium::MooseX::BuildTriggerShortcuts::Role::Attribute'],
    },
    role_metaroles => {
        applied_attribute =>
          ['Actium::MooseX::BuildTriggerShortcuts::Role::Attribute'],
    },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::BuildTriggerShortcuts::Role::Attribute 0.013;

use Moose::Role;

before '_process_options' => sub {
    my $attribute_metaclass = shift;
    my $name                = shift;
    my $opt                 = shift;

    my ( $builderref, $buildername, $default_triggername );

    if ( $name =~ /\A_/ ) {
        $buildername = "_build$name";
    }
    else {
        $buildername = "_build_$name";
    }

    $opt->{builder} = $buildername
      if exists $opt->{builder}
      and ( $opt->{builder} eq '1' or $opt->{builder} eq '_' );

};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Actium::MooseX::BuilderrShortcut - shortcut in attributes for 
builder

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::BuilderShortcut;
 
 has built_attribute => (
    is => 'ro',
    builder => 1;
    # same as builder => '_build_built_attribute'
 );

=head1 DESCRIPTION

Actium::MooseX::BuilderShortcut allows a shortcut in Moose
"has" attribute specifiers to allow easier specification 
of built attributes.

If the builder option is given as "1", a builder method matching the
name of the attribute will be used instead.

The name of the builder method will be "_build_attributename." 
If the attribute name has an initial underscore, that underscore will
not be duplicated (resulting in "_build_attribute" not
"_build__attribute"). (So this will break if there are two attributes
whose names differ only by an initial underscore. Don't do that.)

=cut

=back

=head1 DEPENDENCIES

=over 

=item *

Moose 1.99 or higher

=item *

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

