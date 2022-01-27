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
    my %of_daycode_hp_7 = (
        '1234567-B' => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        '1234567H'  => [ 1234567, 7, 'DA', 'DA', 'Every day', ],
        '135-H'     => [
            135, 3, 135, 'MWF', 'Mondays, Wednesdays and Fridays, except holidays',
        ],
        '3-D' => [ 3,  1, 3,    'W',      'Wednesdays except holidays', ],
        '57H' => [ 57, 2, 57,   'FSuHol', 'Fridays, Sundays and holidays', ],
        '67H' => [ 67, 2, 'WE', 'SSuHol', 'Saturdays, Sundays and holidays', ],
        1     => [ 1,  1, 1,    'M',      'Mondays except holidays', ],
        1234 =>
          [ 1234, 4, 1234, 'XF', 'Mondays through Thursdays, except holidays', ],
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
            135, 3, 135, 'MWF', 'Mondays, Wednesdays and Fridays, except holidays',
        ],
        2 => [ 2, 1, 2, 'T', 'Tuesdays except holidays', ],
        2345 =>
          [ 2345, 4, 2345, 'XM', 'Tuesdays through Fridays, except holidays', ],
        3  => [ 3,  1, 3,  'W',   'Wednesdays except holidays', ],
        4  => [ 4,  1, 4,  'Th',  'Thursdays except holidays', ],
        46 => [ 46, 2, 46, 'ThS', 'Thursdays and Saturdays, except holidays', ],
        5  => [ 5,  1, 5,  'F',   'Fridays except holidays', ],
        57 => [ 57,      2, 57,   'FSuHol', 'Fridays, Sundays and holidays', ],
        6  => [ 6,       1, 6,    'S',      'Saturdays except holidays', ],
        67 => [ 67,      2, 'WE', 'SSuHol', 'Saturdays, Sundays and holidays', ],
        7  => [ 7,       1, 7,    'SuHol',  'Sundays and holidays', ],
        DA => [ 1234567, 7, 'DA', 'DA',     'Every day', ],
        WD =>
          [ 12345, 5, 'WD', 'WD', 'Mondays through Fridays, except holidays', ],
        WE => [ 67, 2, 'WE', 'SSuHol', 'Saturdays, Sundays and holidays', ],
    );

    foreach my $daycode ( sort keys %of_daycode_hp_7 ) {
        my $obj  = Actium::OperatingDays::->instance($daycode);
        my $inst = "instance('$daycode')";
        is_blessed( $obj, 'Actium::OperatingDays', $inst );
        my $returned_daycode = $obj->daycode;
        is( $returned_daycode,
            $of_daycode_hp_7{$daycode}[NORMALIZED_DAYCODE],
            "Returned correct daycode: $inst"
        );

        is( $obj->as_string, $returned_daycode,
            "Returned same as_string as daycode: $inst" );

        is( $obj->bundle, $returned_daycode,
            "Returned same bundle as daycode: $inst" );

        is( $obj->count,
            $of_daycode_hp_7{$daycode}[COUNT],
            "Returned correct count: $inst"
        );
        is( $obj->sortable,
            $of_daycode_hp_7{$daycode}[SORTABLE],
            "Returned correct sortable: $inst"
        );
        is( $obj->holidaypolicy, 7, "Returned correct holiday policy: $inst" );
        is( $obj->as_shortcode,
            $of_daycode_hp_7{$daycode}[SHORTCODE],
            "Returned correct shortcode: $inst"
        );
        is( $obj->as_full,
            $of_daycode_hp_7{$daycode}[FULL],
            "Returned correct full description: $inst"
        );
        is( $obj->as_specdayletter,
            $of_daycode_hp_7{$daycode}[SPECDAYLETTER],
            "Returned correct specdayletter: $inst"
        );
        my $obj2 = Actium::OperatingDays::->instance($daycode);
        cmp_ok( $obj, '==', $obj2, "Second instance same as the first: $inst" );

        if ( $returned_daycode ne $daycode ) {
            my $canonical_obj
              = Actium::OperatingDays::->instance($returned_daycode);
            cmp_ok( $obj, '==', $canonical_obj,
                    "Instance same as canonical daycode "
                  . "'$returned_daycode': $inst" );
            $testcount++;
        }

        is( $obj->holidaypolicy, 7,
            "Returned correct holiday policy 7: $inst" );

        my $obj_with_holpol
          = Actium::OperatingDays::->instance( $daycode, holidaypolicy => 7 );
        cmp_ok( $obj, '==', $obj_with_holpol,
            "Instance same with explicit holidaypolicy '7': $inst" );

        is( $obj_with_holpol->holidaypolicy, 7,
            "Object with explicit holpol setting returned it correctly: $inst"
        );

    }

    $testcount += 14 * scalar keys %of_daycode_hp_7;

}

