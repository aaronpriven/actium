package Actium::Time 0.014;

# object for formatting schedule times and parsing formatted times

use Actium ('class');
use Type::Tiny;
use Types::Standard(qw/Int Str Enum/);
use Types::Common::Numeric (qw/IntRange/);
### Type::Tiny ### DEP ###

const my $MINS_IN_12HRS => ( 12 * 60 );

const my %NAMED => (
    NOON_YESTERDAY    => -$MINS_IN_12HRS,
    MIDNIGHT          => 0,
    NOON              => $MINS_IN_12HRS,
    MIDNIGHT_TOMORROW => 2 * $MINS_IN_12HRS,
    MAX_TIME          => ( 3 * $MINS_IN_12HRS ) - 1,
    NO_VALUE          => -32000,
    f                 => -32001,
    i                 => -32002,
);

###########################################
## CONSTRUCTION
###########################################

my %str_cache;
my %num_cache;

sub from_num {
    my $class    = shift;
    my @timenums = @_;

    my @objs = (
        map {
            defined $_
              ? ( $num_cache{$_} //= $class->new( _timenum => $_ ) )
              : $num_cache{ $NAMED{NO_VALUE} }
              //= $class->new( _timenum => $NAMED{NO_VALUE} )
        } @timenums
    );

    return @objs if wantarray;
    return @timenums > 1 ? \@objs : $objs[0];

}

my $ampm_to_num_cr = sub {

    my $time = shift;
    my $ampm = chop $time;

    my $minutes = substr( $time, -2, 2, $EMPTY );

    # hour is 0 if it reads 12, or otherwise $time
    my $hour = ( $time == 12 ? 0 : $time );

    $minutes += $hour * 60;
    $minutes += (
          $ampm eq 'p' ? $MINS_IN_12HRS
        : $ampm eq 'b' ? -$MINS_IN_12HRS
        : $ampm eq 'x' ? 2 * $MINS_IN_12HRS
        : 0
    );

    return $minutes;

};

my $t24h_to_num_cr = sub {

    my $time    = shift;
    my $minutes = substr( $time, -2, 2, $EMPTY );
    my $sign    = 1;
    if ( $time =~ /^\-/ ) {
        $time =~ s/^\-//;
        $sign = -1;
    }
    return ( $sign * ( $minutes + $time * 60 ) );

};

my $str_to_num_cr = sub {

    my $time = shift;

    if ( exists $NAMED{$time} ) {
        return $NAMED{$time};
    }

    if ( $time !~ /[0-9]/ ) {
        return undef;
    }

    # if there's no numbers, use undef

    my $origtime = $time;

    # ISO TIME FROM XHEA
    if ($time =~ m/
        \A                # beginning of string
        [0-9]+            # year, however many digits
        \-                # hyphen
        (12-31|01-0[12])  # date - captured - Dec 31 or Jan 1 or Jan 2
        T                 # T
        ([0-9]+)          # hours  - captured
        \:                # colon
        ([0-9][0-9])      # minutes - captured
        (?:\:[0-9.]*)?    # seconds
        Z?                # optional Z for Zulu time
        \z                # end of string
        /x
      )
    {

        my $isodate = $1;
        my $isotime = $2 . $3;
        my $time    = $t24h_to_num_cr->($isotime);

        if ( $isodate eq '12-31' ) {
            $time -= ( 2 * $MINS_IN_12HRS );
        }
        elsif ( $isodate eq '01-02' ) {
            $time += ( 2 * $MINS_IN_12HRS );
        }
        return $time;

    }

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
        croak "Invalid time string [orig: $origtime] [result: $time]";
    }

};

sub from_str {
    my $class    = shift;
    my @timestrs = @_;

    my @objs = map {
        defined $_
          ? $str_cache{$_} //= $class->from_num( $str_to_num_cr->($_) )
          : $num_cache{ $NAMED{NO_VALUE} }
          //= $class->new( _timenum => $NAMED{NO_VALUE} )
    } @timestrs;

    return @objs if wantarray;
    return @timestrs > 1 ? \@objs : $objs[0];

}

