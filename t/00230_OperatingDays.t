use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98;
use Scalar::Util('refaddr');

my $testcount = 0;

BEGIN {
    note "These are tests of Actium::OperatingDays.";
    use_ok 'Actium::OperatingDays';
}

$testcount += 1;

note 'simple object creation';

foreach my $daycode (qw/12345 67/) {
    my $obj = Actium::OperatingDays->instance($daycode);
    isa_ok( $obj, 'Actium::OperatingDays', "instance('$daycode')" );
}

$testcount += 2;

note 'warnings for backwards compatibility';

my %warning_of = (
    '12345-B' => {
        regex   => qr/Stripping old-style school code/,
        descrip => 'Warns when supplied with old style school code'
    },
    '67H' => {
        regex   => qr/Stripping old-style Sunday-and-holiday H/,
        descrip => 'Warns when supplied with Sundays-and-holiday H'
    },
);

note 'exceptions for bad data';

test_exception { my $empty = Actium::OperatingDays->instance('') }
'Daycode empty string throws', qr/type constraint/;

test_exception { my $h_only = Actium::OperatingDays->instance('H') }
'Daycode "H" throws', qr/type constraint/;

test_exception {
    my $hol_pol_8 = Actium::OperatingDays->instance( '1', holidaypolicy => 8 )
}
'Holidaypolicy "8" throws', qr/type constraint/;

$testcount += 2 * 3;

foreach my $to_test ( sort keys %warning_of ) {
    run_code_and_warn_maybe { Actium::OperatingDays::->instance($to_test) }
    $warning_of{$to_test}{regex}, $warning_of{$to_test}{descrip},;
}

$testcount += ( scalar keys %warning_of );

note "varied daycodes objects with holidaypolicy=7";

use constant {
    NORMALIZED_DAYCODE => 0,
    SORTABLE           => 0,
    COUNT              => 1,
    SHORTCODE          => 2,
    HOLPOL             => 2,
    SPECDAYLETTER      => 3,
    FULL               => 4,
    BUNDLE             => 5,
};