{

    my %of_daycode_w_hp = (
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
            'Mondays, Tuesdays, Wednesdays and Fridays, except holidays', '1235:4',
        ],
        1245 => [
            1245, 4, 2, 'XWHol',
            'Mondays, Tuesdays, Thursdays, Fridays and holidays', '1245:2',
        ],
        1345 => [
            1345, 4, 6, 'XT',
            'Mondays, Wednesdays, Thursdays and Fridays, except holidays', '1345:6',
        ],
        135 => [
            135, 3, 0, 'MWF', 'Mondays, Wednesdays and Fridays',
            '135:0',
        ],
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
        6 => [ 6, 1, 6, 'SHol', 'Saturdays and holidays', '6:6', ],
        67 =>
          [ 67, 2, 2, 'SSu', 'Saturdays and Sundays, except holidays', '67:2', ],
        7  => [ 7,       1, 6, 'Su', 'Sundays except holidays', '7:6', ],
        DA => [ 1234567, 7, 0, 'DA', 'Every day',              '1234567:0', ],
        DA => [ 1234567, 7, 3, 'DA', 'Every day',              '1234567:3', ],
        WD => [
            12345, 5, 0, 'WD', 'Mondays through Fridays', '12345:0',
        ],
        WE => [ 67, 2, 4, 'SSu', 'Saturdays and Sundays, except holidays', '67:4' ],
    );

    foreach my $daycode ( sort keys %of_daycode_w_hp ) {
        my $holpol = $of_daycode_w_hp{$daycode}[HOLPOL];
        my $obj    = Actium::OperatingDays::->instance( $daycode,
            holidaypolicy => $holpol );
        my $inst = "($daycode:$holpol)";

        is_blessed( $obj, 'Actium::OperatingDays', $inst );
        my $returned_daycode = $obj->daycode;
        is( $returned_daycode,
            $of_daycode_w_hp{$daycode}[NORMALIZED_DAYCODE],
            "Returned correct daycode: $inst"
        );
        my $bundle = $of_daycode_w_hp{$daycode}[BUNDLE];

        is( $obj->as_string, $bundle, "Returned correct as_string: $inst" );
        is( $obj->bundle,    $bundle, "Returned same bundle: $inst" );
        is( $obj->count,
            $of_daycode_w_hp{$daycode}[COUNT],
            "Returned correct count: $inst"
        );
        is( $obj->sortable,
            $of_daycode_w_hp{$daycode}[SORTABLE],
            "Returned correct sortable: $inst"
        );
        is( $obj->holidaypolicy, $holpol,
            "Returned correct holiday policy: $inst" );
        is( $obj->as_full,
            $of_daycode_w_hp{$daycode}[FULL],
            "Returned correct full description: $inst"
        );
        is( $obj->as_specdayletter,
            $of_daycode_w_hp{$daycode}[SPECDAYLETTER],
            "Returned correct specdayletter: $inst"
        );
        my $obj2 = Actium::OperatingDays::->instance( $daycode,
            holidaypolicy => $holpol );
        cmp_ok( $obj, '==', $obj2, "Second instance same as the first: $inst" );

        if ( $returned_daycode ne $daycode ) {
            my $canonical_obj
              = Actium::OperatingDays::->instance( $returned_daycode,
                holidaypolicy => $holpol );
            cmp_ok( $obj, '==', $canonical_obj,
                    "Instance same as canonical daycode "
                  . "'$returned_daycode': $inst" );
            $testcount++;
        }

    }

    $testcount += 10 * scalar keys %of_daycode_w_hp;

}

# to test:
#
# invalid days and holiday policy throws
#
# unbundle
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