method from_excel ($class: @cells) {

    my @objs;

    foreach my $cell (@cells) {

        if ( not defined $cell ) {
            push @objs, $class->from_num( $NAMED{NO_VALUE} );
            next;
        }
        my $formatted   = $cell->value;
        my $unformatted = $cell->unformatted;

        # if it looks like an Excel time fraction,
        if (    Actium::looks_like_number($unformatted)
            and $formatted =~ /:/
            and -0.5 <= $unformatted
            and $unformatted < 1.5 )
        {

            if ( $unformatted < 0 ) {
                $unformatted += 0.5;
            }
            elsif ( 1 < $unformatted ) {
                $unformatted -= 1;
            }

            require POSIX;

            my $timenum = POSIX::round( $unformatted * 2 * $MINS_IN_12HRS );
            push @objs, $class->from_num($timenum);

        }
        else {
            push @objs, $class->from_str($formatted);
        }
    }

    return @objs if wantarray;
    return @objs > 1 ? \@objs : $objs[0];

}

#######################################################
## TIMENUM ATTRIBUTE
#######################################################

has _timenum => (
    isa => ( Enum [ values %NAMED ] )
      | ( IntRange [ $NAMED{NOON_YESTERDAY}, $NAMED{MAX_TIME} ] ),
    is => 'ro',
    #    init_arg => '_timenum',
    required => 1,
);

method timenum {
    my $timenum = $self->_timenum;
    return undef if $timenum < $NAMED{NOON_YESTERDAY};
    return $timenum;
}

#######################################################
## BUNDLE
#######################################################

method bundle {
    return $self->_timenum;
}

method unbundle ($class: Int $bundle) {
    return $class->from_num($bundle);
}

#######################################################
## BOOLEAN METHODS
#######################################################

method is_in_range (Int $integer) {
    return ( $NAMED{NOON_YESTERDAY} <= $integer )
      && ( $integer <= $NAMED{MAX_TIME} );
}

method is_flex {
    return $self->_timenum == $NAMED{f};
}

method is_awaiting_interpolation {
    return $self->_timenum == $NAMED{i};
}

method does_stop {
    return $self->_timenum != $NAMED{NO_VALUE};
}

method no_stop {
    return $self->_timenum == $NAMED{NO_VALUE};
}

method has_time {
    return ( $self->is_in_range( $self->_timenum ) );
}

#######################################################
## FORMATTED TIMES
#######################################################

# KINDS OF TIMES
# 12ap - hours, 1-12 , a/p
# 12apbx - hours, 1-12 , a/p/b/x
# 12apnm - hours, 1-12 , a/p/n/m
# 24 - hours, 0-23
# 24+ - hours, 12-23 for negative, 0-36 for positive
# 24- (not implemented) hours, -12 to 36 (negative minutes)

const my @VALID_FORMATS => qw/12ap 12apbx 12apnm 24 24+/;

has _formatted_cache_r => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        _fcache_exists => 'exists',
        _fcache_set    => 'set',
        _fcache        => 'get'
    },
);

