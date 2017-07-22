package Actium::MooseX::PredicateClearerShortcuts 0.014;

use strict;
use warnings;

use Moose 1.99 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
# use Actium::MooseX::PredicateClearerShortcuts::Role::Attribute;

my %metaroles = (
    class_metaroles => {
        attribute =>
          ['Actium::MooseX::PredicateClearerShortcuts::Role::Attribute'],
    },
    role_metaroles => {
        applied_attribute =>
          ['Actium::MooseX::PredicateClearerShortcuts::Role::Attribute'],
    },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::PredicateClearerShortcuts::Role::Attribute 0.014;

use Moose::Role;

my %prefix = (
    predicate => 'has',
    clearer   => 'clear',
);

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    my $private_attr = ( $name =~ /\A_/ );

    my $suffix = ( $private_attr ? q{_} : q{} ) . $name;

    foreach my $option (qw/predicate clearer/) {
        if ( exists $options->{$option} ) {
            if ( $options->{$option} eq '_'
                or ( $private_attr and 1 eq $options->{$option} ) )
            {
                $options->{$option} = '_' . $prefix{$option} . $suffix;
            }
            elsif ( 1 eq $options->{$option} ) {
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

Actium::MooseX::PredicateClearerShortcuts - supply default predicate
and clearer names

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::PredicateClearerShortcuts;
 
 has attribute => (
    is => 'ro',
    predicate => 1,
    clearer => '_',
 );
 
 # the same as if you had written
 
 has attribute => (
    is => 'ro',
    predicate => 'has_attribute',
    clearer => '_clear_attribute',
 );
 
=head1 DESCRIPTION

Actium::MooseX::PredicateClearerShortcuts allows several shortcuts in
Moose "has" attribute specifiers to allow easier specification of 
predicate or clearer methods, when those methods have conventional
names.

=head2 CONVENTIONAL NAMES

Double-underscores are avoided, so that even if an attribute is called
"_attribute", the associated methods will be "_build_attribute",
"_trigger_attribute", etc., not "_build__attribute."

(So this will break if there are two attributes whose names differ only
by an initial underscore. Don't do that.)

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

