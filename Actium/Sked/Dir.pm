# Actium/Sked/Dir.pm

# Object representing the scheduled direction (of a trip, or set of trips)

# Subversion: $Id$

# legacy stage 4

use 5.014;
use warnings;

package Actium::Sked::Dir 0.002;

use Moose;
use MooseX::StrictConstructor;

use Actium::Types qw<DirCode>;
use Actium::Util qw<positional_around>;
use Actium::Constants;

use Carp;
use Readonly;
use List::MoreUtils ('mesh');

###################################
#### ENGLISH NAMES FOR DAYS CONSTANTS
###################################

#Readonly my @DIRCODES => qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN ) ;
#Readonly my @HASTUS_DIRS => ( 0, 1, 3, 2, 4.. $#DIRCODES);
# now defined in Actium::Constants

Readonly my @DIRECTIONS => (
   qw(North South West East In Out Go Return Clockwise Counterclockwise),
   'Direction One' , 'Direction Two' , qw(Up Down) , 'A Loop' , 'B Loop',
);

Readonly my @BOUND => (
   qw(Northbound Southbound Westbound Eastbound Inbound Outbound), 
   @DIRECTIONS[ 7 .. $#DIRCODES ],
);

Readonly my %DIRECTION_OF => mesh (@DIRCODES, @DIRECTIONS);
Readonly my %BOUND_OF => mesh (@DIRCODES, @BOUND);
Readonly my %ORDER_OF => mesh @DIRCODES , @{ [ 0 .. $#DIRCODES ] };

use Moose::Util::TypeConstraints;

has 'dircode' => (
    is          => 'ro',
    isa         => DirCode,
);

around BUILDARGS => sub {
    return positional_around( \@_, 'dircode' );
};

sub as_bound {
    my $self      = shift;
    my $dir = $self->dircode;
    return $BOUND_OF{$dir};
}

sub as_direction {
    my $self      = shift;
    my $dircode = $self->dircode;
    return $DIRECTION_OF{$dircode};
}

sub as_sortable {
    my $self      = shift;
    my $dircode = $self->dircode;
    return ('A' .. 'Z')[$ORDER_OF{$dircode}];
}

sub as_to_text {
   my $self = shift;
   my $dircode = $self->dircode;
   
   if ($IS_A_LOOP_DIRECTION{$dircode}) {
       return $self->as_direction . " to";
   }
   
   return "To";

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::Sked::Dir - Object for holding scheduled direction

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Sked::Dir;
 
 my $dir = Actium::Sked::Dir->new ('WB');
 
 say $dir->as_direction; # "West"
 say $days->as_bound; # "Westbound"
 
=head1 DESCRIPTION

This class is used for objects storing scheduled direction information. 
Trips, or timetables, are assigned to particular scheduled directions.

=head1 METHODS

=over

=item B<< Actium::Sked::Dir->new(I<dircode>) >>

The object is constructed using "Actium::Sked::Dir->new".  

It accepts a direction specification, in one of two ways.  As a string:

 NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN
 
Or as a number from 0 to 13, corresponding to the above directions,
except that 2 is "EB" and 3 is "WB". (These are the codes from the Hastus
Standard AVL Interface. This program sorts westbound before eastbound, unlike
Hastus.)

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
Unlike the numeric code passed to I<new()>, this puts 
west before east.

=head1 DEPENDENCIES

=over

=item Perl 5.012 and the standard distribution.

=item List::MoreUtils

=item Moose

=item MooseX::StrictConstructor

=item MooseX::Types

=item Readonly

=item Actium::Constants

=item Actium::Types

=item Actium::Util

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 