{
    my %of_daycode = (
        '1234567-B' => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        '1234567H'  => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        '135-H'     => [
            135, 3, 135, 'MWF',
            'Mondays, Wednesdays and Fridays, except holidays',
        ],
        '3-D' => [ 3,  1, 3,    'W',      'Wednesdays except holidays', ],
        '57H' => [ 57, 2, 57,   'FSuHol', 'Fridays, Sundays and holidays', ],
        '67H' => [ 67, 2, 'WE', 'SSuHol', 'Saturdays, Sundays and holidays', ],
        1     => [ 1,  1, 1,    'M',      'Mondays except holidays', ],
        1234  => [
            1234, 4, 1234, 'XF', 'Mondays through Thursdays, except holidays',
        ],
        12345 =>
          [ 12345, 5, 'WD', 'WD', 'Mondays through Fridays, except holidays', ],
        1234567 => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        1235    => [
            1235, 4, 1235, 'XTh',
            'Mondays, Tuesdays, Wednesdays and Fridays, except holidays',
        ],
        1245 => [
            1245, 4, 1245, 'XW',
            'Mondays, Tuesdays, Thursdays and Fridays, except holidays',
        ],
        1345 => [
            1345, 4, 1345, 'XT',
            'Mondays, Wednesdays, Thursdays and Fridays, except holidays',
        ],
        135 => [
            135, 3, 135, 'MWF',
            'Mondays, Wednesdays and Fridays, except holidays',
        ],
        2 => [ 2, 1, 2, 'T', 'Tuesdays except holidays', ],
        2345 =>
          [ 2345, 4, 2345, 'XM', 'Tuesdays through Fridays, except holidays', ],
        3  => [ 3,  1, 3,  'W',   'Wednesdays except holidays', ],
        4  => [ 4,  1, 4,  'Th',  'Thursdays except holidays', ],
        46 => [ 46, 2, 46, 'ThS', 'Thursdays and Saturdays, except holidays', ],
        5  => [ 5,  1, 5,  'F',   'Fridays except holidays', ],
        57 => [ 57, 2, 57,   'FSuHol',  'Fridays, Sundays and holidays', ],
        6  => [ 6,  1, 6,    'S',       'Saturdays except holidays', ],
        67 => [ 67, 2, 'WE', 'SSuHol',  'Saturdays, Sundays and holidays', ],
        7  => [ 7,  1, 7,    'SuHol',   'Sundays and holidays', ],
        DA => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        WD =>
          [ 12345, 5, 'WD', 'WD', 'Mondays through Fridays, except holidays', ],
        WE => [ 67, 2, 'WE', 'SSuHol', 'Saturdays, Sundays and holidays', ],
    );

    foreach my $daycode ( sort keys %of_daycode ) {
        my $obj  = Actium::OperatingDays::->instance($daycode);
        my $inst = "instance('$daycode')";
        is_blessed( $obj, 'Actium::OperatingDays', $inst );

        my $norm_daycode = $of_daycode{$daycode}[NORMALIZED_DAYCODE];
        is( $obj->daycode, $norm_daycode,
            "... Returned correct daycode '$norm_daycode': $inst" );

        is( $obj->as_string, $norm_daycode,
            "... Returned correct as_string '$norm_daycode': $inst" );

        is( $obj->bundle, $norm_daycode,
            "... Returned correct bundle '$norm_daycode': $inst" );

        my $givencount = $of_daycode{$daycode}[COUNT];
        is( $obj->count, $givencount,
            "... Returned correct count '$givencount': $inst" );
        my $givensortable = $of_daycode{$daycode}[SORTABLE];
        is( $obj->sortable, $givensortable,
            "... Returned correct sortable '$givensortable': $inst" );
        is( $obj->holidaypolicy, 7,
            "... Returned correct holiday policy '7': $inst" );
        my $givenshortcode = $of_daycode{$daycode}[SHORTCODE];
        is( $obj->as_shortcode, $givenshortcode,
            "... Returned correct shortcode: $inst" );
        my $givenfull = $of_daycode{$daycode}[FULL];
        is( $obj->as_full, $givenfull,
            "... Returned correct full description '$givenfull': $inst" );
        my $givenspecdayletter = $of_daycode{$daycode}[SPECDAYLETTER];
        is( $obj->as_specdayletter, $givenspecdayletter,
            "... Returned correct specdayletter '$givenspecdayletter': $inst" );
        my $obj2 = Actium::OperatingDays::->instance($daycode);
        cmp_ok( $obj, '==', $obj2, "Second instance same as the first: $inst" );

        if ( $norm_daycode ne $daycode ) {
            my $canonical_obj
              = Actium::OperatingDays::->instance($norm_daycode);
            cmp_ok( $obj, '==', $canonical_obj,
                    "... Instance same as canonical daycode "
                  . "'$norm_daycode': $inst" );
            $testcount++;
        }

        my $obj_with_holpol
          = Actium::OperatingDays::->instance( $daycode, holidaypolicy => 7 );
        cmp_ok( $obj, '==', $obj_with_holpol,
            "... Instance same with explicit holidaypolicy '7': $inst" );

        is( $obj_with_holpol->holidaypolicy, 7,
                "... Object with explicit holpol setting '7' "
              . "returned it correctly: $inst" );

        my $unbundled_obj = Actium::OperatingDays::->unbundle($norm_daycode);
        is_blessed( $unbundled_obj, 'Actium::OperatingDays',
            "Unbundling '$norm_daycode'" );

        is( $unbundled_obj->daycode, $norm_daycode,
            "...... and it returns correct daycode '$norm_daycode'" );
        is( $unbundled_obj->holidaypolicy,
            7, "...... and it returns correct holiday policy '7'" );

        cmp_ok( $obj, '==', $unbundled_obj,
            "...... Unbundled instance same as the initial: '$norm_daycode'" );

    }

    $testcount += 17 * scalar keys %of_daycode;

}



