# Actium/Time.pm
# Routines for formatting times and parsing formatted times

# legacy status 3

use warnings;
use strict;

package Actium::Time 0.010;

use 5.010;

use Carp;
use Actium::Constants;
use Params::Validate qw(:all);
use Const::Fast;
use Scalar::Util (qw<reftype looks_like_number>);
use Memoize;

use List::MoreUtils (qw<firstidx>);

## no critic (ProhibitMagicNumbers)

const my $MINS_IN_12HRS => ( 12 * 60 );

const my %AMPM_OFFSETS => (
    'a' => 0,
    'p' => $MINS_IN_12HRS,
    'b' => -$MINS_IN_12HRS,
    'x' => 2 * $MINS_IN_12HRS,
);

use Sub::Exporter -setup => { exports => [qw(timenum timestr timestr_sub)] };

###########################################
## TIMENUM
###########################################

sub timenum {
    if (wantarray) {
        return map { _single_timenum($_) } @_;
    }
    else {
        return _single_timenum( $_[0] );
    }
}

# maybe it should return \@timenums in scalar context
# if it was passed more than one?

#memoize('_single_timenum');

sub _single_timenum {

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

    # strip everything except numbers, digits, apostrophe, and apxb

    for ($time) {
        if (
                 (/^   0?      [1-9] [0-5] [0-9] [apxb] $/sx)
              or (/^   1       [0-2] [0-5] [0-9] [apxb] $/sx)
          )
        {    # 12 hours
            return $cache{$time} = _ampm_to_num($time);
        }
        if (/^ \-?       [0-9]+ [0-5] [0-9] $/sx) {    # 24 hour
            return $cache{$time} = _24h_to_num($time);
        }
        if (
                 (/^   [01]?  [0-9] \' [0-5] [0-9] $/sx)
              or (/^    2     [0-3] \' [0-5] [0-9] $/sx)
          )
        {    # before-midnight military
            $time =~ s/\'//g;
            return $cache{$time} = ( _24h_to_num($time) - ( 2 * $MINS_IN_12HRS ) )

              # treat as 24 hours, but subtract a day so it refers to yesterday
        }
        croak "Invalid time [$origtime] [$time]" ;
    };

    return;    # this will never be executed because of the default croak

}    ## <perltidy> end sub _single_timenum

sub _ampm_to_num {

    my $time = shift;
    my $ampm = chop $time;

    my $minutes = substr( $time, -2, 2, $EMPTY_STR );

    # hour is 0 if it reads 12, or otherwise $time
    my $hour = ( $time == 12 ? 0 : $time );

    return ( $minutes + $hour * 60 + $AMPM_OFFSETS{$ampm} );

}

sub _24h_to_num {

    my $time = shift;
    my $minutes = substr( $time, -2, 2, $EMPTY_STR );
    return ( $minutes + $time * 60 );

}

#######################################################
## TIMESTR & TIMESTR-SUB
#######################################################

my %timestr_validation_spec = (
    HOURS => { type => SCALAR, regex => qr/^(?:12|24)$/sx, 'default' => '12' },
    XB    => {
        type    => BOOLEAN,
        default => 0,
        callback =>
          { 'Cannot specify XB for 24 hour string' => \&_validate_xb_24hr }
    },
    SEPARATOR   => { type => SCALAR,  default => q{:} },
    LEADINGZERO => { type => BOOLEAN, default => 0 },
    APMARKERS   => {
        type     => ARRAYREF,
        default  => [qw/a p x b/],
        callback => {
            'Improper number of AM/PM markers' => \&_validate_marker_num,
            'Cannot specify AM/PM markers for 24 hour string' =>
              \&_validate_marker_24hr,
        }
      }

);

sub timestr_sub {

    my %params = validate( @_, \%timestr_validation_spec );

    if ( $params{HOURS} eq '24' ) {
        my ($template)
          = _make_template_24( $params{LEADINGZERO}, $params{SEPARATOR} );
        return sub { _timestr24( $template, @_ ) };
    }

    my $template
      = _make_template_12( $params{LEADINGZERO}, $params{SEPARATOR} );

    my $xb      = $params{XB};
    my @markers = @{ $params{APMARKERS} };

    if ( not $params{XB} ) {
        @markers = ( $markers[0], $markers[1], $markers[0], $markers[1] );

        # set the xb entries to be the same as the ap entries
    }

    return sub { _timestr12( $template, @markers, @_ ) };

}    ## <perltidy> end sub timestr_sub

#memoize('_make_template_12');

sub _make_template_12 {
    my $template = _make_template_24(@_);
    return $template . '%s';
}

#memoize('_make_template_24');

sub _make_template_24 {
    my ( $leadingzero, $separator ) = @_;
    my $hours = $leadingzero ? '%2d' : '%d';
    my $minutes = ( $separator // $EMPTY_STR ) . '%02d';
    return ( $hours . $minutes );
}

sub _timestr12 {
    my $template = shift;
    my @markers  = splice( @_, 0, 4 );
    my @timestrs = map { _single_timestr12( $template, @markers, $_ ) } @_;
    return wantarray ? @timestrs : join( "\t", @timestrs );
}

sub _timestr24 {
    my ( $template, @times ) = @_;
    my @timestrs = map { _single_timestr24( $template, $_ ) } @times;
    return wantarray ? @timestrs : join( "\t", @timestrs );
}

#memoize('_single_timestr12');

# TODO - Both _single_timestr12 and _single_timestr24
# appear broken for negative times.
# I think it needs a complete rewrite for that.
# &hours_minutes is wrong because the int doesn't do
# what I thought it did.

sub _single_timestr12 {

    my $template = shift;
    my $time     = pop;
    my @markers  = @_;

    return $EMPTY_STR unless defined($time);

    croak "Cannot make a timestr from non-number $time"
      unless looks_like_number($time);

    croak "Cannot make a 12 hour timestr from out-of-range number $time"
      unless ( $time >= ( -$MINS_IN_12HRS )
        and $time < ( 3 * $MINS_IN_12HRS ) );

    my $negative = 0;

    if ( $time < 0 ) {
        $time += 2 * $MINS_IN_12HRS;
        $negative = 1;
    }

    my ( $hours, $minutes ) = _hoursminutes($time);

    my $ampm;

    if ($negative) {
        $ampm = $markers[3];    # b
    }
    else {
        $ampm = int( $time / $MINS_IN_12HRS );    # 0, 1, or 2
        $ampm = $markers[$ampm];
    }

    $hours = $hours % 12;

    if ( $hours == 0 ) {
        $hours = 12;
    }

    return sprintf( $template, $hours, $minutes, $ampm );

}

#memoize('_single_timestr24');

sub _single_timestr24 {
    my ( $template, $time ) = @_;

    return $EMPTY_STR unless defined($time);

    croak "Cannot make a timestr from non-number $time"
      unless looks_like_number($time);

    my $negative = 0;

    if ( $time < 0 ) {
        $time     = abs($time);
        $template = "-$template";
    }

    my ( $hours, $minutes ) = _hoursminutes($time);

    return sprintf( $template, $hours, $minutes );

} ## #tidy# end sub _single_timestr24

sub _hoursminutes {
    my $time    = shift;
    my $minutes = $time % 60;
    my $hours   = int( $time / 60 );
    return ( $hours, $minutes );
}

sub timestr {

    # REGULARIZE TIME

    for ( ref( $_[0] ) ) {    # The first parameter

        if ($_ eq 'ARRAY') {
            unshift @_, 'TIME';

     # when the first parameter is an arrayref, take it to be an array of times,
     # and put TIME in front of it so Params::Validate will see it as a name
     next;
        }

        if ( $_ ne 'HASH' ) {

            # so first parameter is (presumably) a scalar

            if ( looks_like_timenum( $_[0] ) ) {

                # if it is potentially a timenum,

                my $first_nontimenum = firstidx {
                    our $_;
                    not( looks_like_number($_) ) and defined($_);
                }
                @_;

                $first_nontimenum = scalar(@_) if $first_nontimenum == -1;

                my @times = splice( @_, 0, $first_nontimenum );

                # stick everything that looks like a number in @times,

                unshift @_, 'TIME', \@times;

                # and put that at the front with TIME,
                # so Params::Validate will see it

            }    ## <perltidy> end if ( looks_like_timenum...)

            # otherwise, if it doesn't look like it might be a timenum,
            # assume the TIME entry is somewhere later in the list, and
            # hope Params::Validate can deal with it

        next;
        }    ## <perltidy> end when ( $_ ne 'HASH' )

    }    ## <perltidy> end given

    my %params = validate(
        @_,
        {   %timestr_validation_spec,
            TIME => {
                type     => ( SCALAR | UNDEF | ARRAYREF ),
                callback => { 'Time out of range' => \&_validate_time }
            }
        }
    );    # validate parameters

    my @times;
    if ( ref( $params{TIME} ) eq 'ARRAY' ) {
        @times = @{ $params{TIME} };
    }
    else {
        @times = $params{TIME};
    }
    delete $params{TIME};

    # put times into @times

    return timestr_sub(%params)->(@times);

}    ## <perltidy> end sub timestr

sub looks_like_timenum {
    my $value = shift;
    return ( not( defined($value) ) or looks_like_number($value) );
}

sub _validate_marker_num {

    my @markers      = @{ +shift };
    my %params       = %{ +shift };
    my $xb           = $params{XB};
    my $marker_elems = scalar(@_);

    if ( !$xb ) {    # If we're not using $xb, then 2 is a permissible number
        return 0 if $marker_elems == 2;
    }

    # Check the number of markers. If we're using xb, then only 4 is ok.
    # Otherwise, either 2 or 4 is ok.
    # This way you can have a @markers = qw/am pm xm bm/ and not worry
    # that some aren't being used.

    return 1 if $marker_elems != 4;

    return 0;

}    ## <perltidy> end sub _validate_marker_num

sub _validate_marker_24hr {
    my @markers = @{ +shift };
    my %params  = %{ +shift };
    return 1 if $params{HOURS} eq '24';
    return 0;
}

sub _validate_xb_24hr {
    my $xb     = shift;
    my %params = %{ +shift };
    return 1 if $params{HOURS} eq '24';
    return 0;
}

1;

__END__

=head1 NAME

Actium::Time - Routines to format times in the Actium system

=head1 VERSION

This documentation refers to Actium::Time version 0.001

=head1 SYNOPSIS

 use Actium::Time qw(timenum timestr timestr_sub);
 @times = '1:15a' , '0545p' , '13.15';
 @timenums = timenum(@times);
 # @timenums = 75, 1065, 795
 @timenums = sort { $a <=> $b} @timenums; # 75, 795, 1065
 
 @timestrs = timestr($_);
 # @timestrs = '1:15a' , '1:15p' , '5:45p';

 $timesub = timestr_sub {HOURS => 24, LEADINGZERO => 1 , SEPARATOR => '.' };
 $timestr = $timesub->(75); # '01.15'
  
=head1 DESCRIPTION

Actium::Time contains routines to format times for transit schedules.
It takes times formatted in a number of different ways and converts them
to a number of minutes after midnight (or, if negative, before midnight).

The routines allow times in different formats to be normalized and output
in various other formats, as well as allowing sorting of times numerically.

=head1 SUBROUTINES

=over

=item B<timenum(@times)>

B<timenum()> accepts one or more times in string form and returns
the number of minutes after midnight that the time represents.

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
final "m" are filtered out before determining which format applies. This makes
it easy to submit "8:35 a.m." if you receive times in that format; it will
be converted to '835a' before processing.

All three formats require a leading zero on the minutes, but not on the hours.

The first format accepts hours from 1 to 12, and minutes from 00 to 59. 

The second format accepts any number of hours. Minutes still must be from 
00 to 59.

The third format accepts hours from 0 to 23. It is treated as though it were 
the time on the day before midnight, so "23'59" is returned as -1 (meaning, one minute before midnight).

For the first format, a final "a" is accepted for a.m. times, and a final "p" 
for p.m. times. Two other final letters are accepted. A final "b" is accepted
for times before midnight, so timenum('1159b') is equal to -1 (again, one minute
before midnight).  

A final "x" is accepted for times after midnight on the following day, so 
timenum('1201x') is equal to 1441 (meaning, 1441 minutes after midnight).

As a special case, if there are no numbers in the string at all, it returns 
undef. This is used for blank columns in schedules.

If called in scalar context, returns only the first value.

=item B<timestr(I<TIMES> , I<NAMED PARAMETERS>)>

B<timestr()> takes one or more time numbers (the number of minutes after midnight) 
and returns a formatted string separating hours and minutes, with an optional
a.m./p.m. marker at the end.

If it receives an undefined value instead of a time number, it returns the empty string.

This routine can be called in a multiplicity of ways. I<TIMES> can be specified either
as a flat list of time numbers (meaning, numbers and/or undefined values), or as a 
(single) reference to a flat list of time numbers.  

(Alternatively, times can be specified as the named argument TIME.)

I<NAMED PARAMETERS> can be specified either as a (single) hash reference or as 
a flattened list.

Basically, this means the following all mean the same thing:

 timestr (15, undef, 60, HOURS => 12 , XB => 1);
 timestr ([15, undef, 60], HOURS => 12, XB => 1);
 timestr (15, undef, 60, {HOURS => 12, XB => 1);
 timestr ([15, undef, 60], {HOURS => 12, XB => 1} );
 timestr ( TIME => [15, undef, 60] , HOURS => 12, XB => 1 );
 timestr ( { TIME => [15, undef, 60] , HOURS => 12, XB => 1 } );
 
(Actium::Time is politically liberal and believes strongly in acceptance.)
 
The named parameters are as follows:

=over

=item TIME

The time number, the number of minutes after midnight. (If negative, the 
number of minutes before midnight.)  Alternatively, an undefined value, in
which case timestr returns the empty string.

=item HOURS

The format: either a 12-hour format (with a.m./p.m. markers) or a 24-hour
format (without those markers). Valid values are '12' and '24'. The default
is '12'.

Times more than twelve hours before midnight, or after 36 hours after midnight,
will give an error if an attempt is made to present them in a 12-hour format.

=item APMARKERS

This is a reference to a list of markers for AM/PM status. If the 'XB' parameter
is false, can have either two or four entries, the latter two of which are 
ignored; if XB is true, must have four entries.

 MARKER  USED FOR                  DEFAULT
 0       a.m. times                'a'
 1       p.m. times                'p'
 2       times after midnight      'x'
         the following day
 3       times before midnight     'b'

Useful markers might be [' a.m.' , ' p.m.'] or [qw(A P X B)] .

An error will be generated if this parameter is present and the HOURS 
parameter is '24'.

=item XB

If true, will return times before midnight with marker #3 (default: 'b')
and times after midnight on the following day with marker #2 (default: 'x').
Otherwise, will use markers #0 ('p') and #1 ('a') respectively.  This defaults
to false.

An error will be generated if this parameter is present and the HOURS 
parameter is '24'.

=item LEADINGZERO

If true, the hours will be given with at least two digits: '01:15' instead of
'1:15'. The default is false.

=item SEPARATOR

This is a string that separates the hours from minutes. The default is 
a colon: '1:15a'. Supply the empty string for no separator: '115a'.

=back

If called in scalar context, returns a string of all the time strings joined 
together by tab characters. This is probably not what you want.

=item B<timestr_sub()>

This is designed to make it easier to supply a long list of parameters only once,
saving typing. It accepts all the same named parameters as B<timestr()>,
except TIME, and returns a reference to an anonymous subroutine that allows easy
access to that particular format. The anonymous subroutine accepts one argument,
which becomes the TIME parameter given above.

For example:

 $timesub = timestr_sub {HOURS => 24, LEADINGZERO => 1 , SEPARATOR => '.' };
 $timestr = $timesub->(75); # '01.15' - parameters are preserved
 
Since what happens when you call timestr is that it uses timestr_sub to generate
a subroutine and then promptly throws it away, it is strongly recommended that timestr_sub
be used in your program rather than timestr if the routine is used more than once with 
the same parameters.

=back

=head1 DIAGNOSTICS

=over

=item Invalid time [$origtime]

An invalid time string, not matching the formats Actium::Time knows about, 
was supplied to B<timenum()>

=item Cannot specify XB for 24 hour string

=item Cannot specify AM/PM markers for 24 hour string

A request was made to use a 24-hour format, and a parameter that doesn't
apply to the 24-hour format was included.

=item Improper number of AM/PM markers

A number of AM/PM markers was given that was other than exactly four 
(or two, if the XB parameter is false).

=item Time out of range

A time number was given for a 12-hour format that was more than 12 hours before,
or 36 hours after, midnight.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010

=item *

Params::Validate

=back

=head1 SEE ALSO

Actium::Cmd::Time provides a command-line interface to Actium::Time.

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


