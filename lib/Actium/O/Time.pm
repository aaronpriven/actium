package Actium::O::Time 0.011;

# object for formatting schedule times and parsing formatted times

use 5.022;
use warnings;    ### DEP ###

use Actium::Moose;
use MooseX::Storage;    ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );

use Actium::Types('TimeNum');
# that definition should be moved inside here when Actium::Time is phased out

const my $NOON_YESTERDAY    => -$MINS_IN_12HRS;
const my $MIDNIGHT          => 0;
const my $NOON              => $MINS_IN_12HRS;
const my $MIDNIGHT_TOMORROW => 2 * $MINS_IN_12HRS;
const my $NOON_TOMORROW     => 3 * $MINS_IN_12HRS;

const my %NAMED_TIMENUMS => (
    NOON_YESTERDAY    => -$MINS_IN_12HRS,
    MIDNIGHT          => 0,
    NOON              => $MINS_IN_12HRS,
    MIDNIGHT_TOMORROW => 2 * $MINS_IN_12HRS,
    NOON_TOMORROW     => 3 * $MINS_IN_12HRS,
);

const my %AMPM_OFFSETS => (
    'a' => 0,
    'p' => $MINS_IN_12HRS,
    'b' => -$MINS_IN_12HRS,
    'x' => 2 * $MINS_IN_12HRS,
);

###########################################
## CONSTRUCTION
###########################################

my %str_cache;
my %num_cache;

my $undef_instance;
# undef can't be a hash key, so can't keep it in the caches.
# Can't create it here because rest of object not defined yet

sub from_num {
    my $class    = shift;
    my @timenums = @_;

    my @objs = (
        map {
            defined $_
              ? $num_cache{$_} //= $class->new( timenum => $_ )
              : $undef_instance
              //= $class->new( timenum => undef )
        } @timenums
    );

    return @objs if wantarray;
    return @timenums > 1 ? \@objs : $objs[0];

}

my $ampm_to_num_cr = sub {

    my $time = shift;
    my $ampm = chop $time;

    my $minutes = substr( $time, -2, 2, $EMPTY_STR );

    # hour is 0 if it reads 12, or otherwise $time
    my $hour = ( $time == 12 ? 0 : $time );

    return ( $minutes + $hour * 60 + $AMPM_OFFSETS{$ampm} );

};

my $t24h_to_num_cr = sub {

    my $time = shift;
    my $minutes = substr( $time, -2, 2, $EMPTY_STR );
    return ( $minutes + $time * 60 );

};

