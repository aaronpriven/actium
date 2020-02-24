package Actium::MooseX::BuiltIsRo 0.014;
use strict;
use warnings;

use Moose 1.99 ();
use Moose::Exporter;
use Moose::Util::MetaRole;
# use Actium::MooseX::BuiltIsRO::Role::Attribute;

my %metaroles = (
    class_metaroles =>
      { attribute => ['Actium::MooseX::BuiltIsRO::Role::Attribute'], },
    role_metaroles =>
      { applied_attribute => ['Actium::MooseX::BuiltIsRO::Role::Attribute'], },
);

Moose::Exporter->setup_import_methods(%metaroles);

package Actium::MooseX::BuiltIsRO::Role::Attribute 0.013;

use Moose::Role;

before '_process_options' => sub {
    my $class   = shift;
    my $name    = shift;
    my $options = shift;

    if (not exists $options->{is}
        and (  exists $options->{default}
            or exists $options->{builder}
            or exists $options->{lazy} )
      )
    {
        $options->{is} = 'ro';
    }

};

no Moose::Role;

1;

__END__

=encoding utf8

=head1 NAME

Actium::MooseX::BuiltIsRo - Make built attributes read-only by default

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Moose;
 use Actium::MooseX::BuiltIsRo;
 
 has attribute => (
    default => 'value',
 );
 
 # is as though you had written:

 has attribute => (
    is => 'ro' ,
    default => 'value',
 );

=head1 DESCRIPTION

Actium::MooseX::BuiltIsRo  ensures that if either "lazy," "builder," or
"default" is supplied, but there is no "is" option supplied, the
attribute will be set to be read-only ("is => 'ro'").

Any supplied "is" option, such as "is => 'bare'" or "is => 'rw'", will
be left intact.

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

