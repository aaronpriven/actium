# Actium/Constants.pm
# Various constants

# Should this be combined with Actium::Preamble?

# legacy stages 3 and 4

use strict;
use warnings;

package Actium::Constants 0.010;
# Cannot use Actium::Preamble since that module depends on this one

use 5.016;
use Const::Fast;    ### DEP ###

use Scalar::Util('reftype');   ### DEP ###

my %constants;

## no critic (ProhibitMagicNumbers)

BEGIN {

    %constants = (
        EMPTY_STR     => \q{},
        EMPTY         => \q{},
        CR            => \"\cM",
        LF            => \"\cJ",
        TAB           => \"\t",
        CRLF          => \qq{\cM\cJ},
        SPACE         => \q{ },
        DQUOTE        => \q{"},
        VERTICALTAB   => \qq{\cK},
        MINS_IN_12HRS => \( 12 * 60 ),

        # FileMaker uses this separator for repeating fields, so I do too
        KEY_SEPARATOR => \"\c]",

        LINES_TO_COMBINE => {
            '72M' => '72',
            '386' => '86',
            'NC'  => 'NX4',
            'NXC' => 'NX4',
            'LC'  => 'L',
        },

        SCHEDULE_DAYS => [qw/WD SA SU WA WU WE DA/],
        # Weekdays, Saturdays, Sundays, Weekdays-and-Saturdays,
        # Weekdays-and-Sundays, Weekends, Daily

        DIRCODES => [qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN A B )],
        LOOP_DIRECTIONS     => [qw( CW CC A B )],
        TRANSBAY_NOLOCALS   => [qw/FS L NX NX1 NX2 NX3 U W/],
        LINES_TO_BE_SKIPPED => [399],



        SIDE_OF => {
            ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 98 99/ ) ),
            ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
        },

        HASTUS_CITY_OF => {
            "01" => "Alameda",
            "02" => "Albany",
            "03" => "Berkeley",
            "04" => "Castro Valley",
            "05" => "El Cerrito",
            "06" => "Emeryville",
            "07" => "Fremont",
            "08" => "Hayward",
            "09" => "Newark",
            "10" => "Oakland",
            "11" => "Piedmont",
            "12" => "Pinole",
            "13" => "Richmond",
            "14" => "San Francisco",
            "15" => "San Leandro",
            "16" => "San Pablo",
            "17" => "Union City",
            "18" => "Foster City",
            "19" => "San Mateo",
            "20" => "San Lorenzo",
            "21" => "Orinda",
            "22" => "Palo Alto",
            "23" => "Milpitas",
            "24" => "Menlo Park",
            "25" => "Redwood City",
            "26" => "East Palo Alto",
            "97" => "Santa Clara County",
            "98" => "Alameda County",
            "99" => "Contra Costa County",

        },

    );

    {
        require Params::Validate;    ### DEP ###
        my %pv_type;

        my @pv = @{ $Params::Validate::EXPORT_TAGS{'types'} };
        foreach (@pv) {
            my $name = 'Params::Validate::' . $_;
            no strict 'refs';
            my $value = &$name;
            $pv_type{$_} = $value;
        }

        $constants{PV_TYPE} = \%pv_type;
    }

    foreach ( 1 .. 9 ) {
        $constants{HASTUS_CITY_OF}{$_} = $constants{HASTUS_CITY_OF}{"0$_"};
    }    # add single-digit versions as well

    $constants{IS_A_LOOP_DIRECTION}{$_} = 1
      foreach @{ $constants{LOOP_DIRECTIONS} };

    $constants{LINE_SHOULD_BE_SKIPPED}{$_} = 1
      foreach @{ $constants{LINES_TO_BE_SKIPPED} };

    $constants{HASTUS_DIRS}
      = [ 0, 1, 3, 2, 4 .. scalar @{ $constants{DIRCODES} } ];

    no warnings 'once';
    no strict 'refs';

    foreach my $name ( keys %constants ) {
        my $value = $constants{$name};
        #*{$name} = $value;    # supports <sigil>__PACKAGE__::<variable>
        my $qualname = __PACKAGE__ . q{::} . $name;
        my $reftype  = reftype($value);

        if ( not $reftype ) {
            $value            = \$value;     # non-references turn to references
            $constants{$name} = $value;
            $reftype          = 'SCALAR',;
        }

        if ( $reftype eq 'HASH' ) {
            const %{$qualname}, %{$value};
        }
        elsif ( $reftype eq 'ARRAY' ) {
            const @{$qualname}, @{$value};
        }
        elsif ( $reftype eq 'SCALAR' ) {
            const ${$qualname}, ${$value};
        }
        else {
            die "Can't make $reftype into a constant";
            #const ${$qualname}, $value;
        }
    } ## tidy end: foreach my $name ( keys %constants)

} ## tidy end: BEGIN