method formatted ( 
    :$separator = ':' , 
    :$negative_separator = q['] ,
    :$format = '24', 
) {

    croak "Invalid format $format in " . __PACKAGE__ . '->formatted'
      unless Actium::any { $_ eq $format } @VALID_FORMATS;

    my $cachekey;
    if ( $format eq '24+' ) {
        $cachekey = join( "\0", $format, $separator, $negative_separator );
    }
    else {
        $cachekey = join( "\0", $format, $separator );
    }
    return $self->_fcache($cachekey) if $self->_fcache_exists($cachekey);

    my $timenum = $self->_timenum;
    return $EMPTY if $timenum == $NAMED{NO_VALUE};
    return $self->_fcache_set( $cachekey => $timenum )
      if $timenum == $NAMED{f}
      or $timenum == $NAMED{i};

    ## 24 hour formats

    if ( $format eq '24' ) {
        $timenum += ( $MINS_IN_12HRS * 2 ) if $timenum < 0;
        my $minutes = sprintf( '%02d', $timenum % 60 );
        my $hours   = sprintf( '%02d', ( int( $timenum / 60 ) ) % 24 );
        return $self->_fcache_set(
            $cachekey => join( $EMPTY, $hours, $separator, $minutes ) );
    }
    elsif ( $format eq '24+' ) {
        if ( $timenum < 0 ) {
            $separator = $negative_separator;
            $timenum += ( $MINS_IN_12HRS * 2 );
        }
        my $minutes = sprintf( '%02d', $timenum % 60 );
        my $hours   = sprintf( '%02d', ( int( $timenum / 60 ) ) );
        return $self->_fcache_set(
            $cachekey => join( $EMPTY, $hours, $separator, $minutes ) );
    }

    # 12 hour formats

    my $minutes = sprintf( '%02d', $timenum % 60 );
    my $hours   = ( Actium::floor( $timenum / 60 ) ) % 12;
    $hours = 12 if $hours == 0;

    if ( $format eq '12apmn' ) {

        return "12:00m"
          if ( $timenum == $NAMED{MIDNIGHT}
            or $timenum == $NAMED{MIDNIGHT_TOMORROW} );
        return "12:00n"
          if ( $timenum == $NAMED{NOON} or $timenum == $NAMED{NOON_YESTERDAY} );

        $format = '12ap';
    }

    my $marker;
    if ( $format eq '12ap' ) {
        $marker
          = ( $timenum % ( 2 * $MINS_IN_12HRS ) ) < $MINS_IN_12HRS
          ? 'a'
          : 'p';
    }
    else {    # 12apbx
   #<<<
 $marker
   = $timenum >= $NAMED{MIDNIGHT} && $timenum < $NAMED{NOON} ? 'a'
   : $timenum >= $NAMED{NOON} && $timenum < $NAMED{MIDNIGHT_TOMORROW} ? 'p'
   : $timenum >= $NAMED{NOON_YESTERDAY} && $timenum < $NAMED{MIDNIGHT} ? 'b'
   : $timenum >= $NAMED{MIDNIGHT_TOMORROW} && $timenum <= $NAMED{MAX_TIME} ? 'x'
   : croak "Cannot make a 12 hour timestr from out-of-range number $timenum";
  #>>>
    }
    return $self->_fcache_set(
        $cachekey => join( $EMPTY, $hours, $separator, $minutes, $marker ) );

}

has [qw/ap ap_noseparator apbx apbx_noseparator t24/] => (
    isa      => 'Str',
    is       => 'ro',
    lazy     => 1,
    builder  => 1,
    init_arg => undef,
);

method _build_ap {
    return $self->formatted( format => '12ap' );
}

method _build_t24 {
    return $self->formatted( format => '24' );
}

method _build_apbx {
    return $self->formatted( format => '12apbx' );
}

method _build_ap_noseparator {
    return $self->formatted( format => '12ap', separator => $EMPTY );
}

method _build_apbx_noseparator {
    return $self->formatted( format => '12apbx', separator => $EMPTY );
}

#######################################
### OTHER CLASS METHODS

sub timesort {
    my $class = shift;
    my @objs  = @_;

    my @tosort;

    for my $obj (@objs) {
        my $timenum = $obj->timenum;
        $timenum = $NAMED{NOON_YESTERDAY}
          if not defined $timenum
          or $timenum eq 'f'
          or $timenum eq 'i';
        push @tosort, [ $obj, $timenum ];
    }

    # Schwartzian transform
    return map { $_->[0] }
      sort { $a->[1] <=> $b->[1] } @tosort;

}

Actium::immut;

1;

__END__

=head1 NAME

Actium::Time - Routines to format times in the Actium system

=head1 VERSION

This documentation refers to Actium::Time version 0.015

=head1 SYNOPSIS

 use Actium::Time;
 my $time = Actium::Time->from_str('8:15a');
 my $time2 = Actium::Time->from_num(  65 ); # 1:05 am
 my $negtime = Actium::Time->from_str("23'59");
 my @moretimes = Actium::Time->from_str('12:15p', '2015', '12:01x');
 
 say $time->ap;      # 12:15a
 say $time->formatted(format => '24', separator => '.'); # 0.15
 say $negtime->ap;   # 11:59p
 say $negtime->apbx; # 11:59b

=head1 DESCRIPTION

Actium::Time is an class designed to format times for transit
schedules. It takes times formatted in a number of different ways and
converts them to a number of minutes after midnight (or, if negative,
before midnight). Times are only treated as whole minutes, so seconds
are not used.

Most transit operators that run service after midnight treat those
trips as a later part of the service day: so a trip that begins at
1:00 a.m. on Sunday  is scheduled as though it were at 25 o'clock
on Saturday. This class allows a 48-hour stretch of times, from
noon on the day before the service day through 11:59 on the day
after the service day (so for a Saturday day of service, from 12:00
p.m. Friday through 11:59 a.m. Sunday).

The object allows times in different formats to be normalized and
output in various other formats, as well as allowing sorting of times
numerically.

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These
objects are immutable.

There are three special time values.  

=over

=item * -32000

This signifies a blank time on a schedule -- the vehicle does not stop.

=item * -32001

This signifies that this is a stop for flexible service,
but that there is no specific time when the bus will arrive at this stop.

=item * -32002

This indicates that this time will eventually be interpolated from nearby
times, but this interpolation has not yet been performed.  

=back

=head1 CLASS METHODS

The object is constructed using C<< Actium::Time->from_str >> , C<<
Actium::Time->from_num >>, or  C<< Actium::Time->from_excel >>.

=head2 from_str

 Actium::Time->from_str( I<string> , I<string>, ...) 

This constructor accepts times represented as a string, usually a
formatted time such as "11:59a" or "13'25", and returns an object for
each time that is passed.

There are a limited number of special cases where names may be for
times instead of a format string. The valid named times are:

=over

=item    NOON_YESTERDAY

=item    MIDNIGHT

=item    NOON

=item    MIDNIGHT_TOMORROW 

=item    MAX_TIME

=item    f

=item    i

=item    NO_VALUE

=back 

The 'f' value is stored as the value representing flexible service, and the 'i'
value is stored as the value representing future interpolation. 

MAX_TIME is equivalent to 11:59x, or 11:59 a.m. on the following day.

The C<from_str> method also accepts the undefined value.  Other than "f" and
"i", a string without any numbers in it is treated as the undefined value.
(This includes the empty string.) This is treated the same as NO_VALUE.

Otherwise, the string format can be one of these:

=over 

=item 1

<hours><minutes><am/pm>

=item 2

<optional negative sign><hours><minutes>

=item 3

<hours><apostrophe><minutes>

=item 4

A date and time specification similar to ISO 8601 date-time format.
The date must be specified first, in yyyy-mm-dd format, followed by
the letter T, and then hours, minutes, and seconds in hh:mm::ss format.
A letter Z signifying the time zone is optional at the end of the string.

Hours and minutes are accepted as one would expect. Seconds are ignored.

The year is also ignored. The only recognized dates are December 31,
January 1, and January 2. With a date of December 31, 24 hours are
subtracted from the hours given. With a date of January 2, 24 hours are
added to the hours given.

=back

For the first three formats,  most characters, including common
separators (colons, periods, spaces, commas)  and the  final "m" are
filtered out before determining which format applies. This makes it easy
to submit "8:35 a.m." if you receive times in that format; it will be
converted to '835a' before processing.

These three formats require a leading zero on the minutes, but not on the
hours.

The first format accepts hours from 1 to 12, and minutes from 00 to 59.

The second format accepts any number of hours from -11 to 35. Minutes 
still must be from 00 to 59. If a negative sign is given, these are
treated  as times before midnight, so -0:01 is the same as "11:59b" 
(i.e., 11:59 yesterday).

The third format accepts hours from 12 to 23. It is treated as though
it were the time on the day before midnight, so "23'59" is treated as
meaning, one minute before today's midnight.

For the first format, a final "a" is accepted for a.m. times, and a
final "p" for p.m. times.

Two other final letters are accepted.

A final "b" is accepted for times before midnight, so '1159b' is 
treated as one minute before midnight.

A final "x" is accepted for times after midnight on the following day,
so '1201x' is treated as one minute after midnight, tomorrow.

=head2 from_num

 Actium::Time->from_num( I<integer>, I<integer>, ... ) 

This constructor accepts a time number: an integer representing the
number of minutes after midnight (or, if negative, before midnight). It
returns one object for each number that is passed.

The integer must be between -720 and 2159, representing the times
between noon yesterday and one minute before noon tomorrow.

It also accepts the three special values listed above as for flexible service,
a future interpolated time, and no value.

=head2 from_excel

 Actium::Time->from_excel( I<cell>, I<cell>, ... ) 

This constructor accepts cells from Excel, specifically those returned
from the get_cell routine in either Spreadsheet::ParseExcel or
Spreadsheet::ParseXLSX. (The object passed in must support the methods 
C<value> and C<unformatted>.)  It can accept a formatted Excel time 
(which it converts to a time number and sends to C<from_num>) or a
string (which it sends to C<from_str>). It returns one object for each
cell passed to it.

=head2 is_in_range

 Actium::Time->is_in_range($integer)

Returns true if the supplied integer is in the valid range for timenum integers
(between noon on the previous day and 11:59 p.m. on the following day).

=head2 new

B<< Do not use this method. >>

This method is used internally by Actium::Time to create a new
object and insert it into the caches used by C<from_str>, C<from_excel>, and
C<from_num>.  There should never be a reason to create more than one
object with the same arguments.

=head2 unbundle

This method takes the string generated by C<bundle> and returns an appropriate
instance of Actium::Time. 

=head2 timesort

 Actium::Time::->timesort(I<obj>, I<obj>, ... )

This class method takes a series of Actium::Time objects and sorts
them (numerically according to their time number value), returning the 
sorted list of objects.

=head1 OBJECT METHODS

=head2 timenum

Returns the time as a number of minutes since midnight (or, if
negative, before midnight), or an undefined value if it is not a time. 
(This may be changed in the future to return the special values given above.)

=head2 bundle

Returns a string that, when sent to C<unbundle>, will recreate the object.

=head2 is_flex

Returns true if the time represents a flexible stop, false otherwise.

=head2 is_awaiting_interpolation

Returns true if the time represents a time that must be interpolated, false otherwise.

=head2 does_stop

Returns true if the time represents a stop that will be made (i.e., the timenum
value anything other than the NO_VALUE value), false otherwise.

=head2 no_stop

The opposite of C<does_stop>. Returns true if the time represents a stop that
will not be made (i.e., the timenum value is the NO_VALUE value), false
otherwise.

=head2 has_time

Returns true if the time represents an actual time rather than one of the
special values for flexible service, future interpolation, or no value.

=head2 ap and ap_noseparator

The C<ap> method returns the time as a string: hours, a colon, minutes,
followed by "a" for a.m. or "p" for p.m. For example, "2:25a" or
"11:30p".  The C<ap_noseparator> method also returns this value, only
without the colon: "225a" or "1130p".

The special values 'f' and 'i' will be returned as such. An undefined
time will be returned as the empty string.

These values are cached so will only be generated once for each time.

=head2 apbx and apbx_noseparator

The C<apbx> method returns the time as a string: hours, a colon,
minutes, followed by a marker.  Times today are given the marker
"a" for a.m. or "p" for p.m.  Times tomorrow are given the marker
"x" and times yesterday are given the marker "b". For example,
"11:59b" is yesterday, one minute before midnight and  "12:01x" is
tomorrow, one minute after midnight.

The C<apbx_noseparator> method is similar, but does not include the colon.

The special values 'f' and 'i' will be returned as such. An undefined
time will be returned as the empty string.

These values are cached so will only be generated once for each time.

=head2 formatted

C<< formatted (format => I<format>, separator => I<str> , negative_separator => I<str> >>

This method provides the time in one of several formats. In each case,
the separator given is used to separate the hours and minutes (except
for the format "24+"; see below). The default separator is the colon (":").

The formats are as follows:
qw/12ap 12apbx 12apnm 24 24+/;

=over

=item 12ap

This returns the 12-hour time: hours from 1 to 12, minutes from 0 to 60, 
with the marker "a" for a.m. times and "p" for p.m. times. No distinction is
made between times on the current day, on the previous day, or on the following day.

=item 12apmn

This is like 12ap, except that midnight (on any day) is returned as 12:00m and
noon (on any day) is returned as 12:00n.

=item 12apbx

This returns the 12-hour time: hours from 1 to 12, and minutes from 0 to 60.
Times on the current day are marked "a" for a.m. or "p" for p.m.  The previous
day's p.m. times are given the marker "b", and the following day's a.m. times
are given the marker "x".  

=item 24

This returns the 24-hour time: hours from 0 to 23, minutes from 0 to 60.
No distinction is made between times on the current day, on the previous
day, or on the following day.

=item 24+

This returns the 24-hour time: hours from 0 to 36, minutes are from 0 to 60.
Hours above 23 indicate times on the following day. 

The separator serves to indicate times on the previous day. Times on the
previous day use the negative separator provided, rather than the regular
separator. (This is the only format that uses the negative separator.) 
The default negative separator is a single quote (').

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009-2018

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
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.
