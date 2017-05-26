package Actium::MooseX::IsCodeRef 0.014;

use strict;
use warnings;

use Moose 1.99 ();    ### DEP ###
use Moose::Exporter;
use Moose::Util::MetaRole;
use Ref::Util('is_coderef');    ### DEP ###
# use Actium::MooseX::IsCodeRef::Role::Attribute;

my %metaroles = (
    class_metaroles =>
      { attribute => ['Actium::MooseX::IsCodeRef::Role::Attribute'], },
    role_metaroles =>
      { applied_attribute => ['Actium::MooseX::IsCodeRef::Role::Attribute'], },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::IsCodeRef::Role::Attribute 0.013;

use Moose::Role;

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    my ( $builderref, $buildername );

    if ( $name =~ /\A_/ ) {
        $buildername = "_build$name";
    }
    else {
        $buildername = "_build_$name";
    }

    if ( exists $options->{lazy} ) {
        if ( is_coderef( $options->{lazy} ) ) {
            $builderref = $options->{lazy};
            $options->{lazy} = 1;
        }
        elsif ( $options->lazy eq '_' ) {
            $options->{builder} //= $buildername;
            $options->{lazy} = 1;
        }
    }

    if ( exists $options->{builder} ) {
        if ( is_coderef( $options->{builder} ) ) {
            $builderref = $options->{builder};
        }
        else {
            $buildername = $options->{builder};
        }
    }

    if ($builderref) {
        $class->meta->add_method( $buildername => $builderref );
        $options->{builder} //= $buildername;
    }

};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Actium::MooseX::IsCodeRef - shortcuts in attributes for builder and
lazy

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::IsCodeRef;
 
 has lazy_attribute => (
    is => 'ro',
    lazy => sub {  some_expensive_operation() },
 );
 
 has built_attribute => (
    is => 'ro',
    builder => sub { some_other_operation() },
 );
 
=head1 DESCRIPTION

Actium::MooseX::IsCodeRef allows several shortcuts in Moose "has"
attribute  specifiers to allow easier specification of lazy or built
attributes.

A coderef for a builder can be supplied directly in the "has"
attribute, and a default builder name can be supplied in the "lazy"
option.  That code reference will be installed in the class as a
method, and that method set to be the attribute's builder. This allows
the option and its builder to be specified together, as is already
possible using "default => sub {...}", but unlike "default", named
builders can have method modifiers applied or be overridden by a
subclass.

If the "lazy" option is set to "_", then the builder name will be set
to the  default builder name.

=head2 DEFAULT BUILDER NAME

The name of the method will be "_build_attributename" unless the
coderef is  given in the "lazy" option and another name is given in the
"builder" option. If the attribute name has an initial underscore, that
underscore will not  be duplicated (resulting in "_build_attribute" not
"_build__attribute").  (So this will break if there are two attributes
whose names differ only by  an initial underscore. Don't do that.)

=head1 OPTIONS TO 'HAS'

=over

=item C<lazy => sub { ... }> 

Unless a builder option is also provided, the coderef given is
installed in the class as the builder, using the default builder name
as given above. The attribute will be marked as lazy (as though "lazy
=> 1" had been specified).

If a builder option is supplied, and that option is a string (not a
coderef),  then that string is used as the name instead of the default
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

=item C<builder => sub { ... }> 

The coderef given is installed in the class as the builder, using the
default builder name as given above.

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
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

