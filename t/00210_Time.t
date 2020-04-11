use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

use Actium::TestUtil;

use Test::More 0.98;

my $testcount = 0;

BEGIN {
    note "These are tests of Actium::Time.";
    use_ok 'Actium::Time';
}

$testcount += 1;

note 'from_num() creation';

my @numtests = ( 60, -500, 2000 );
$testcount += @numtests;

for my $num (@numtests) {
    my $obj = Actium::Time->from_num($num);
    cmp_ok( $obj->timenum, '==', $num,
        "Returned correct number: from-num($num)" );
}

my $MINS_IN_12HRS = ( 12 * 60 );

my %NAMED = (
    NOON_YESTERDAY    => -$MINS_IN_12HRS,
    MIDNIGHT          => 0,
    NOON              => $MINS_IN_12HRS,
    MIDNIGHT_TOMORROW => 2 * $MINS_IN_12HRS,
    MAX_TIME          => ( 3 * $MINS_IN_12HRS ) - 1,
    NO_VALUE          => -32000,
    f                 => -32001,
    i                 => -32002,
);

note 'from_num() specials';

{
    my $flextime = Actium::Time->from_num( $NAMED{f} );
    is( $flextime->timenum, $NAMED{f},
        'Timenum for flex is ' . $NAMED{f} . ' - from_num' );

    my $intertime = Actium::Time->from_num( $NAMED{i} );
    is( $intertime->timenum, $NAMED{i},
        'Timenum for interpolate is ' . $NAMED{i} . ' - from_num' );

    my $notime = Actium::Time->from_num(undef);
    is( $notime->timenum, $NAMED{NO_VALUE},
        'Timenum for undef is ' . $NAMED{NO_VALUE} . ' - from_num' );

    $testcount += 3;
}

note 'from_str() creation';

