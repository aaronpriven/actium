package Octium::Files::HastusASI::Filetype 0.012;

# Class for Hastus ASI filetypes

use warnings;
use 5.012;    # turns on features

use Moose;                        ### DEP ###
use MooseX::StrictConstructor;    ### DEP ###

use namespace::autoclean;         ### DEP ###

has 'id' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has 'tables_r' => (
    is       => 'bare',
    traits   => ['Array'],
    isa      => 'ArrayRef[Str]',
    required => 1,
    handles  => { tables => 'elements', },
);

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Octium::Files::HastusASI::Filetype - Class representing filetypes in 
Hastus AVL Standard Interface

=head1 NOTE

This documentation is intended for maintainers of the Actium system,
not users of it. Run "perldoc Actium" for general information on the
Actium system.

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Octium::Files::HastusASI::Filetype;
 
 my $filetype = 'PAT';
 my @tables = qw/PAT TPS/;
 my $filetype_obj = 
     Octium::Files::HastusASI::Filetype->new(
         id => $filetype ,
         tables_r => \@tables ,
     );
 
 ...
 
 # (in another scope)
 
 my $filetype = $filetype_obj->filetype;
 my @tables = $filetype_obj->tables;
 
=head1 DESCRIPTION

Octium::Files::HastusASI::Filetype is a very simple class holding
information on the file types from a Hastus AVL Standard Interface
export. All attributes are read-only and are expected to be set during
object construction.

It is intended to be used only from
Octium::Files::HastusASI::Definition. All  attributes and methods
should be considered private to that module.

=head1 ATTRIBUTES and METHODS

=over

=item B<new>

As with most Moose classes, the constructor method is called "new".
Invoke it with C<<
Octium:::Files::HastusASI::Filetype->new(%hash_of_attributes) >>.

=item B<id>

Identifier for the filetype. This should be the same as the file's
extension ('PAT' for the trip pattern file, 'NET' for the itinerary
file, etc.).

=item B<tables>

Returns the list of table IDS for tables found in files of this type.
Some will  return just one table ID; others will return more. (In the
constructor, specify tables_r and give a reference to the list of
tables.)

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Moose

=item MooseX::SemiAffordanceAccessor

=item MooseX::StrictConstructor

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

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

