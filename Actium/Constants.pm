# Actium/Constants.pm
# Various constants

# Subversion: $Id$

# legacy stages 3 and 4

use strict;
use warnings;

package Actium::Constants 0.003;
# Cannot use Actium::Preamble since that module depends on this one

use 5.016;
use Const::Fast;

my %constants;

## no critic (ProhibitMagicNumbers)

BEGIN {

    %constants = (
        FALSE       => \0,
        TRUE        => \( not 0 ),
        EMPTY_STR   => \q{},
        CRLF        => \qq{\cM\cJ},
        SPACE       => \q{ },
        DQUOTE      => \q{"},
        VERTICALTAB => \qq{\cK},

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

        TRANSITINFO_DAYS_OF => {
            qw(
              1234567H DA
              123457H  WU
              123456   WA
              12345    WD
              1        MY
              2        TY
              3        WY
              4        TH
              5        FY
              6        SA
              56       FS
              7H       SU
              67H      WE
              24       TT
              25       TF
              35       WF
              135      MZ
              )
        },

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
    
    foreach (1 .. 9) {
        $constants{HASTUS_CITY_OF}{$_} = 
        $constants{HASTUS_CITY_OF}{"0$_"};
    } # add single-digit versions as well

    $constants{IS_A_LOOP_DIRECTION}{$_} = 1
      foreach @{ $constants{LOOP_DIRECTIONS} };

    $constants{LINE_SHOULD_BE_SKIPPED}{$_} = 1
      foreach @{ $constants{LINES_TO_BE_SKIPPED} };

    $constants{HASTUS_DIRS}
      = [ 0, 1, 3, 2, 4 .. scalar @{ $constants{DIRCODES} } ];

    $constants{DAYS_FROM_TRANSITINFO}
      = { reverse %{ $constants{TRANSITINFO_DAYS_OF} } };

    no warnings 'once';
    no strict 'refs';

    while ( my ( $name, $value ) = each(%constants) ) {
        #*{$name} = $value;    # supports <sigil>__PACKAGE__::<variable>
        my $qualname = __PACKAGE__ . q{::} . $name;
        my $reftype  = ref($value);
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
            const ${$qualname}, $value;
        }
    }

} ## tidy end: BEGIN

sub import {
    my $caller = caller;
    no strict 'refs';
    while ( my ( $name, $value ) = each(%constants) ) {
        *{ $caller . q{::} . $name } = $value;
    }
    return;
}

1;

__END__

=head1 NAME

Actium::Constants - constants used across Actium modules

=head1 VERSION

This documentation refers to Actium::Constants version 0.001

=head1 SYNOPSIS

 use Actium::Constants;
 $new_string = join($SPACE , @whatever) . $CRLF;
   
=head1 DESCRIPTION

This module exports a series of constant values used by various
Actium modules.  They will be exported by default and are also
available using the fully-qualified form, e.g., 
$Actium::Constants::CRLF .

=head1 CONSTANTS

See the code for the values of the constants. Most are obvious.
Some exceptions:

=over

=item $KEY_SEPARATOR

This contains the C<^]> character (ASCII 29, "Group Separator"),
which is used by FileMaker to separate entries in repeating fields.
It is also used by various Actium routines to separate values, e.g.,
the Hastus Standard AVL routines use it in hash keys when two or
more values are needed to uniquely identify a record. (This is the
same basic idea as that intended by perl's C<$;> variable [see
L<perlvar/$;>].)

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

=back

=head1 BUGS AND LIMITATIONS

See L</%LINES_TO_COMBINE>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2014

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
