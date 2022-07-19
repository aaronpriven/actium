use strict;
use warnings;

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'tabulation.pl';
}

note('Use Unicode::GCString for determining column widths');

if ( eval { require Unicode::GCString; 1 } ) {

    our %tests;

    push @{ $tests{tabulate} },
      ( {   description => 'an array with Unicode decomposed characters',
            test_array  => [
                [ '_11_chars__',      'q' ],
                [ 'solo',             'alone' ],
                [ "so\x{301}lo",      'only' ],
                [ "dieciseis",        'sixteen' ],
                [ "diecise\x{301}is", 'sixteen' ],
            ],
            expected => [
                '_11_chars__ q',
                'solo        alone',
                "so\x{301}lo        only",
                "dieciseis   sixteen",
                "diecise\x{301}is   sixteen",
            ],
        },
        {   description => 'an array with double-wide characters',
            test_array  => [
                [ "\x{4300}", "Chinese character for one", ],
                [ '1',        'Arabic numeral one', ],
                [ 'uno',      'Spanish word for one' ],
            ],
            expected => [
                "\x{4300}  Chinese character for one",
                '1   Arabic numeral one',
                'uno Spanish word for one',
            ],
        },
      );

    push @{ $tests{tabulate_equal_width} },
      ( {   description => 'an array with Unicode decomposed characters',
            test_array  => [
                [ "so\x{301}lo", 'only', 'a' ],
                [qw/solo alone b/],
                [ "diecise\x{301}is", 'sixteen', 'c' ],
            ],
            expected => [
                "so\x{0301}lo      only      a",
                'solo      alone     b',
                "diecise\x{301}is sixteen   c",
            ],
        },
        {   description => 'an array with double-wide characters',
            test_array  => [
                [ "\x{4300}", 'Chinese', 'a' ],
                [ '1',        'Arabic',  'b' ],
                [ 'uno',      'Spanish', 'c' ],
            ],
            expected => [
                "\x{4300}      Chinese a",
                , '1       Arabic  b',
                , 'uno     Spanish c',
            ],
        },
      );

    our $separator_width_list;

    our @term_width_tests;
    push @term_width_tests,
      { list           => [ "\x{4300}", '123456789', qw/three four five six/ ],
        expected_array => [
            [ "\x{4300}", 'four', ], [ '123456789', 'five' ], [qw/three six/],
        ],
        expected_tabulated =>
          [ "\x{4300}        four", '123456789 five', 'three     six' ],
        description => 'with double-wide character',
        width       => 20,
      },
      { list => [ "so\x{0301}lo", '123456789', qw/three four five six/ ],
        expected_array => [
            [ "so\x{0301}lo", 'four', ],
            [ '123456789',    'five' ],
            [qw/three six/],
        ],
        expected_tabulated =>
          [ "so\x{0301}lo      four", '123456789 five', 'three     six' ],
        description => 'with Unicode decomposed character',
        width       => 20,

      },
      { description    => 'with one-width decomposed separator',
        list           => $separator_width_list,
        width          => 19,
        expected_array => [
            [qw/a   ddd ggg jjj mmm/], [qw/bbb eee hhh k/],
            [qw/ccc fff iii lll/],
        ],
        expected_tabulated => [
            "a  o\x{301}dddo\x{301}gggo\x{301}jjjo\x{301}mmm",
            "bbbo\x{301}eeeo\x{301}hhho\x{301}k",
            "ccco\x{301}fffo\x{301}iiio\x{301}lll",
        ],
        separator => "o\x{301}",
      },
      { description    => 'with Asian full-width character separator',
        list           => $separator_width_list,
        separator      => "\x{4300}",
        width          => 19,
        expected_array => [
            [qw/a   eee iii mmm/], [qw/bbb fff jjj/],
            [qw/ccc ggg k/],       [qw/ddd hhh lll/],
        ],
        expected_tabulated => [
            "a  \x{4300}eee\x{4300}iii\x{4300}mmm",
            "bbb\x{4300}fff\x{4300}jjj",
            "ccc\x{4300}ggg\x{4300}k",
            "ddd\x{4300}hhh\x{4300}lll",
        ],
      };

    run_tabulation_tests();

} ## tidy end: if ( eval { require Unicode::GCString...})
else {
    plan skip_all => 'Unicode::GCString not available';
    done_testing;
}
