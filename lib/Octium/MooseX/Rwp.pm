package Actium::MooseX::Rwp 0.013;

use strict;
use warnings;

use Moose 1.99 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
# use Actium::MooseX::Rwp::Role::Attribute;

my %metaroles = (
    class_metaroles =>
      { attribute => ['Actium::MooseX::Rwp::Role::Attribute'], },
    role_metaroles =>
      { applied_attribute => ['Actium::MooseX::Rwp::Role::Attribute'], },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::Rwp::Role::Attribute 0.013;

use Moose::Role;

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    if ( exists $options->{is} and $options->{is} eq 'rwp' ) {
        if ( not exists $options->{reader} ) {
            $options->{reader} = $name;
        }
        if ( not exists $options->{writer} ) {

            if ( $name =~ s/\A_// ) {
                $options->{writer} = "_set$name";
            }
            else {
                $options->{writer} = "_set_$name";
            }

        }
        delete $options->{is};
    }
};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Actium::MooseX::Rwp - implements "has x => ( is => 'rwp' )"

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::Rwp;
 
 has attribute => (
    is => 'rwp',
 );
 
 # is as though you wrote
 
 has attribute => (
    reader => 'attribute',
    writer => '_set_attribute',
    );
 
=head1 DESCRIPTION

Actium::MooseX::Rwp implements the "rwp" shortcut in Moose, allowing
attributes with private writers but public readers.

=head1 OPTIONS TO 'HAS'

=over

=item C<is => 'rwp'>

This will install a reader in your class with the name of the
attribute, and a writer in your class with the name of your attribute
preceded by "_set_". So, for an attribute called "name", the reader
would be "name" and the writer would be "_set_name".

If the name begins with an underscore, a second underscore will not be
added after "set", so for example "_attribute" would have a writer
called "_set_attribute" and not "_set__attribute".

So this will break if there are two attributes whose names differ only
by an initial underscore. Don't do that. But in any case, it would
usually make more sense to use MooseX::SemiAffordanceAccessor and
express that as just plain "is => 'rw'", rather than use "rwp" with  an
attribute whose name begins with an underscore.

In any event, you can explicitly specify a reader or writer and this
module will not overwrite them.

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

