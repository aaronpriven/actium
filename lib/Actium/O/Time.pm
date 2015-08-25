package Actium::O::Time 0.010;

# object for formatting schedule times and parsing formatted times

use 5.022;
use warnings;                     ### DEP ###

use Actium::Moose;
use MooseX::Storage;              ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );
with 'MooseX::Role::Flyweight';

use Actium::Types('TimeNum');

const my $MINS_IN_12HRS => ( 12 * 60 );

const my $NOON_YESTERDAY    => -$MINS_IN_12HRS;
const my $MIDNIGHT          => 0;
const my $NOON              => $MINS_IN_12HRS;
const my $MIDNIGHT_TOMORROW => 2 * $MINS_IN_12HRS;
const my $NOON_TOMORROW     => 3 * $MINS_IN_12HRS;

const my %AMPM_OFFSETS => (
    'a' => 0,
    'p' => $MINS_IN_12HRS,
    'b' => -$MINS_IN_12HRS,
    'x' => 2 * $MINS_IN_12HRS,
);

###########################################
## CONSTRUCTION
###########################################

sub instances {
    my $class = shift;
    return map { $class->instance($_) } @_;
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

my $timestr_to_timenum = sub {

    my $time = shift;
    state %cache;
    return $cache{$time} if exists $cache{$time};

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
            return $cache{$time} = $ampm_to_num_cr->($time);
        }
        if (/^ \-?       [0-9]+ [0-5] [0-9] $/sx) {    # 24 hour
            return $cache{$time} = $t24h_to_num_cr->($time);
        }
        if (   (/^   [01]?  [0-9] \' [0-5] [0-9] $/sx)
            or (/^    2     [0-3] \' [0-5] [0-9] $/sx) )
        {    # before-midnight military
            $time =~ s/\'//g;
            return $cache{$time}
              = ( $t24h_to_num_cr->($time) - ( 2 * $MINS_IN_12HRS ) )

              # treat as 24 hours, but subtract a day so it refers to yesterday
        }
        croak "Invalid time [$origtime] [$time]";
    } ## tidy end: for ($time)

};

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;
    my %params;

    if ( @_ == 1 ) {
        if ( u::reftype( $_[0] ) eq 'HASH' ) {
            %params = %{ $_[0] };
        }
        else {
            %params = ( time => $_[0] );
        }
    }
    else {
        %params = @_;
    }
    # doing it that way instead of using 'u::positional' means we can specify
    # named arguments with either a hash or a hashref.
    # u::positional requires a hashref because it may have optional positional
    # arguments.

    if ( $params{timenum} and $params{'time'} ) {
        croak q{Can't specify both a time and a timenum to } . __PACKAGE__;
    }

    if ( $params{'time'} ) {
        $params{timenum} = $timestr_to_timenum->($_);
        delete $params{'time'};
    }

    return $class->$orig( \%params );

};

#######################################################
## TIMENUM ATTRIBUTE
#######################################################

has timenum => {
    isa      => TimeNum,
    is       => 'ro',
    required => 1,
};

#######################################################
## FORMATTED TIMES
#######################################################

my $hr12_min_cr = sub {
    my $time    = shift;
    my $minutes = $time % 60;
    my $hours   = ( int( $time / 60 ) ) % 12;
    return ( $hours, $minutes );
};

for my $attribute (qw/ap apbx t24/) {
    has $attribute => {
        isa     => 'Str',
        is      => 'ro',
        lazy    => 1,
        builder => "_build_$attribute",
        traits  => ['DoNotSerialize'],
    };
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
      :   croak "Cannot make a 12 hour timestr from out-of-range number $tn";

    my ( $hours, $minutes ) = $hr12_min_cr->($tn);

}

sub _build_t24 {
    my $self = shift;
    my $tn   = $self->timenum;
    return $EMPTY unless defined $tn;

    my $minutes = $tn % 60;
    my $hours = sprintf( '%2d', ( int( $tn / 60 ) ) % 24 );
    return "$hours:$minutes";
}

# A lot of formatting flexibility from the old Actium::Time was not replicated
# here, because it was never used, and why bother.

1;

__END__

=head1 NAME

Actium::O::Time - Routines to format times in the Actium system

=head1 VERSION

This documentation refers to Actium::O::Time version 0.010

=head1 SYNOPSIS

 use Actium::O::Time;
 my $time = Actium::O::Time->instance('8:15a');
 my $time2 = Actium::O::Time->instance( {timenum => 65 } ); # 1:05 am
 my $negtime = Actium::O::Time->instance("23'59");
 my @moretimes = Actium::O::Time->instances('12:15p', '2015', '12:01x');
 
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

=over

=item B<< Actium::O::Time->instance( I<time> ) >>

=item B<< Actium::O::Time->instance( { time => I<time> }) >>

=item B<< Actium::O::Time->instance( { timenum => I<timenum> }) >>

The object is constructed using "Actium::O::Time->instance".  

The constructor accepts a time string, either as the only positional
argument or as the "time" named argument.  Or, it accepts, in the
"timenum" named argument, a time number: an integer representing
the number of minutes after midnight (or, if negative, before
midnight). It can accept only one or the other, not both.

The times must be between -720 and 2159, representing the times between
noon yesterday and 11:59 a.m. tomorrow.

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
a final "p" for p.m. times. Two other final letters are accepted.
A final "b" is accepted for times before midnight, so '1159b' is 
treated as one minute before midnight.

A final "x" is accepted for times after midnight on the following day, so 
'1201x' is treated as one minute after midnight, tomorrow.

As a special case, if there are no numbers in the string at all, it represents
a null time. This is used for blank columns in schedules.

=item B<< Actium::O::Time->instances(I<time>, I<time>, ...) >>

This class method accepts a list of time strings and returns all the objects
represented by them.

=item B<< Actium::O::Time->new() >>

B<< Do not use this method. >>

This method is used internally by Actium::O::Time to create a new object and
insert it into the cache used by instance(). There should never be a reason
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
necessary), a colon, and minutes.  The day is not given (so yesterday's times
are shown as if they were today's).

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
