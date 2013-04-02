# Actium/HeadwayPage.pm

# Routines to process headway sheet pages

# Subversion: $Id$

package Actium::O::Sked::HeadwayPage;

use 5.010;

use utf8;
our $VERSION = '0.001';
$VERSION = eval $VERSION;

#use Term::Emit qw(:all);
use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;
use Actium::Constants;
use Actium::Term;
use Actium::O::Sked;
use Text::Trim();
use Actium::O::Sked::Trip;
use Actium::Util qw<:all>;

use List::MoreUtils ('uniq');

has 'line_r' => (
    traits   => ['Array'],
    is       => 'bare',
    isa      => 'ArrayRef[Str]',
    default  => sub { [] },
    required => 1,
    handles  => {
        line       => 'get',
        line_count => 'count',
        set_line   => 'set',
        lines      => 'elements',
        push_lines => 'push',
    },

);

has 'place8_r' => (
    traits => ['Array'],
    is     => 'rw',
    isa    => 'ArrayRef[Str]',
    handles =>
      { place8s => 'elements', place8 => 'get', splice_place8s => 'splice' },
);

has [qw<linedescrip origlinegroup direction days>] => (
    is  => 'rw',
    isa => 'Str',
);

has 'trip_r' => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Actium::O::Sked::Trip]',
    default => sub { [] },
    handles => {
        push_trips  => 'push',
        trips       => 'elements',
        trip_count  => 'count',
        trip        => 'get',
        set_trip    => 'set',
        delete_trip => 'delete',
    },
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

    # Convert day strings with exceptions to # Actium::O::Day objects
    
    my ($day_obj, @daysexceptions );
    
    @daysexceptions = uniq ( map { $_->daysexceptions } $self->trips) ;
    
    
    if (@daysexceptions == 1 ) {
        given ($daysexceptions[0]) {
         when ('SD') {
            $day_obj = Actium::O::Days->new($self->days, 'D');
         }
         when ('SH') {
            $day_obj = Actium::O::Days->new($self->days, 'H');
         }
         default {
            $day_obj = Actium::O::Days->new($self->days);
         }
        }
    }
    else {
            $day_obj = Actium::O::Days->new($self->days);
    }
    
    my $sked = Actium::O::Sked->new(
        place8_r      => $self->place8_r(),
        origlinegroup => $self->origlinegroup(),
        linedescrip   => $self->linedescrip(),
        direction     => $self->direction(), # coerces string to object
        days          => $day_obj,
        trip_r        => $self->trip_r(),
    );

    return $sked;

} ## tidy end: sub sked

no Moose::Util::TypeConstraints;
no Moose;
__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

1;

=head1 NAME

Actium::O::HeadwayPage - Page objects for headway sheet processing

=head1 VERSION

This documentation refers to Actium::O::HeadwayPage version 0.001

=head1 SYNOPSIS

 use Actium::O::HeadwayPage;

   $headwayfileobject->add_page(
      Actium::O::HeadwayPage->new(
         {   route_idx     => $self->route_idx(),
             direction_idx => $self->direction_idx(),
             lines         => [@lines_in_this_page],
         }
      )
   );;
   
=head1 DESCRIPTION

This is a Moose class, representing each page of a headway sheet file. It is 
an intermediate form used when processing pages in headway sheets.  

For more information on headway sheets, see L<Actium::Cmd::Headways>.

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

