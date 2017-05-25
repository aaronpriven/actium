package Actium::Constants 0.012;
# Cannot use Actium:.pm since that module depends on this one

use 5.020;
use warnings;
use Const::Fast;    ### DEP ###

use Scalar::Util('reftype');    ### DEP ###

my %constants;

## no critic (ProhibitMagicNumbers)

BEGIN {

    %constants = (
        EMPTY_STR     => \q{},
        EMPTY         => \q{},
        CRLF          => \qq{\cM\cJ},
        SPACE         => \q{ },
        MINS_IN_12HRS => \( 12 * 60 ),

        # FileMaker uses this separator for repeating fields, so I do too
        KEY_SEPARATOR => \"\c]",

        DIRCODES => [qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN  A  B )],
        #                0  1  3  2  4  5  6  7  8  9  10 11 12 13 14 15
        TRANSBAY_NOLOCALS => [qw/FS L NX NX1 NX2 NX3 U W/],

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

This module exports a series of constant values used by various Actium
modules.  They will be exported by default and are also available using
the fully-qualified form, e.g.,  $Actium::Constants::CRLF .

=head1 CONSTANTS

=over

=item $EMPTY_STR

=item $EMPTY

The empty string.

=item $CRLF

A carriage return followed by a line feed ("\r\n").

=item $SPACE

A space.

=item $KEY_SEPARATOR

This contains the C<^]> character (ASCII 29, "Group Separator"), which
is used by FileMaker to separate entries in repeating fields. It is
also used by various Actium routines to separate values, e.g., the
Hastus Standard AVL routines use it in hash keys when two or more
values are needed to uniquely identify a record. (This is the same
basic idea as that intended by perl's C<$;> variable [see
L<perlvar/$;>].)

=item $MINS_IN_12HRS

The number of minutes in 12 hours (12 times 60, or 720).

=item @DIRCODES

Direction codes (northbound, southbound, etc.)  The original few were
based on transitinfo.org directions, but have been extended to include
kinds of directions that didn't exist back then.

=item @HASTUS_DIRS

Numeric directions from Hastus, in the same order as @DIRCODES (so
@DIRCODES[5] is the same direction as @HASTUS_DIRS[5]).

=item @TRANSBAY_NOLOCALS

Transbay lines where local riding is prohibited. This should be moved 
to a database.

=item @HASTUS_CITY_OF

City codes associated with Hastus. Should be replaced with the "Code"
value in the "Cities" table in the Actium database.

=item %PV_TYPE

A hash whose keys are all the various type values that are part of
Params::Validate's ":types" export tag (SCALAR, ARRAYREF, HASHREF,
etc.). This way it avoids polluting the namespace with all those very
generic  values, while still allowing the use of Params::Validate
types. (Which are not at all related to Moose types.)

See L<Params::Validate|Params::Validate> for details on the values and
their  meanings.

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2015

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

