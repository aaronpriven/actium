package Actium::O::Dir 0.010;

# Object representing the scheduled direction (of a trip, or set of trips)

use 5.022;
use warnings;

package Actium::O::Dir 0.010;

use Actium::Moose;
use MooseX::Storage;    ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );
with 'MooseX::Role::Flyweight';
# MooseX::Role::Flyweight ### DEP ###

use Actium::Types qw<DirCode>;

###################################
#### ENGLISH NAMES FOR DAYS CONSTANTS
###################################

const my @DIRECTIONS => (
    qw(North South West East In Out Go Return Clockwise Counterclockwise),
    'Direction One',
    'Direction Two',
    qw(Up Down), 'A Loop', 'B Loop',
);

const my @BOUND => (
    qw(Northbound Southbound Westbound Eastbound Inbound Outbound),
    @DIRECTIONS[ 6 .. $#DIRCODES ],
);

const my %DIRECTION_OF => u::mesh( @DIRCODES, @DIRECTIONS );
const my %BOUND_OF     => u::mesh( @DIRCODES, @BOUND );
const my %ORDER_OF => u::mesh @DIRCODES, @{ [ 0 .. $#DIRCODES ] };

has 'dircode' => (
    is  => 'ro',
    isa => DirCode,
);

around BUILDARGS => sub {
    return u::positional_around( \@_, 'dircode' );
};

sub as_bound {
    my $self = shift;
    my $dir  = $self->dircode;
    return $BOUND_OF{$dir};
}

sub as_direction {
    my $self    = shift;
    my $dircode = $self->dircode;
    return $DIRECTION_OF{$dircode};
}

sub as_sortable {
    my $self    = shift;
    my $dircode = $self->dircode;
    return ( 'A' .. 'Z' )[ $ORDER_OF{$dircode} ];
}

sub as_to_text {
    my $self    = shift;
    my $dircode = $self->dircode;

    if ( exists $IS_A_LOOP_DIRECTION{$dircode} ) {
        return $self->as_direction . " to";
    }

    return "To";

}

sub should_preserve_direction_order {
    my $self    = shift;
    my $dircode = $self->dircode;

    return not u::in( $self->dircode, qw/NB SB EB WB/ );

}

u::immut;

1;

__END__

=head1 NAME

Actium::O::Dir - Object for holding scheduled direction

=head1 VERSION

This documentation refers to version 0.010

=head1 SYNOPSIS

 use Actium::O::Dir;
 
 my $dir = Actium::O::Dir->instance ('WB');
 
 say $dir->as_direction; # "West"
 say $days->as_bound; # "Westbound"
 
=head1 DESCRIPTION

This class is used for objects storing scheduled direction information. 
Trips, or timetables, are assigned to particular scheduled directions.

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These objects
are immutable.

=head1 METHODS

=over

=item B<< Actium::O::Dir->instance(I<dircode>) >>

The object is constructed using "Actium::O::Dir->instance".  

It accepts a direction specification, in one of two ways.  As a string:

 NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN
 
Or as a number from 0 to 13, corresponding to the above directions,
except that 2 is "EB" and 3 is "WB". (These are the codes from the Hastus
Standard AVL Interface. This program sorts westbound before eastbound, unlike
Hastus.)

=item B<< Actium::O::Dir->new(I<dircode>) >>

B<< Do not use this method. >>

This method is used internally by Actium::O::Days to create a new object and
insert it into the cache used by instance(). There should never be a reason
to create more than one method with the same arguments.

=item B<< $obj->dircode >>

Returns the direction code, as the string given above.

=item B<< $obj->as_direction >>

Returns one of the following, corresponding to the direction:

   North           South    
   West            East 
   In              Out      
   Go              Return 
   Clockwise       Counterclockwise
   Direction One   Direction Two
   Up              Down

=item B<< $obj->as_bound >>

Returns one of the following, corresponding to the direction:

   Northbound      Southbound
   Westbound       Eastbound
   Inbound         Outbound 
   Go              Return 
   Clockwise       Counterclockwise
   Direction One   Direction Two
   Up              Down
   
At this point I don't think "Clockwisebound" or "Upbound" make much sense, but
this may change.
   
=item B<< $obj->as_sortable >>

Returns a code corresponding to the directions in order,
suitable for sorting using perl's cmp operator.
Unlike the numeric code passed to I<instance()>, this puts 
west before east.

=back

=head1 DEPENDENCIES

=over

=item Perl 5.022 and the standard distribution.

=item Actium::Moose

=item Actium::Types

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 