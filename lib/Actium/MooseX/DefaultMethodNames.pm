package Actium::MooseX::DefaultMethodNames 0.013;

use strict;
use warnings;

use Moose 1.99 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
# use Actium::MooseX::DefaultMethodNames::Role::Attribute;

my %metaroles = (
    class_metaroles =>
      { attribute => ['Actium::MooseX::DefaultMethodNames::Role::Attribute'], },
    role_metaroles => {
        applied_attribute =>
          ['Actium::MooseX::DefaultMethodNames::Role::Attribute'],
    },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::DefaultMethodNames::Role::Attribute 0.013;

use Moose::Role;

# trigger and build are always private, since they should not be called
# outside the class, but predicate and clearer could be public, or not

my %prefix = (
    trigger   => 'trigger',
    builder   => 'build',
    predicate => 'has',
    clearer   => 'clear',
);

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    my $suffix = $name;
    if ( $suffix !~ /\A_/ ) {
        $suffix = '_' . $suffix;
    }

    foreach my $option (qw/trigger builder/) {
        if ( exists $options->{$option}
            and ( '_' eq $options->{$option} or 1 == $options->{$option} ) )
        {
            $options->{$option} = '_' . $prefix{$option} . $suffix;
        }
    }

    foreach my $option (qw/predicate clearer/) {
        if ( exists $options->{$option} ) {
            if ( $options->{$option} eq '_'
                or ( 1 == $options->{$option} and $name =~ /\A_/ ) )
            {
                $options->{$option} = '_' . $prefix{$option} . $suffix;
            }
            elsif ( 1 == $options->{$option} ) {
                $options->{$option} = $prefix{$option} . $suffix;
            }
        }

    }
};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Actium::MooseX::DefaultMethodNames - supply default names for Moose
attributes

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::DefaultMethodNames;
 
 has attribute => (
    is => 'ro',
    trigger => 1,
    builder => 1,
    predicate => 1,
    clearer => '_',
 );
 
 # the same as if you had written
 
 has attribute => (
    is => 'ro',
    trigger => '_trigger_attribute',
    builder => '_build_attribute',
    predicate => 'has_attribute',
    clearer => '_clear_attribute',
 );
 
=head1 DESCRIPTION

Actium::MooseX::DefaultMethodNames allows several shortcuts in Moose
"has" attribute specifiers to allow easier specification of trigger,
builder, predicate, or clearer methods, when those methods have
conventional names.

=head2 CONVENTIONAL NAMES

Double-underscores are avoided, so that even if an attribute is called
"_attribute", the associated methods will be "_build_attribute",
"_trigger_attribute", etc., not "_build__attribute."

(So this will break if there are two attributes whose names differ only
by  an initial underscore. Don't do that.)

=over

=item C<< predicate => 1 >>
=item C<< clearer => 1 >>

These are given names "has_I<attributename>" and
"clear_I<attributename>",  respectively. If the attribute name has a
leading underscore, the methods will too: "_has_I<attributename>" and
"_clear_I<attributename>",

=item C<< predicate => '_' >>
=item C<< clearer => '_' >>

Specifying an underscore instead of 1 will make these methods private
(with a leading underscore) instead of public, even if the attribute
itself is public: so an attribute called "name" will be given methods
"_has_name" and "_clear_name".

=item C<< trigger => 1 >>
=item C<< builder => 1 >>
=item C<< trigger => '_' >>
=item C<< builder => '_' >>

These are always given an underscore in front, whether or not the
attribute is private and whether or not the underscore or 1 is given in
the option to "has", since conventionally triggers and builders are not
part of a class's interface.

The default nams are "_trigger_I<attributename>" and
"_build_<attributename>".

=back

=head1 DEPENDENCIES

=over 

=item *

Moose 1.99 or higher

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

