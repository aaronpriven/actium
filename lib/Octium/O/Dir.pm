package Octium::O::Dir 0.012;

# Object representing the scheduled direction (of a trip, or set of trips)

use Actium ('class');
use Octium;
use MooseX::Storage;    ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );

use Octium::Types qw<DirCode>;

# if you supply this with "1", it's going to think you mean Hastus AVL "1"
# (i.e., "SB") instead of "D1".

const my %IS_A_LOOP_DIRECTION => ( CW => 1, CC => 1, A => 1, B => 1 );

const my @HASTUS_DIRS => ( 0, 1, 3, 2, 4 .. scalar @DIRCODES );

const my %DIRCODE_OF => (
    ( map { lc($_) => $_ } @DIRCODES ),
    ( map { $HASTUS_DIRS[$_], $DIRCODES[ $HASTUS_DIRS[$_] ] } 0 .. $#DIRCODES ),
    'ccw'           => 'CC',
    'clock'         => 'CW',
    'counterclo'    => 'CC',
    'counterclock'  => 'CC',
    'direction one' => 'D1',
    'direction two' => 'D2',
    'da'            => 'A',
    'db'            => 'B',
    'down'          => 'DN',
    'ea'            => 'EB',
    'east'          => 'EB',
    'in'            => 'IN',
    'inb'           => 'IN',
    'outb'          => 'OU',
    'inw'           => 'IN',
    'outw'          => 'OU',
    'no'            => 'NB',
    'north'         => 'NB',
    'out'           => 'OU',
    'return'        => 'RT',
    'so'            => 'SB',
    'south'         => 'SB',
    'up'            => 'UP',
    'we'            => 'WB',
    'west'          => 'WB',
);

my %obj_cache;

sub instance {
    my $class          = shift;
    my $orig_direction = shift;

    if ( exists $obj_cache{$orig_direction} ) {
        return $obj_cache{$orig_direction};
    }

    my $direction = lc($orig_direction);

    for ($direction) {
        s/\Adir/d/;
        s/bound\z//;
        s/ward\z//;
        s/wise\z//;
    }

    if ( not exists $DIRCODE_OF{$direction} ) {
        croak "Unknown direction $direction";
    }

    my $instance = $class->new( dircode => $DIRCODE_OF{$direction} );
    $obj_cache{$orig_direction} = $instance;
    return $instance;

}    ## tidy end: sub instance

####################
### Utility methods
####################

sub linedir {
    my $invocant = shift;
    my $line     = shift;

    my $self;

    if ( Actium::blessed $invocant) {
        $self = $invocant;
    }
    else {
        # invocant is class
        my $direction = shift;
        $self = $invocant->instance($direction);
    }
    return "$line." . $self->dircode;

}
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

const my %DIRECTION_OF => Actium::mesh( @DIRCODES, @DIRECTIONS );
const my %BOUND_OF     => Actium::mesh( @DIRCODES, @BOUND );
const my %ORDER_OF => Actium::mesh @DIRCODES, @{ [ 0 .. $#DIRCODES ] };

has 'dircode' => (
    is  => 'ro',
    isa => DirCode,
);

sub _data_printer {
    my $self  = shift;
    my $class = Actium::blessed($self);
    return "$class=" . $self->dircode;
}

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

const my %ONECHAR_DIRECTION_OF => qw(
  A   A
  B   B
  CC  9
  CW  8
  D1  1
  D2  2
  DN  D
  EB  E
  GO  G
  IN  I
  NB  N
  OU  O
  RT  R
  SB  S
  UP  U
  WB  W
);

sub as_onechar {
    my $self    = shift;
    my $dircode = $self->dircode;
    return $ONECHAR_DIRECTION_OF{$dircode};
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

    return not Actium::in( $self->dircode, qw/NB SB EB WB/ );

}

Actium::immut;

1;

__END__

=head1 NAME

Octium::O::Dir - Object for holding scheduled direction

=head1 VERSION

This documentation refers to version 0.010

=head1 SYNOPSIS

 use Octium::O::Dir;
 
 my $dir = Octium::O::Dir->instance ('WB');
 
 say $dir->as_direction; # "West"
 say $days->as_bound; # "Westbound"
 
=head1 DESCRIPTION

This class is used for objects storing scheduled direction information.
 Trips, or timetables, are assigned to particular scheduled directions.

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These
objects are immutable.

=head1 METHODS

=over

=item B<< Octium::O::Dir->instance(I<dircode>) >>

The object is constructed using "Octium::O::Dir->instance".

It accepts a direction string. In general, the directions are as
follows:

 Direction         Code         Hastus Standard AVL code
 ---------         ----         ------------------------
 North             NB           0
 South             SB           1
 West              WB           3
 East              EB           2      
 In                IN           4
 Out               OU           5
 Go                GO           6
 Return            RT           7
 Clock             CW           8
 Counterclock      CC           9
 Direction One     D1           10
 Direction Two     D2           11
 Up                UP           12
 Down              DN           13
 A                 A            14
 B                 B            15
 
The 'Code' is the code used by 'dircode', below. This is the sort order
that is used by this program -- the Hastus Standard AVL code is the
code from the Hastus Standard AVL interface, and this program sorts
westbound before eastbound, unlike Hastus.

The ->instance method will accept any of these as inputs,
case-insensitively, will strip a final "bound", "ward", or "wise" from
any of them, and replaces a leading "dir" with just "d". In addition,
it accepts:

  Abbreviation    Meaning
  ------------    ------------
  CCW             Counterclock
  Counterclo      Counterclock
  DA              A
  DB              B
  Ea              East
  No              North
  So              South
  We              West


=item B<< Octium::O::Dir->new(I<dircode>) >>

B<< Do not use this method. >>

This method is used internally by Octium::O::Days to create a new
object and insert it into the cache used by instance(). There should
never be a reason to create more than one object with the same
arguments.

=item B<< $obj->dircode >>

Returns the direction code, as above.

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
   
At this point I don't think "Clockwisebound" or "Upbound" make much
sense, but this may change.

=item B<< $obj->as_sortable >>

Returns a code corresponding to the directions in order, suitable for
sorting using perl's cmp operator. Unlike the numeric code passed to
I<instance()>, this puts  west before east.

=back

=head1 DEPENDENCIES

=over

=item Perl 5.022 and the standard distribution.

=item Actium

=item Moose

=item Octium::Types

=back

=head1 BUGS AND LIMITATIONS

Supplying the ->instance() routine with "1" is somewhat ambiguous: it 
could mean Hastus Stnadard AVL direction 1, which is "southbound," or
it could mean "Direction 1" (which is used for supervisor orders). At
the moment it  treats it as though it were the Hastus AVL direction.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