sub import {
    my $caller = caller;
    no strict 'refs';
    while ( my ( $name, $value ) = each(%constants) ) {
        my $reftype    = reftype($value);
        my $callername = $caller . '::' . $name;

        if ( $reftype eq 'HASH' ) {
            *{$callername} = \%{$name};
        }
        elsif ( $reftype eq 'ARRAY' ) {
            *{$callername} = \@{$name};
        }
        elsif ( $reftype eq 'SCALAR' or $reftype eq 'REF' ) {
            *{$callername} = \${$name};
        }
        else {
            die "Can't make $reftype into a constant";
        }

        #*{ $caller . q{::} . $name } = $value;
    }
    return;
} ## tidy end: sub import

1;

__END__

=head1 NAME

Actium::Constants - constants used across Actium modules

=head1 VERSION

This documentation refers to Actium::Constants version 0.005

=head1 SYNOPSIS

 use Actium::Constants;
 $new_string = join($SPACE , @whatever) . $CRLF;
   
=head1 DESCRIPTION

This module exports a series of constant values used by various
Actium modules.  They will be exported by default and are also
available using the fully-qualified form, e.g., 
$Actium::Constants::CRLF .

=head1 CONSTANTS

=over

=item $EMPTY_STR

=item $EMPTY

The empty string.

=item $CR

A carriage return.

=item $LF

A line feed.

=item $CRLF

A carriage return followed by a line feed ("\r\n").

=item $TAB

A tab.

=item $SPACE

A space.

=item $DQUOTE

A double quote (useful for interpolation).

=item $VERTICALTAB

A vertical tab, used to separate multiline fields in FileMaker.

=item $KEY_SEPARATOR

This contains the C<^]> character (ASCII 29, "Group Separator"),
which is used by FileMaker to separate entries in repeating fields.
It is also used by various Actium routines to separate values, e.g.,
the Hastus Standard AVL routines use it in hash keys when two or
more values are needed to uniquely identify a record. (This is the
same basic idea as that intended by perl's C<$;> variable [see
L<perlvar/$;>].)

=item $MINS_IN_12HRS

The number of minutes in 12 hours (12 times 60, or 720). 

=item %LINES_TO_COMBINE

This contains a hard-wired hash of lines. Each key is a line that
should be consolidated with another line on its schedule: for
example, 59A should appear with 59, and 72M should appear with 72.
It is not possible to simply assume that a line should appear with
all its subsidiary lines since some lines do not fit this pattern
(386 and 83 go on 86 while 72R does not go on 72).

This is not the right place to store this information; 
it should be moved to a user-accessible database.

=item @SCHEDULE_DAYS

This is a list of valid schedule day codes. Each set of schedules
is either the set of schedules for weekdays (WD), Saturdays (SA),
or Sundays (SU). Sometimes these can be combined, so we have
combinations: weekends (WE), and every day (DA). For completeness
we also have weekdays and Saturdays (WA) and weekdays and Sundays
(WU), although usage is expected to be extremely rare.

These originate from the old transitinfo.org web site, which many years ago
helped parse the schedules. That went away a long time ago, but the codes
live on.

=item @DIRCODES

Direction codes (northbound, southbound, etc.)  The original few were
based on transitinfo.org directions, but have been extended to include kinds
of directions that didn't exist back then.

=item @HASTUS_DIRS

Numeric directions from Hastus, in the same order as @DIRCODES (so @DIRCODES[5]
is the same direction as @HASTUS_DIRS[5]).

=item @LOOP_DIRECTIONS

=item %IS_A_LOOP_DIRECTION

Those directions that are loops: counterclockwise and clockwise, and A and B.
The hash version just allows an easy "is this a loop direction" lookup.

=item @TRANSBAY_NOLOCALS

Transbay lines where local riding is prohibited. This should be moved 
to a database.

=item @LINES_TO_BE_SKIPPED

=item %LINE_SHOULD_BE_SKIPPED

Lines that should not be used at all. This should be moved to a database. 
The hash version just allows an easy "should this line be skipped" lookup.

=item %SIDE_OF

Of city codes, "E" if it's in the East Bay, "W" for the West Bay. Used for 
determining whether "Transbay Passengers Only" needs to be 
put on flags, among other things. Should be replaced with the "Side" value in 
the "Cities" table in the Actium database. (Perhaps should even be replaced 
by a more general fare-zone value associated with stops...)

=item @HASTUS_CITY_OF

City codes associated with Hastus. Should be replaced with the "Code" value
in the "Cities" table in the Actium database.

=item %PV_TYPE

A hash whose keys are all the various type values that are part of
Params::Validate's ":types" export tag (SCALAR, ARRAYREF, HASHREF, etc.).
This way it avoids polluting the namespace with all those very generic 
values, while still allowing the use of Params::Validate types.
(Which are not at all related to Moose types.)

See L<Params::Validate|Params::Validate> for details on the values and their 
meanings.

=back

=head1 BUGS AND LIMITATIONS

See L</%LINES_TO_COMBINE>.

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