my $str_to_num_cr = sub {

    my $time = shift;
    
    if (exists $NAMED_TIMENUMS{$time} ) {
        return $NAMED_TIMENUMS{$time} ;
    }

    if ( $time !~ /[0-9]/ ) {
        return undef;
    }

    # if there's no numbers, use undef

    my $origtime = $time;

    $time = lc($time);

    $time =~ s/[^0123456789apxb\-']//sg;

    # strip everything except numbers, digits, minus, apostrophe, and apxb

    for ($time) {
        if (   (/^   0?      [1-9] [0-5] [0-9] [apxb] $/sx)
            or (/^   1       [0-2] [0-5] [0-9] [apxb] $/sx) )
        {    # 12 hours
            return $ampm_to_num_cr->($time);
        }
        if (/^ \-?       [0-9]+ [0-5] [0-9] $/sx) {    # 24 hour
            return $t24h_to_num_cr->($time);
        }
        if (   (/^   [01]?  [0-9] \' [0-5] [0-9] $/sx)
            or (/^    2     [0-3] \' [0-5] [0-9] $/sx) )
        {    # before-midnight military
            $time =~ s/\'//g;
            return $t24h_to_num_cr->($time) - ( 2 * $MINS_IN_12HRS );

            # treat as 24 hours, but subtract a day so it refers to yesterday
        }
        croak "Invalid time [$origtime] [$time]";
    }

};

sub from_str {
    my $class    = shift;
    my @timestrs = @_;

    my @objs = map {
        defined $_
          ? $str_cache{$_} //= $class->from_num( $str_to_num_cr->($_) )
          : $undef_instance
          //= $class->new( timenum => undef )
    } @timestrs;

    return @objs if wantarray;
    return @timestrs > 1 ? \@objs : $objs[0];

}

#######################################################
## TIMENUM ATTRIBUTE
#######################################################

has timenum => (
    isa      => TimeNum,
    is       => 'ro',
    required => 1,
);

#######################################################
## FORMATTED TIMES
#######################################################

my $hr12_min_cr = sub {
    my $time    = shift;
    my $minutes = sprintf( '%02d', $time % 60 );
    my $hours   = ( u::floor( $time / 60 ) ) % 12;
    $hours = 12 if $hours == 0;
    return ( $hours, $minutes );
};

for my $attribute (qw/ap apbx t24/) {
    has $attribute => (
        isa      => 'Str',
        is       => 'ro',
        lazy     => 1,
        init_arg => undef,
        builder  => "_build_$attribute",
        traits   => ['DoNotSerialize'],
    );
}

sub _build_ap {
    my $self = shift;
    my $tn   = $self->timenum;
    return $EMPTY unless defined $tn;

    my $marker
      = ( $tn % ( 2 * $MINS_IN_12HRS ) ) < $MINS_IN_12HRS
      ? 'a'
      : 'p';

    my ( $hours, $minutes ) = $hr12_min_cr->($tn);

    return "$hours:${minutes}$marker";
}

sub _build_apbx {

    my $self = shift;
    my $tn   = $self->timenum;
    return $EMPTY unless defined $tn;

    my $marker
      = $tn >= $MIDNIGHT          && $tn < $NOON              ? 'a'
      : $tn >= $NOON              && $tn < $MIDNIGHT_TOMORROW ? 'p'
      : $tn >= $NOON_YESTERDAY    && $tn < $MIDNIGHT          ? 'b'
      : $tn >= $MIDNIGHT_TOMORROW && $tn < $NOON_TOMORROW     ? 'x'
      : $tn == $NOON_TOMORROW                                 ? 'z'
      :   croak "Cannot make a 12 hour timestr from out-of-range number $tn";
      
    my ( $hours, $minutes ) = $hr12_min_cr->($tn);

    return "$hours:${minutes}$marker";

}

sub _build_t24 {
    my $self = shift;
    my $tn   = $self->timenum;
    return $EMPTY unless defined $tn;

    my $minutes = sprintf( '%02d', $tn % 60 );
    my $hours = sprintf( '%02d', ( int( $tn / 60 ) ) % 24 );
    return "$hours:$minutes";
}

# A lot of formatting flexibility from the old Actium::Time was not replicated
# here, because it was never used, and why bother.

u::immut;

1;

__END__

=head1 NAME

Actium::O::Time - Routines to format times in the Actium system

=head1 VERSION

This documentation refers to Actium::O::Time version 0.010

=head1 SYNOPSIS

 use Actium::O::Time;
 my $time = Actium::O::Time->from_str('8:15a');
 my $time2 = Actium::O::Time->from_num(  65 ); # 1:05 am
 my $negtime = Actium::O::Time->from_str("23'59");
 my @moretimes = Actium::O::Time->from_str('12:15p', '2015', '12:01x');
 
 say $time->ap;      # 12:15a
 say $negtime->ap;   # 11:59p
 say $negtime->apbx; # 11:59b
 say $time->t24;     # 00:15
 
=head1 DESCRIPTION

Actium::O::Time contains routines to format times for transit schedules.
It takes times formatted in a number of different ways and converts them
to a number of minutes after midnight (or, if negative, before midnight).

The routines allow times in different formats to be normalized and output
in various other formats, as well as allowing sorting of times numerically.

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These objects
are immutable.

=head1 CLASS METHODS

The object is constructed using C<< Actium::O::Time->from_str >>
or C<< Actium::O::Time->from_num >>

=over

=item B<< Actium::O::Time->from_str( I<string> , I<string>, ...) >>

This constructor accepts times represented as a string.
The string form can be in one of three basic formats:

=over 

=item 1

<hours><minutes><am/pm>

=item 2

<optional negative sign><hours><minutes>

=item 3

<hours><apostrophe><minutes>

=back

Common separators (colons, periods, spaces, commas) as well as a
final "m" are filtered out before determining which format applies.
This makes it easy to submit "8:35 a.m." if you receive times in
that format; it will be converted to '835a' before processing.

All three formats require a leading zero on the minutes, but not
on the hours.

The first format accepts hours from 1 to 12, and minutes from 00 to 59. 

The second format accepts any number of hours from 0 to 35. Minutes 
still must be from 00 to 59.

The third format accepts hours from 12 to 23. It is treated as though
it were the time on the day before midnight, so "23'59" is treated as
meaning, one minute before today's midnight.

For the first format, a final "a" is accepted for a.m. times, and
a final "p" for p.m. times. 

Two other final letters are accepted.

A final "b" is accepted for times before midnight, so '1159b' is 
treated as one minute before midnight.

A final "x" is accepted for times after midnight on the following day, so 
'1201x' is treated as one minute after midnight, tomorrow.

As a special case, if there are no numbers in the string at all, it represents
a null time. This is used for blank columns in schedules.

=item B<< Actium::O::Time->from_num( I<integer>, I<integer>, ... ) >>

This constructor accepts a time number: an integer representing
the number of minutes after midnight (or, if negative, before
midnight). 

The integer must be between -720 and 2159, representing the times between
noon yesterday and 11:59 a.m. tomorrow.

=item B<< Actium::O::Time->new() >>

B<< Do not use this method. >>

This method is used internally by Actium::O::Time to create a new object and
insert it into the caches used by C<from_str> and C<from_num>. 
There should never be a reason
to create more than one object with the same arguments.

=back

=head1 OBJECT METHODS

=over

=item B<timenum()>

Returns the time as a number of minutes since midnight (or, if negative, before
midnight).

=item B<ap()>

Returns the time as a string: hours, a colon, minutes, followed by "a" for a.m.
or "p" for p.m. For example, "2:25a" or "11:30p".

=item B<apbx()>

Returns the time as a string: hours, a colon, minutes, followed by marker. 
Times today are given the marker "a" for a.m. or "p" for p.m. Times tomorrow
are given the marker "x" and times yesterday are given the marker "b".
For example, "11:59b" is yesterday, one minute before midnight and 
"12:01x" is tomorrow, one minute after midnight.

=item B<t24()>

Returns the time as a 24-hour string: hours (padded with a leading zero if
necessary), a colon, and minutes.  The day is not given (so yesterday's and 
tomorrow's times are shown as if they were today's).

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015

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
