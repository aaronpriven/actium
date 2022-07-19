use strict;
use warnings;
use utf8;
use Test::More 0.98;
use Array::2D;

BEGIN {
    require 'testutil.pl';
}

my $tab_test = [
    [qw/one two three four/],     [qw/five six seven eight/],
    [qw/nine ten eleven twelve/], [qw/thirteen 14 fifteen/],
];

our %tests = (
    tabulate => [
        {   description => 'an array',
            expected    => [
                'one      two three   four',
                'five     six seven   eight',
                'nine     ten eleven  twelve',
                'thirteen 14  fifteen',
            ],
        },
        {   description => 'an array (with separator)',
            expected    => [
                'one     |two|three  |four',
                'five    |six|seven  |eight',
                'nine    |ten|eleven |twelve',
                'thirteen|14 |fifteen',
            ],
            arguments => '|',
        },
        {   description => 'an array with empty strings',
            test_array  => [
                [ qw/one two/, '', 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, '' ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                'one      two         four',
                'five     six seven   eight',
                'nine     ten eleven',
                'thirteen 14  fifteen',
            ],
        },
        {   description => 'an array with undefined values',
            test_array  => [
                [ qw/one two/, undef, 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                'one      two         four',
                'five     six seven   eight',
                'nine     ten eleven',
                'thirteen 14  fifteen',
            ],
        },
        {   description => 'a ragged array',
            test_array  => [
                [ undef, qw/two three four/ ], [qw/five six seven/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen/],
            ],
            expected => [
                '         two three  four',
                'five     six seven',
                'nine     ten eleven',
                'thirteen',
            ],
        },
        {   description => 'a one-column array',
            test_array  => [ ['one'], ['five'], ['nine'], ['thirteen'], ],
            expected => [ 'one', 'five', 'nine', 'thirteen', ],
        },
        {   description => 'a one-row array',
            test_array  => [ [qw/one two three four/] ],
            expected    => ['one two three four'],
        },
        {   description => 'an empty array',
            test_array  => [ [] ],
            expected    => [],
        },

        {   description => 'an array with an empty row',
            test_array  => [
                [qw/one two three/],   [],
                [qw/nine ten eleven/], [qw/thirteen fourteen fifteen/],
            ],
            expected => [
                'one      two      three',
                'nine     ten      eleven',
                'thirteen fourteen fifteen',
            ],
        },
        {   description => 'an array with an empty column',
            test_array  => [
                [ qw/one two/,  '',    'four' ],
                [ qw/five six/, undef, 'eight' ],
                [ qw/nine ten/, '',    'twelve' ],
                [qw/thirteen fourteen/],
            ],
            expected => [
                'one      two      four',
                'five     six      eight',
                'nine     ten      twelve',
                'thirteen fourteen',
            ],
        },
    ],
    tabulate_equal_width => [
        {   description => 'an array',
            expected    => [
                'one      two      three    four',
                'five     six      seven    eight',
                'nine     ten      eleven   twelve',
                'thirteen 14       fifteen',
            ],
        },
        {   description => 'an array (with arguments)',
            expected    => [
                'one     |two     |three   |four',
                'five    |six     |seven   |eight',
                'nine    |ten     |eleven  |twelve',
                'thirteen|14      |fifteen',
            ],
            arguments => '|',
        },
        {   description => 'an array with empty strings',
            test_array  => [
                [ qw/one two/, '', 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, '' ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                'one      two               four',
                'five     six      seven    eight',
                'nine     ten      eleven',
                'thirteen 14       fifteen',
            ],
        },
        {   description => 'an array with undefined values',
            test_array  => [
                [ qw/one two/, undef, 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                'one      two               four',
                'five     six      seven    eight',
                'nine     ten      eleven',
                'thirteen 14       fifteen',
            ],
        },
        {   description => 'a ragged array',
            test_array  => [
                [ undef, qw/two three four/ ], [qw/five six seven/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen/],
            ],
            expected => [
                '         two      three    four',
                'five     six      seven',
                'nine     ten      eleven',
                'thirteen',
            ],
        },
        {   description => 'a one-column array',
            test_array  => [ ['one'], ['five'], ['nine'], ['thirteen'], ],
            expected => [ 'one', 'five', 'nine', 'thirteen', ],
        },
        {   description => 'a one-row array',
            test_array  => [ [qw/one two three four/] ],
            expected    => ['one   two   three four'],
        },
        {   description => 'an empty array',
            test_array  => [ [] ],
            expected    => [],
        },

        {   description => 'an array with an empty row',
            test_array  => [
                [qw/one two three/],   [],
                [qw/nine ten eleven/], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                'one      two      three',
                'nine     ten      eleven',
                'thirteen 14       fifteen',
            ],
        },
        {   description => 'an array with an empty column',
            test_array  => [
                [ qw/one two/,  '',    'four' ],
                [ qw/five six/, undef, 'eight' ],
                [ qw/nine ten/, '',    'twelve' ],
                [qw/thirteen 14/],
            ],
            expected => [
                'one      two      four',
                'five     six      eight',
                'nine     ten      twelve',
                'thirteen 14',
            ],
        },
    ],
    tsv_lines => [
        {   description => 'an array',
            expected    => [
                "one\ttwo\tthree\tfour",     "five\tsix\tseven\teight",
                "nine\tten\televen\ttwelve", "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'an array (with headers)',
            arguments   => [qw/Spring Summer Fall Winter/],
            expected    => [
                "Spring\tSummer\tFall\tWinter", "one\ttwo\tthree\tfour",
                "five\tsix\tseven\teight",      "nine\tten\televen\ttwelve",
                "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'an array with empty strings',
            test_array  => [
                [ qw/one two/, '', 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, '' ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                "one\ttwo\t\tfour",  "five\tsix\tseven\teight",
                "nine\tten\televen", "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'an array with undefined values',
            test_array  => [
                [ qw/one two/, undef, 'four' ], [qw/five six seven eight/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                "one\ttwo\t\tfour",  "five\tsix\tseven\teight",
                "nine\tten\televen", "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'a ragged array',
            test_array  => [
                [ undef, qw/two three four/ ], [qw/five six seven/],
                [ qw/nine ten eleven/, undef ], [qw/thirteen/],
            ],
            expected => [
                "\ttwo\tthree\tfour", "five\tsix\tseven",
                "nine\tten\televen",  "thirteen",
            ],
        },
        {   description => 'a one-column array',
            test_array  => [ ['one'], ['five'], ['nine'], ['thirteen'], ],
            expected => [ 'one', 'five', 'nine', 'thirteen', ],
        },
        {   description => 'a one-row array',
            test_array  => [ [qw/one two three four/] ],
            expected    => ["one\ttwo\tthree\tfour"],
        },
        {   description => 'an empty array',
            test_array  => [ [] ],
            expected    => [''],
        },
        {   description => 'an empty array, with headers',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [ [] ],
            expected    => [ "Spring\tSummer\tFall\tWinter", '' ],
        },
        {   description => 'an array with an empty row',
            test_array  => [
                [qw/one two three/],   [],
                [qw/nine ten eleven/], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                "one\ttwo\tthree",   '',
                "nine\tten\televen", "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'an array with an empty row, with headers',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [
                [qw/one two three/],   [],
                [qw/nine ten eleven/], [qw/thirteen 14 fifteen/],
            ],
            expected => [
                "Spring\tSummer\tFall\tWinter", "one\ttwo\tthree",
                '',                             "nine\tten\televen",
                "thirteen\t14\tfifteen",
            ],
        },
        {   description => 'an array with an empty column',
            test_array  => [
                [ qw/one two/,  '',    'four' ],
                [ qw/five six/, undef, 'eight' ],
                [ qw/nine ten/, '',    'twelve' ],
                [qw/thirteen 14/],
            ],
            expected => [
                "one\ttwo\t\tfour",    "five\tsix\t\teight",
                "nine\tten\t\ttwelve", "thirteen\t14",
            ],
        },
        {   description => 'an array with an empty column and headers',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [
                [ qw/one two/,  '',    'four' ],
                [ qw/five six/, undef, 'eight' ],
                [ qw/nine ten/, '',    'twelve' ],
                [qw/thirteen 14/],
            ],
            expected => [
                "Spring\tSummer\tFall\tWinter", "one\ttwo\t\tfour",
                "five\tsix\t\teight",           "nine\tten\t\ttwelve",
                "thirteen\t14",
            ],
        },
        {   description => 'embedded tab in body',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [ [ qw/one two/, "thr\tee", 'four' ], ],
            warning     => qr/Tab character found/,
            expected    => [
                "Spring\tSummer\tFall\tWinter",
                "one\ttwo\tthr\x{FFFD}ee\tfour",
            ],
        },
        {   description => 'two embedded tabs in body',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [ [ qw/one two/, "thr\tee", "f\tour" ], ],
            warning     => qr/Tab character found/,
            expected    => [
                "Spring\tSummer\tFall\tWinter",
                "one\ttwo\tthr\x{FFFD}ee\tf\x{FFFD}our",
            ],
        },
        {   description => 'embedded tab in header',
            arguments   => [ qw/Spring Summer/, "Fa\tll", 'Winter' ],
            test_array  => [ [ qw/one two/, "three", 'four' ], ],
            warning     => qr/Tab character found/,
            expected    => [
                "Spring\tSummer\tFa\x{FFFD}ll\tWinter",
                "one\ttwo\tthree\tfour",
            ],
        },
    ],
    tsv => [
        {   description => 'embedded line feed in body',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [ [ qw/one two/, "thr\nee", 'four' ], ],
            warning     => qr/Line feed character found/,
            expected =>
              "Spring\tSummer\tFall\tWinter\none\ttwo\tthr\x{FFFD}ee\tfour\n",
        },
        {   description => 'two embedded line feeds in body',
            arguments   => [qw/Spring Summer Fall Winter/],
            test_array  => [ [ qw/one two/, "thr\nee", "f\nour" ], ],
            warning     => qr/Line feed character found/,
            expected    => "Spring\tSummer\tFall\tWinter\n"
              . "one\ttwo\tthr\x{FFFD}ee\tf\x{FFFD}our\n",
        },
        {   description => 'embedded line feed in header',
            arguments   => [ qw/Spring Summer/, "Fa\nll", 'Winter' ],
            test_array  => [ [ qw/one two/, "three", 'four' ], ],
            warning     => qr/Line feed character found/,
            expected =>
              "Spring\tSummer\tFa\x{FFFD}ll\tWinter\none\ttwo\tthree\tfour\n",
        },
    ],

);

my %defaults = (
    tsv       => { test_procedure => 'results', test_array => $tab_test, },
    tsv_lines => {
        test_procedure => 'results',
        returns_a_list => 1,
        test_array     => $tab_test,
    },
    tabulate => { test_procedure => 'results', test_array => $tab_test, },
    tabulate_equal_width =>
      { test_procedure => 'results', test_array => $tab_test, },
    tabulated => {
        test_procedure => 'results',
        test_array     => $tab_test,
    },
);

my @term_width_list = (
    qw/addfields avl2patdest avl2points avl2stoplines avl2stoplists
      bags2 bartskeds citiesbyline compareskeds comparestops
      dbexport decalcompare decalcount decallabels flagspecs
      htmltables iphoto_stops linedescrip linesbycity
      makepoints matrix mr_copy mr_import newsignup orderbytravel
      prepareflags slists2html ss stops2kml stopsofline storeavl
      tabskeds timetables xhea2skeds zipcodes zipdecals/
);

my $term_width_ref = [
    [qw/addfields     compareskeds  iphoto_stops  orderbytravel timetables/],
    [qw/avl2patdest   comparestops  linedescrip   prepareflags  xhea2skeds/],
    [qw/avl2points    dbexport      linesbycity   slists2html   zipcodes/],
    [qw/avl2stoplines decalcompare  makepoints    ss            zipdecals/],
    [qw/avl2stoplists decalcount    matrix        stops2kml/],
    [qw/bags2         decallabels   mr_copy       stopsofline/],
    [qw/bartskeds     flagspecs     mr_import     storeavl/],
    [qw/citiesbyline  htmltables    newsignup     tabskeds/],
];

our $separator_width_list
  = [qw/a bbb ccc ddd eee fff ggg hhh iii jjj k lll mmm/];

our @term_width_tests = (
    {   description        => 'made new',
        expected_tabulated => [
"addfields     compareskeds  iphoto_stops  orderbytravel timetables",
"avl2patdest   comparestops  linedescrip   prepareflags  xhea2skeds",
            "avl2points    dbexport      linesbycity   slists2html   zipcodes",
            "avl2stoplines decalcompare  makepoints    ss            zipdecals",
            "avl2stoplists decalcount    matrix        stops2kml",
            "bags2         decallabels   mr_copy       stopsofline",
            "bartskeds     flagspecs     mr_import     storeavl",
            "citiesbyline  htmltables    newsignup     tabskeds",
        ]
    },
    {   description        => 'made new, width 60',
        expected_tabulated => [
            'addfields     comparestops  linesbycity   ss',
            'avl2patdest   dbexport      makepoints    stops2kml',
            'avl2points    decalcompare  matrix        stopsofline',
            'avl2stoplines decalcount    mr_copy       storeavl',
            'avl2stoplists decallabels   mr_import     tabskeds',
            'bags2         flagspecs     newsignup     timetables',
            'bartskeds     htmltables    orderbytravel xhea2skeds',
            'citiesbyline  iphoto_stops  prepareflags  zipcodes',
            'compareskeds  linedescrip   slists2html   zipdecals'
        ],
        expected_array => [
            [ 'addfields',     'comparestops', 'linesbycity',   'ss' ],
            [ 'avl2patdest',   'dbexport',     'makepoints',    'stops2kml' ],
            [ 'avl2points',    'decalcompare', 'matrix',        'stopsofline' ],
            [ 'avl2stoplines', 'decalcount',   'mr_copy',       'storeavl' ],
            [ 'avl2stoplists', 'decallabels',  'mr_import',     'tabskeds' ],
            [ 'bags2',         'flagspecs',    'newsignup',     'timetables' ],
            [ 'bartskeds',     'htmltables',   'orderbytravel', 'xhea2skeds' ],
            [ 'citiesbyline',  'iphoto_stops', 'prepareflags',  'zipcodes' ],
            [ 'compareskeds',  'linedescrip',  'slists2html',   'zipdecals' ],
        ],
        width => 60,
    },
    {   description        => 'made new with separator',
        separator          => '|',
        expected_tabulated => [
"addfields    |compareskeds |iphoto_stops |orderbytravel|timetables",
"avl2patdest  |comparestops |linedescrip  |prepareflags |xhea2skeds",
            "avl2points   |dbexport     |linesbycity  |slists2html  |zipcodes",
            "avl2stoplines|decalcompare |makepoints   |ss           |zipdecals",
            "avl2stoplists|decalcount   |matrix       |stops2kml",
            "bags2        |decallabels  |mr_copy      |stopsofline",
            "bartskeds    |flagspecs    |mr_import    |storeavl",
            "citiesbyline |htmltables   |newsignup    |tabskeds",
        ]
    },

    {   description    => 'with one-width separator',
        list           => $separator_width_list,
        width          => 19,
        expected_array => [
            [qw/a   ddd ggg jjj mmm/], [qw/bbb eee hhh k/],
            [qw/ccc fff iii lll/],
        ],
        expected_tabulated =>
          [ 'a   ddd ggg jjj mmm', 'bbb eee hhh k', 'ccc fff iii lll', ],

    },
    {   description    => 'with two-width separator',
        list           => $separator_width_list,
        separator      => '--',
        width          => 19,
        expected_array => [
            [qw/a   eee iii mmm/], [qw/bbb fff jjj/],
            [qw/ccc ggg k  /],     [qw/ddd hhh lll/],
        ],
        expected_tabulated => [
            'a  --eee--iii--mmm', 'bbb--fff--jjj',
            'ccc--ggg--k',        'ddd--hhh--lll',
        ],
    },
    {   description => 'with zero-width separator',
        separator   => '',
        width       => 19,
        list        => [qw/a bbb ccc ddd eee fff ggg hhh iii jjj k lll/],
        expected_array =>
          [ [qw/a   ccc eee ggg iii k/], [qw/bbb ddd fff hhh jjj lll/], ],
        expected_tabulated => [ 'a  ccceeegggiiik', 'bbbdddfffhhhjjjlll', ],
    },
);

sub run_tabulation_tests {

    # So the idea is that when this module is loaded, it will set the
    # %tests and @term_width_tests variables. The loading module
    # can then add whatever tests it feels are appropriate.
    # Finally, the loading module runs run_tabulation_tests to carry
    # out the tests.

    # generate tests of tabulated() from tests of tabulate(),
    # and tests of tsv() from tests of tsv_lines()

    my %to_add_lf = ( tsv_lines => 'tsv', tabulate => 'tabulated' );

    foreach my $no_lf_method ( keys %to_add_lf ) {
        my $lf_method = $to_add_lf{$no_lf_method};
        my @tests;

        foreach my $test_r ( @{ $tests{$no_lf_method} } ) {
            my %lf_test = %{$test_r};
            $lf_test{expected}
              = join( "\n", @{ $lf_test{expected} } ) . "\n";
            push @tests, \%lf_test;
        }
        push @tests, @{ $tests{$lf_method} }
          if $tests{$lf_method};
        $tests{$lf_method} = \@tests;

    }

    # generic tests expects a list of tests in order, not an
    # unordered hash. Generate that list

    my @generic_tests;
    foreach
      my $method (qw/tabulate tabulate_equal_width tabulated tsv tsv_lines/)
    {
        push @generic_tests, $method, $tests{$method};
    }

    # get test count and run generic tests

    my $test_count = generic_test_count( \@generic_tests, \%defaults );

    $test_count += ( 3 * scalar @term_width_tests ) + 1;
    # three tests for each new_to_term_width test
    # ( returned tabulation, returned array, array is blessed)
    # plus one for a2dcan('new_to_term_width');

    plan( tests => $test_count );

    run_generic_tests( \@generic_tests, \%defaults );

    # do non-generic new_to_term_width() tests

    a2dcan('new_to_term_width');

    for my $test_r (@term_width_tests) {

        my $expected_array     = $test_r->{expected_array} // $term_width_ref;
        my $expected_tabulated = $test_r->{expected_tabulated};
        my $description        = $test_r->{description};
        my %params;
        $params{array} = $test_r->{list} // [@term_width_list];
        $params{width} = $test_r->{width}
          if defined $test_r->{width};
        $params{separator} = $test_r->{separator}
          if defined $test_r->{separator};

        my ( $array2d_result, $tabulated_result )
          = Array::2D->new_to_term_width(%params);
        is_deeply( $array2d_result, $expected_array,
            "new from term width: $description: got correct object" );

        #note explain $array2d_result;
        is_blessed($array2d_result);
        is_deeply( $tabulated_result, $expected_tabulated,
            "new_from_term_width: $description: got correct tabulation" );
        #note explain $tabulated_result;

    } ## tidy end: for my $test_r (@term_width_tests)

    done_testing;

} ## tidy end: sub run_tabulation_tests

1;
