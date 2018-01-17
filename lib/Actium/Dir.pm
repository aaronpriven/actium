package Actium::Dir 0.015;

# Object representing the scheduled direction (of a trip, or set of trips)

=encoding utf8

=head1 NAME

Actium::Dir - Object for holding scheduled direction

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use Actium::Dir;
 
 my $dir = Actium::Dir->instance ('WB');
 
 say $dir->as_direction; # "West"
 say $days->as_bound; # "Westbound"
 
=head1 DESCRIPTION

This class is used for objects storing scheduled direction information.
Trips, or timetables, are assigned to particular scheduled directions.

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These
objects are immutable.

=cut

use Actium ('class');
use Types::Standard qw( Str );

## no critic 'ProhibitConstantPragma'
use constant {
    ORDER          => 0,
    HASTUS_ORDER   => 1,
    ONE_CHAR       => 2,
    DIRECTION      => 3,
    BOUND          => 4,
    TO_TEXT        => 5,
    PRESERVE_ORDER => 6,
    IS_LOOP        => 7,
};
## use critic

const my %DIRDATA => (
    NB => [ 1, 1, N => 'North',     'Northbound', 'To',           0, 0 ],
    SB => [ 2, 2, S => 'South',     'Southbound', 'To',           0, 0 ],
    WB => [ 3, 4, W => 'West',      'Westbound',  'To',           0, 0 ],
    EB => [ 4, 3, E => 'East',      'Eastbound',  'To',           0, 0 ],
    IN => [ 5, 5, I => 'In',        'Inbound',    'To',           1, 0 ],
    OU => [ 6, 6, O => 'Out',       'Outbound',   'To',           1, 0 ],
    GO => [ 7, 7, G => 'Go',        'Going',      'To',           1, 0 ],
    RT => [ 8, 8, R => 'Return',    'Returning',  'To',           1, 0 ],
    CW => [ 9, 9, 8 => 'Clockwise', 'Clockwise',  'Clockwise to', 1, 1 ],
    CC => [
        10,
        10,
        9 => 'Counterclockwise',
        'Counterclockwise', 'Counterclockwise to', 1, 1,
    ],
    D1 => [ 11, 11, 1 => 'Direction One', 'Direction One', 'To',        1, 0 ],
    D2 => [ 12, 12, 2 => 'Direction Two', 'Direction Two', 'To',        1, 0 ],
    UP => [ 13, 13, U => 'Up',            'Going up',      'To',        1, 0 ],
    DN => [ 14, 14, D => 'Down',          'Going down',    'To',        1, 0 ],
    A  => [ 15, 15, A => 'A Loop',        'A Loop',        'A Loop to', 1, 1 ],
    B  => [ 16, 16, B => 'B Loop',        'B Loop',        'B Loop to', 1, 1 ],
);

const my %DIR_OF_ALIAS => (
    NO            => 'NB',
    SO            => 'SB',
    WE            => 'WB',
    EA            => 'EB',
    INB           => 'IN',
    INW           => 'IN',
    OUTB          => 'OU',
    OUTW          => 'OU',
    CLOCK         => 'CW',
    CCW           => 'CC',
    COUNTERCLO    => 'CC',
    COUNTERCLOCK  => 'CC',
    'DIRECTION 1' => 'D1',
    'DIRECTION 2' => 'D2',
    'DIR1'        => 'D1',
    'DIR2'        => 'D2',
    ONE           => 'D1',
    TWO           => 'D2',
    DA            => 'A',
    DB            => 'B',
    ( map { $DIRDATA{$_}[HASTUS_ORDER]    => $_ } keys %DIRDATA ),
    ( map { uc( $DIRDATA{$_}[DIRECTION] ) => $_ } keys %DIRDATA ),
    ( map { $_                            => $_ } keys %DIRDATA ),
);

=head1 CLASS METHODS

=head2 instance

 Actium::Dir->instance('direction')

The object is constructed using "Actium::Dir->instance".

It accepts a direction string. In general, the directions are as
follows:

 Direction           Code         Hastus Standard AVL code
 ---------           ----         ------------------------
 North               NB           0
 South               SB           1
 West                WB           3
 East                EB           2      
 In                  IN           4
 Out                 OU           5
 Go                  GO           6
 Return              RT           7
 Clockwise           CW           8
 Counterclockwise    CC           9
 Direction One       D1           10
 Direction Two       D2           11
 Up                  UP           12
 Down                DN           13
 A Loop              A            14
 B Loop              B            15

These are listed in the sort order used by this program.  (Note that
unlike Hastus, it sorts west before east.)

Also note that specifying "1" will give South, not Direction One,
because Hastus Standard AVL Export numeric directions are accepted.

The method is case-insensitive, and will accept either the direction,
the code, the Hastus numeric code, or any of the following
abbreviations:

  Abbreviation       Meaning
  ------------       ------------

    NO               North
    SO               South
    WE               West
    EA               East
    INB              In
    INW              In
    OUTB             Out
    OUTW             Out
    CLOCK            Clockwise
    CCW              Counterclockwise
    COUNTERCLO       Counterclockwise
    COUNTERCLOCK     Counterclockwise
    'DIRECTION 1'    Direction One
    'DIRECTION 2'    Direction Two
    'DIR1'           Direction One
    'DIR2'           Direction Two
    ONE              Direction One
    TWO              Direction Two
    DA               A Loop
    DB               B Loop

Note that specifying "1" or "2" will give South or East, not Direction
One or Direction Two, because Hastus Standard AVL Export numeric
directions are accepted.