{
    my %of_daycode = (
        1    => [ 1, 1, 1, 'MHol', 'Mondays and holidays', '1:1' ],
        1234 => [
            1234, 4, 5, 'XF', 'Mondays through Thursdays, except holidays',
            '1234:5'
        ],
        12345 => [
            12345, 5, 6, 'WD', 'Mondays through Fridays, except holidays',
            '12345:6'
        ],
        1234567 => [ 1234567, 7, 0, 'DA', 'Every day', '1234567:0' ],
        1234567 => [ 1234567, 7, 6, 'DA', 'Every day', '1234567:6' ],
        1235    => [
            1235, 4, 4, 'XTh',
            'Mondays, Tuesdays, Wednesdays and Fridays, except holidays',
            '1235:4',
        ],
        1245 => [
            1245, 4, 2, 'XWHol',
            'Mondays, Tuesdays, Thursdays, Fridays and holidays', '1245:2',
        ],
        1345 => [
            1345, 4, 6, 'XT',
            'Mondays, Wednesdays, Thursdays and Fridays, except holidays',
            '1345:6',
        ],
        135 =>
          [ 135, 3, 0, 'MWF', 'Mondays, Wednesdays and Fridays', '135:0', ],
        2    => [ 2, 1, 3, 'T', 'Tuesdays except holidays', '2:3', ],
        2345 => [
            2345, 4, 5, 'XMHol', 'Tuesdays through Fridays and holidays',
            '2345:5'
        ],
        3 => [ 3, 1, 3, 'WHol', 'Wednesdays and holidays',   '3:3', ],
        4 => [ 4, 1, 3, 'Th',   'Thursdays except holidays', '4:3', ],
        46 =>
          [ 46, 2, 6, 'ThSHol', 'Thursdays, Saturdays and holidays', '46:6', ],
        5 => [ 5, 1, 5, 'FHol', 'Fridays and holidays', '5:5' ],
        57 =>
          [ 57, 2, 6, 'FSu', 'Fridays and Sundays, except holidays', '57:6', ],
        6  => [ 6, 1, 6, 'SHol', 'Saturdays and holidays', '6:6', ],
        67 => [
            67, 2, 2, 'SSu', 'Saturdays and Sundays, except holidays', '67:2',
        ],
        7  => [ 7,       1, 6, 'Su', 'Sundays except holidays', '7:6', ],
        DA => [ 1234567, 7, 0, 'DA', 'Every day',               '1234567:0', ],
        DA => [ 1234567, 7, 3, 'DA', 'Every day',               '1234567:3', ],
        WD => [ 12345,   5, 0, 'WD', 'Mondays through Fridays', '12345:0', ],
        WE =>
          [ 67, 2, 4, 'SSu', 'Saturdays and Sundays, except holidays', '67:4' ],
    );

    foreach my $daycode ( sort keys %of_daycode ) {
        my $holpol = $of_daycode{$daycode}[HOLPOL];
        my $obj    = Actium::OperatingDays::->instance( $daycode,
            holidaypolicy => $holpol );
        my $inst = "($daycode:$holpol)";

        is_blessed( $obj, 'Actium::OperatingDays', $inst );
        my $norm_daycode = $of_daycode{$daycode}[NORMALIZED_DAYCODE];
        is( $norm_daycode, $obj->daycode,
            "... Returned correct daycode '$norm_daycode': $inst" );
        my $bundle = $of_daycode{$daycode}[BUNDLE];

        is( $obj->as_string, $bundle,
            "... Returned correct as_string '$bundle': $inst" );
        is( $obj->bundle, $bundle,
            "... Returned same bundle '$bundle': $inst" );

        my $givencount = $of_daycode{$daycode}[COUNT];
        is( $obj->count, $givencount,
            "... Returned correct count '$givencount': $inst" );
        my $givensortable = $of_daycode{$daycode}[SORTABLE];
        is( $obj->sortable, $givensortable,
            "... Returned correct sortable '$givensortable': $inst" );

        is( $obj->holidaypolicy, $holpol,
            "... Returned correct holiday policy '$holpol': $inst" );
        is( $obj->as_full,
            $of_daycode{$daycode}[FULL],
            "... Returned correct full description: $inst"
        );
        is( $obj->as_specdayletter,
            $of_daycode{$daycode}[SPECDAYLETTER],
            "... Returned correct specdayletter: $inst"
        );
        my $obj2 = Actium::OperatingDays::->instance( $daycode,
            holidaypolicy => $holpol );
        cmp_ok( $obj, '==', $obj2,
            "... Second instance same as the first: $inst" );

        if ( $norm_daycode ne $daycode ) {
            my $canonical_obj
              = Actium::OperatingDays::->instance( $norm_daycode,
                holidaypolicy => $holpol );
            my $norm_inst = "($norm_daycode:$holpol)";
            cmp_ok( $obj, '==', $canonical_obj,
                    "... Instance same as canonical daycode "
                  . "'$norm_inst': $inst" );
            $testcount++;

        }

        my $unbundled_obj = Actium::OperatingDays::->unbundle($bundle);
        is_blessed( $unbundled_obj, 'Actium::OperatingDays',
            "Unbundling '$bundle'" );

        is( $unbundled_obj->daycode, $norm_daycode,
            "...... and it returns correct daycode '$norm_daycode'" );
        is( $unbundled_obj->holidaypolicy,
            $holpol, "...... and it returns correct holiday policy '$holpol'" );

        cmp_ok( $obj, '==', $unbundled_obj,
            "...... Unbundled instance same as the initial: '$bundle'" );

    }

    $testcount += 14 * scalar keys %of_daycode;

}

# to test:
#
# is_equal_to
# union
# intersection
# is_a_superset_of
# specday_and_specdayletter

done_testing($testcount);

__END__

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

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