my %timenum_of = (
    '-030'                 => -30,
    '-1000'                => -600,
    '-115'                 => -75,
    '100'                  => 60,
    '1100b'                => -60,
    '13:01'                => 781,
    '1999-12-31T16:50:00Z' => -430,
    '2000-01-01T11:01:00'  => 661,
    '2000-01-02T2:01'      => 1561,
    '200a'                 => 120,
    '27:35'                => 1655,
    '3:30p'                => 930,
    '517x'                 => 1757,
    MAX_TIME               => 2159,
    MIDNIGHT               => 0,
    MIDNIGHT_TOMORROW      => 1440,
    NOON                   => 720,
    NOON_YESTERDAY         => -720,
    q{22'30}               => -90,
);

$testcount += keys %timenum_of;

for my $string ( sort keys %timenum_of ) {
    my $obj = Actium::Time->from_str($string);
    cmp_ok( $obj->timenum, '==', $timenum_of{$string},
        "Returned correct number: from_str($string)" );
}

note 'from_str() specials';

my $flextime = Actium::Time->from_str('f');
is( $flextime->timenum, $NAMED{f},
    'Timenum for flex is ' . $NAMED{f} . ' - from_str' );

my $intertime = Actium::Time->from_str('i');
is( $intertime->timenum, $NAMED{i},
    'Timenum for interpolate is ' . $NAMED{i} . ' - from_str' );

my $notime = Actium::Time->from_str('');
is( $notime->timenum, $NAMED{NO_VALUE},
    'Timenum for empty str is ' . $NAMED{NO_VALUE} . ' - from_str' );

my $undeftime = Actium::Time->from_str(undef);
is( $undeftime->timenum, $NAMED{NO_VALUE},
    'Timenum for undef is ' . $NAMED{NO_VALUE} . ' - from_str' );

$testcount += 4;

package Actium::MockCell {
    use Moose;
    has [qw /value unformatted/] => ( is => 'ro' );
}

{
    note 'from_excel()';

    my %cell_of = (
        180 => Actium::MockCell->new(
            unformatted => 180 / 1440,
            value       => '3:00'
        ),
        930 =>
          Actium::MockCell->new( unformatted => '15:30', value => '15:30' ),
    );

    $testcount += keys %cell_of;

    foreach my $timenum ( keys %cell_of ) {
        my $timeobj = Actium::Time->from_excel( $cell_of{$timenum} );
        cmp_ok( $timeobj->timenum, '==', $timenum,
                'Returned correct number: from_excel(value =>'
              . $cell_of{$timenum}->value
              . ', unformatted => '
              . $cell_of{$timenum}->unformatted
              . '.' );
    }

}

note 'type constraint in from_num';

test_exception { my $empty = Actium::Time->from_num('') }
'Violating type constraint with empty string throws', qr/type constraint/;

test_exception { my $floating = Actium::Time->from_num(5.5) }
'Violating type constraint with non-integer throws', qr/type constraint/;

test_exception { my $x = Actium::Time->from_num('x') }
'Violating type constraint with invalid string throws', qr/type constraint/;

test_exception { my $x = Actium::Time->from_num('3:30') }
'Violating type constraint with time string throws', qr/type constraint/;

$testcount += ( 4 * 2 );
# exceptions test twice -- does it throw, and is it the right
# exception

note "caches";

$testcount += 5;

{
    my $numobj  = Actium::Time->from_num(3);
    my $num2obj = Actium::Time->from_num(3);
    cmp_ok $numobj, '==', $num2obj,
      'Number fetches same object as previously queried number';
}

{
    my $strobj  = Actium::Time->from_str('0:04');
    my $str2obj = Actium::Time->from_str('0:04');
    cmp_ok $strobj, '==', $str2obj,
      'String fetches same object as previously queried identical string';
}

{
    my $strobj  = Actium::Time->from_str('-0:05');
    my $str2obj = Actium::Time->from_str('1155b');
    cmp_ok $strobj, '==', $str2obj,
      'String fetches same object as previously queried equivalent string';
}

{
    my $numobj = Actium::Time->from_num(1);
    my $strobj = Actium::Time->from_str('0:01');
    cmp_ok $numobj, '==', $strobj,
      'String fetches same object as previously queried number';
}

{
    my $strobj = Actium::Time->from_str('0:02');
    my $numobj = Actium::Time->from_num(2);
    cmp_ok $strobj, '==', $numobj,
      'Number fetches same object as previously queried string';
}

note 'boolean queries';

my $numobj = Actium::Time->from_num(1);

ok $flextime->is_flex, 'is_flex() correct when positive';
ok !$numobj->is_flex,    'is_flex() correct when negative on number';
ok !$intertime->is_flex, 'is_flex() correct when negative on special';

ok $intertime->is_awaiting_interpolation,
  'is_awaiting_interpolation() correct when positive';
ok !$numobj->is_awaiting_interpolation,
  'is_awaiting_interpolation() correct when negative on number';
ok !$flextime->is_awaiting_interpolation,
  'is_awaiting_interpolation() correct when negative on special';

ok $numobj->does_stop,   'does_stop() correct when positive on number';
ok $flextime->does_stop, 'does_stop() correct when positive on special';
ok !$undeftime->does_stop, 'does_stop() correct when negative';

ok $undeftime->no_stop, 'no_stop() correct when positive';
ok !$numobj->no_stop,   'no_stop() correct when negative on number';
ok !$flextime->no_stop, 'no_stop() correct when negative on special';

ok $numobj->has_time, 'no_stop() correct when positive';
ok !$flextime->has_time,  'no_stop() correct when negative on special';
ok !$undeftime->has_time, 'has_time() correct when negative on undef';

$testcount += 15;

note 'tests of predefined formats';

# input    ap   ap_noseparator  apbx  apbx_noseparator
my @predefined_tests = (
    [qw/12:00b  12:00p   1200p  12:00b  1200b/],
    [qw/11:55b  11:55p   1155p  11:55b  1155b/],
    [qw/0:00    12:00a   1200a  12:00a  1200a/],
    [qw/2:32     2:32a    232a   2:32a   232a/],
    [qw/12:00   12:00p   1200p  12:00p  1200p/],
    [qw/15:15    3:15p    315p   3:15p   315p/],
    [qw/24:00   12:00a   1200a  12:00x  1200x/],
    [qw/25:37    1:37a    137a   1:37x   137x/],
);

$testcount += @predefined_tests * $#{ $predefined_tests[0] };

foreach my $test_r (@predefined_tests) {
    my $string = shift @$test_r;
    my $obj    = Actium::Time->from_str($string);
    foreach my $method (qw/ap ap_noseparator apbx apbx_noseparator/) {

        my $expected = shift @$test_r;
        is( $obj->$method, $expected,
            "$method gives correct result on $string" );

    }

}

{

    # test everything except negative separators

    #my @timestrs = (qw/12:00b 11:55b 0:00 2:32 12:00 15:15 24:00 25:37/);

    my @tests = (
        [   '12:00b' =>
              qw/12:00p 1200p 12.00p 12:00b 1200b 12.00b 12:00b 1200b 12.00b
              12:00 1200 12.00 12'00 12'00 12'00/
        ],
        [   '11:55b' =>
              qw/11:55p 1155p 11.55p 11:55b 1155b 11.55b 11:55b 1155b 11.55b
              23:55 2355 23.55 23'55 23'55 23'55/
        ],
        [   '0:00' =>
              qw/12:00a 1200a 12.00a 12:00a 1200a 12.00a 12:00a 1200a 12.00a
              00:00 0000 00.00 00:00 0000 00.00/
        ],
        [   '2:32' => qw/2:32a 232a 2.32a 2:32a 232a 2.32a 2:32a 232a 2.32a
              02:32 0232 02.32 02:32 0232 02.32/
        ],
        [   '12:00' =>
              qw/12:00p 1200p 12.00p 12:00p 1200p 12.00p 12:00p 1200p 12.00p
              12:00 1200 12.00 12:00 1200 12.00/
        ],
        [   '15:15' => qw/3:15p 315p 3.15p 3:15p 315p 3.15p 3:15p 315p 3.15p
              15:15 1515 15.15 15:15 1515 15.15/
        ],
        [   '24:00' =>
              qw/12:00a 1200a 12.00a 12:00x 1200x 12.00x 12:00x 1200x 12.00x
              00:00 0000 00.00 24:00 2400 24.00/
        ],
        [   '25:37' => qw/1:37a 137a 1.37a 1:37x 137x 1.37x 1:37x 137x 1.37x
              01:37 0137 01.37 25:37 2537 25.37/
        ],
    );

    $testcount += @tests;

    for my $test_r (@tests) {
        my $timestr = shift @$test_r;

        my @results;
        my $time = Actium::Time->from_str($timestr);
        for my $format (qw/12ap 12apbx 12apnm 24 24+/) {
            for my $separator ( ':', '', '.' ) {
                push @results,
                  $time->formatted(
                    format    => $format,
                    separator => $separator,
                  );
            }
        }

        is_deeply( \@results, $test_r, "formatted tests with $timestr" );
        #note "['$timestr' => qw/@results/],";
    }
}

#[ '12:00b'   => qw/12'00 12Z00 12'00 12Z00 12'00 12Z00/ ],
#  [ '11:55b' => qw/23'55 23Z55 23'55 23Z55 23'55 23Z55/ ],

{

    # test negative separators

    my @tests
      = ( [ '12:00b' => qw/12'00 12Z00 / ], [ '11:55b' => qw/23'55 23Z55 / ], );

    $testcount += @tests;

    for my $test_r (@tests) {
        my $timestr = shift @$test_r;

        my @results;
        my $time = Actium::Time->from_str($timestr);
        for my $negative_separator ( q{'}, 'Z' ) {
            push @results,
              $time->formatted(
                format             => '24+',
                negative_separator => $negative_separator
              );

        }
        is_deeply( \@results, $test_r,
            "formatted tests with $timestr and varying negative separators" );

        #note "['$timestr' => qw/@results/],";
    }
}

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