Before it looks for an abbreviation, it strips a final "bound", "ward",
or "wise".

=head2 new 

B<< Do not use this method. >>

This method is provided by Moose, and used internally by Actium::Days
to create a new object and insert it into the cache used by instance().
There should never be a reason to create more than one object with the
same arguments.

=cut

my %obj_cache;

method instance ($class: Str $provided_dir) {

    if ( exists $obj_cache{$provided_dir} ) {
        return $obj_cache{$provided_dir};
    }

    my $lookup = uc($provided_dir);

    for ($lookup) {
        s/BOUND\z//;
        s/WARD\z//;
        s/WISE\z//;
    }

    if ( not exists $DIR_OF_ALIAS{$lookup} ) {
        croak "Unknown direction $provided_dir";
    }

    my $dircode = $DIR_OF_ALIAS{$lookup};
    if ( exists $obj_cache{$dircode} ) {
        return $obj_cache{$provided_dir} = $obj_cache{$dircode};
    }

    my $instance = $class->new( _dircode => $dircode );
    $obj_cache{$provided_dir} = $instance;
    $obj_cache{$dircode}      = $instance;
    return $instance;

}

# I don't remember how I used this, but it seems kind of odd to be here.
# I'll have to see where I used it and see if there are better alternatives.

#sub linedir {
#    my $invocant = shift;
#    my $line     = shift;
#
#    my $self;
#
#    if ( Actium::blessed $invocant) {
#        $self = $invocant;
#    }
#    else {
#        # invocant is class
#        my $direction = shift;
#        $self = $invocant->instance($direction);
#    }
#    return "$line." . $self->dircode;
#
#}

=head1 OBJECT METHODS

=head2 dircode

 $obj->dircode

Returns the direction code, as above.

=cut

has 'dircode' => (
    is       => 'ro',
    init_arg => '_dircode',
    isa      => Str->where( sub { exists $DIRDATA{$_} } ),
);

method _data_printer {
    return Actium::blessed($self) . '=' . $self->dircode;
}

=head2 as_bound

Returns one of the following, corresponding to the direction:

   Northbound      Southbound
   Westbound       Eastbound
   Inbound         Outbound 
   Go              Return 
   Clockwise       Counterclockwise
   Direction One   Direction Two
   Going up        Going down
   A Loop          B Loop

=cut

method as_bound {
    return $DIRDATA{ $self->dircode }[BOUND];
}

=head2 as_direction

 $obj->as_direction 

Returns the direction, as above.

=cut

method as_direction {
    return $DIRDATA{ $self->dircode }[DIRECTION];
}

=head2 as_onechar 

Returns a one-character version of the direction.

 Direction           Code         One character
 ---------           ----         -------------
 North               NB           N
 South               SB           S
 West                WB           W
 East                EB           E      
 In                  IN           I
 Out                 OU           O
 Go                  GO           G
 Return              RT           R
 Clockwise           CW           8
 Counterclockwise    CC           9
 Direction One       D1           1
 Direction Two       D2           2
 Up                  UP           U
 Down                DN           D
 A                   A            A
 B                   B            B

=cut

method as_onechar {
    return $DIRDATA{ $self->dircode }[ONE_CHAR];
}

#method _as_sortable {
#    return ( 'A' .. 'Z' )[ $DIRDATA{ $self->dircode }[ORDER] ];
#}

=head2 as_to_text 

Returns a string suitable for prepending to destinations.

 Direction           String
 ---------           ------
 Clockwise           'Clockwise to '
 Counterclockwise    'Counterclockwise to '
 A Loop              'A Loop to '
 B Loop              'B Loop to '
 all others          'To '

Note that in each case there is a final space.

=cut

method as_to_text {
    return $DIRDATA{ $self->dircode }[TO_TEXT] . ' ';
}

=head2 compare

 $dirobj->compare ($dirobj2);

Like the C<cmp> or C<< <=> >> operators in perl, returns either -1, 0,
or 1 depending on whether the first object has an order that is before,
the same, or after this one. See L<instance, above|/#instance> for the
order of the directions.

=cut

method compare ($other, $swap = 0) {
    return 0 if $other == $self;
    my $result = $DIRDATA{ $self->dircode }[ORDER]
      <=> $DIRDATA{ $other->dircode }[ORDER];
    $result = -$result if $swap;
    return $result;
}

=head2 preserve_order

This returns a true value if the order of the directions should always
be preserved when presenting different schedules.

The idea is that for some directions, one should always go first, while
for others, which one goes first is pretty arbitrary, and something
else might be better used instead for deciding in what order to present
the schedule.

Specifically, it is often better to present the schedule with the
earliest time first. So, for example, if the first time on the
southbound schedule is 6:00 a.m., and the first time on the northbound
schedule is 4:00 p.m., it makes sense to present the southbound
schedule first, even though the usual order would be to list first
northbound and then southbound.

On the other hand, for transit lines whose directions are "Go" and
"Return," then it would be odd to list the "Return" schedule first.

At the moment, preserve_order returns false only for northbound,
southbound, eastbound, and westbound, and for others, returns true.
However, this is subject to change.

=cut

method preserve_order {
    return $DIRDATA{ $self->dircode }[PRESERVE_ORDER];
}

Actium::immut;

1;

__END__

=head1 DEPENDENCIES

=over

=item Actium

=item Types::Standard

=back

=head1 BUGS AND LIMITATIONS

Supplying the ->instance() routine with "1" is potentially confusing:
it actually means Hastus Standard AVL direction 1, which is
"southbound," but it might appear more logical that it means "Direction
1."

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * 

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item * 

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

