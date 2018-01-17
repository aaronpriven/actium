use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'testutil.pl';
}

use Test::More 0.98 tests => 19;

BEGIN {
    note "These are tests of Actium::Dir.";
    use_ok 'Actium::Dir';
}

my $eb_obj = Actium::Dir->instance('EB');

isa_ok( $eb_obj, 'Actium::Dir' );
is( $eb_obj->dircode,      'EB',        'dircode is as expected' );
is( $eb_obj->as_bound,     'Eastbound', 'bound is as expected' );
is( $eb_obj->as_direction, 'East',      'direction is as expected' );
is( $eb_obj->as_onechar,   'E',         'onechar is as expected' );
is( $eb_obj->as_to_text,   'To ',       'to_text is as expected' );
cmp_ok( $eb_obj->preserve_order, '==', 0, 'preserve_order is as expected' );

cmp_ok( Actium::Dir->instance('EB'),
    '==', $eb_obj, 'Two instances with the same code are the same object' );

cmp_ok( Actium::Dir->instance('eb'),
    '==', $eb_obj,
    'Two instances with the codes differing only by case are the same object' );

cmp_ok( Actium::Dir->instance('EA'),
    '==', $eb_obj, 'Custom alias returns the same object' );

cmp_ok( Actium::Dir->instance('East'),
    '==', $eb_obj, 'Direction returns the same object' );

cmp_ok( Actium::Dir->instance('eastward'),
    '==', $eb_obj, 'Direction with ending "ward" returns the same object' );

cmp_ok( Actium::Dir->instance(3),
    '==', $eb_obj, 'Hastus Standard AVL direction returns the same object' );

my $cw_obj = Actium::Dir->instance('CW');
is( $cw_obj->as_to_text, 'Clockwise to ', 'to_text is as expected for loop' );

cmp_ok( $cw_obj->preserve_order, '==', 1,
    'preserve_order is as expected for loop' );

cmp_ok( $cw_obj->compare($eb_obj),
    '==', 1, 'compare returns correctly for object > second object' );

cmp_ok( $eb_obj->compare($cw_obj),
    '==', -1, 'compare returns correctly for object < second object' );

cmp_ok( $eb_obj->compare($eb_obj),
    '==', 0, 'compare returns correctly for object = second object' );

done_testing;

