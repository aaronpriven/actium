# Actium/HeadwayPage.pm

# Routines to process headway sheet pages

# Subversion: $Id$

package Actium::HeadwayPage;

use 5.010;

use utf8;
our $VERSION = '0.001';
$VERSION = eval $VERSION;

#use Term::Emit qw(:all);
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose;
use Moose::Util::TypeConstraints;
use Actium::Constants;
use Actium::Term;
use Actium::Sked; 
use Text::Trim();
use Actium::Trip;
use Actium::Util qw<:ALL>;
use Actium::AttributeHandlers qw<:all>;

has 'line_r' => (
    traits   => ['Array'],
    is       => 'rw',
    isa      => 'ArrayRef[Str]',
    default  => sub { [] },
    required => 1,
    handles  => { arrayhandles('line') },

);

has 'place8_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    handles => { arrayhandles('place8') },
);

has [qw<linedescrip origlinegroup direction days>] => (
    is  => 'rw',
    isa => 'Str',
);

has 'trip_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Actium::Trip]',
    default => sub { [] },
    handles => { arrayhandles('trip') },
);

#has [qw(direction_idx route_idx)] => (
#    is  => 'rw',
#    isa => 'Int',
#);

sub insert_blank_final_column {
    my $self = shift;

    foreach my $trip ( $self->trips() ) {
        $trip->push_placetime($EMPTY_STR);
    }
    return;
}

sub insert_blank_column_before {
    my $self  = shift;
    my $index = shift;

    foreach my $trip ( $self->trips() ) {
        $trip->insert_placetime( $index, $EMPTY_STR );
    }
    return;

}

sub origlinegroup_and_dir {
    my $self = shift;
    return join( $KEY_SEPARATOR, $self->origlinegroup, $self->direction );
}

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    return $class->$orig( { line_r => [@_] } );

};

sub sked {
    my $self = shift;

    my $sked = Actium::Sked->new(
        place8_r      => $self->place8_r(),
        origlinegroup => $self->origlinegroup(),
        linedescrip   => $self->linedescrip(),
        direction     => $self->direction(),
        days          => $self->days(),
        trip_r        => $self->trip_r(),
    );

    return $sked;

}


no Moose::Util::TypeConstraints;
no Moose;
__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

1;

=head1 NAME

Actium::Headways::Page - Page objects for headway sheet processing

=head1 VERSION

This documentation refers to Actium::Headways::Page version 0.001

=head1 SYNOPSIS

 use Actium::Headways::Page;

   $headwayfileobject->add_page(
      Actium::Headways::Page->new(
         {   route_idx     => $self->route_idx(),
             direction_idx => $self->direction_idx(),
             lines         => [@lines_in_this_page],
         }
      )
   );;
   
=head1 DESCRIPTION

This is a Moose class, representing each page of a headway sheet file. It is 
an intermediate form used when processing pages in headway sheets.  

For more information on headway sheets, see L<Actium::Headways>.

=head1 ATTRIBUTES

=over

=item B<line>



=back

=head1 DIAGNOSTICS

See L<Moose>.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.

