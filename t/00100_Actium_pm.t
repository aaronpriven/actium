use strict;
use Test::More 0.98 tests => 107;

BEGIN {
    note "These are tests for constants and functions in Actium.pm.";
    use_ok 'Actium';
}

ok( __PACKAGE__->can('env'), 'module should export env()' );

is( $SPACE, ' ',    '$SPACE is exported' );
is( $EMPTY, '',     '$EMPTY is exported' );
is( $CRLF,  "\r\n", '$CRLF is exported' );

# add tests for imported functions

my @joinlists = (
    {   list      => ['a'],
        msg       => 'one string',
        joincomma => 'a',
        joinempty => 'a',
        joinlf    => 'a',
        jointab   => 'a'
    },
    {   list      => [qw/a b/],
        msg       => 'two strings',
        joincomma => 'a and b',
        joinempty => 'ab',
        joinlf    => "a\nb",
        jointab   => "a\tb"
    },
    {   list      => [qw/a b c/],
        msg       => 'three strings',
        joincomma => 'a, b and c',
        joinempty => 'abc',
        joinlf    => "a\nb\nc",
        jointab   => "a\tb\tc"
    },
    {   list      => [qw/a b c d/],
        msg       => 'four strings',
        joincomma => 'a, b, c and d',
        joinempty => 'abcd',
        joinlf    => "a\nb\nc\nd",
        jointab   => "a\tb\tc\td"
    },
    {   list      => [ 'a', undef, 'c', ],
        msg       => 'two strings and an undef',
        joincomma => undef,
        joinempty => 'ac',
        joinlf    => "a\n\nc",
        jointab   => "a\t\tc"
    },
);

for my $function (qw/joincomma joinempty joinlf jointab/) {
    note $function;
    for my $join_of_r (@joinlists) {
        my @list     = @{ $join_of_r->{list} };
        my $expected = $join_of_r->{$function};
        next unless defined $expected;
        no strict 'refs';
        is( &{ 'Actium::' . $function }(@list),
            $expected, "$function: " . $join_of_r->{msg} );
    }
}

note 'joinseries';

my @items = ( items => [qw/a b c d/] );

is( Actium::joinseries(@items),
    'a, b, c and d',
    'joinseries: four strings with defaults'
);

is( Actium::joinseries( @items, conjunction => 'or' ),
    'a, b, c or d', 'joinseries: four strings with custom conjunction' );

is( Actium::joinseries( @items, oxford => 1 ),
    'a, b, c, and d',
    'joinseries: four strings with oxford'
);

is( Actium::joinseries( @items, separator => ';' ),
    'a; b; c; and d',
    'joinseries: four strings with different separator'
);

is( Actium::joinseries( @items, separator => ';', oxford => 0 ),
    'a; b; c and d',
    'joinseries: four strings with different separator but no oxford'
);

note 'all_eq';

ok( Actium::all_eq(qw/a a a/),        "all_eq: three identical values" );
ok( not( Actium::all_eq(qw/a b c/) ), "all_eq: three non-identical values" );

note 'folded_in';

ok( Actium::folded_in( 'b', qw/a b c/ ),
    'folded_in: lc found when lc searched'
);
ok( Actium::folded_in( 'b', qw/a B c/ ),
    'folded_in: uc found when lc searched'
);
ok( Actium::folded_in( 'B', qw/a b c/ ),
    'folded_in: lc found when uc searched'
);
ok( Actium::folded_in( 'B', qw/a B c/ ),
    'folded_in: uc found when uc searched'
);
ok( not( Actium::folded_in( 'd', qw/a b c/ ) ),
    'folded_in: correctly identified non-element'
);

note 'in';
ok( Actium::folded_in( 'b', qw/a b c/ ), 'in: element found' );
ok( not( Actium::folded_in( 'd', qw/a b c/ ) ),
    'in: correctly identified non-element'
);

note 'linekeys';

is( Actium::linekeys('a'),    'A',          'single lc letter' );
is( Actium::linekeys('B'),    'B',          'single uc letter' );
is( Actium::linekeys('C1'),   "C\x{0}11",   'letter and digit' );
is( Actium::linekeys('2D'),   "12\x{0}D",   'digit and letter' );
is( Actium::linekeys('E99'),  "E\x{0}299",  'letter and 2 digits' );
is( Actium::linekeys('25F'),  "225\x{0}F",  '2 digits and letter' );
is( Actium::linekeys('G307'), "G\x{0}3307", 'letter and 3 digits' );
is( Actium::linekeys('560H'), "3560\x{0}H", '3 digits and letter' );
is( Actium::linekeys('JK44'), "JK\x{0}244", '2 letters and 2 digits' );
is( Actium::linekeys('90LM'), "290\x{0}LM", '2 digits and 2 letters' );
is( Actium::linekeys('JK44'), "JK\x{0}244", '2 letters and 2 digits' );
is( Actium::linekeys('90LM'), "290\x{0}LM", '2 digits and 2 letters' );
is( Actium::linekeys('0077NP'),
    "277\x{0}NP", 'leading zeroes, 2 digits and 2 letters' );
is( Actium::linekeys('QR0043'),
    "QR\x{0}243", '2 letters, leading zeroes and 2 digits' );
is( Actium::linekeys('S5T'), "S\x{0}15\x{0}T",  'letter, number, letter' );
is( Actium::linekeys('6U7'), "16\x{0}U\x{0}17", 'number, letter, number' );
is( Actium::linekeys('1234567890'), "911234567890", '10-digit number' );
is( Actium::linekeys('12345678901234567890'),
    "99212345678901234567890", '20-digit number' );

note 'byline';

cmp_ok( Actium::byline( 'A', 'A' ), '==', 0,  'equal letters are equal' );
cmp_ok( Actium::byline( 'A', 'B' ), '==', -1, 'letter le letter' );
cmp_ok( Actium::byline( 'D', 'C' ), '==', 1,  'letter ge letter' );
cmp_ok( Actium::byline( '2', 'F' ), '==', -1, 'number le letter' );
cmp_ok( Actium::byline( 'E', '1' ), '==', 1,  'letter ge number' );
cmp_ok( Actium::byline( 'NX', 'P' ),
    '==', -1, 'earlier two-letters le later letter' );
cmp_ok( Actium::byline( '11', '9' ),
    '==', 1, 'earlier two-digits ge later digit' );
cmp_ok( Actium::byline( 'B1', 'BB' ), '==', -1,
    'letter-number le two letters' );
cmp_ok( Actium::byline( '4C', '33' ), '==', -1, 'letter-number le two digits' );

note 'sortbyline';

is_deeply(
    [ Actium::sortbyline(qw(N N1 NA NA1 1 1R 10 2 20 200 20A )) ],
    [qw/1 1R 2 10 20 20A 200 N N1 NA NA1/],
    'sortbyline sorts list of lines correctly'
);

note 'u_columns';

cmp_ok( Actium::u_columns('a'), '==', 1, 'halfwidth character has one column' );
cmp_ok( Actium::u_columns('BC'), '==', 2,
    '2 halfwidth characters have two columns' );
cmp_ok( Actium::u_columns("\x{FF21}"),
    '==', 2, '1 fullwidth character has two columns' );
cmp_ok( Actium::u_columns("B\x{FF23}"),
    '==', 3, '1 full and 1 halfwidth character has three columns' );
cmp_ok(
    Actium::u_columns(
        "\x{006B}\x{0301}\x{0075}\x{032D}\x{006F}\x{0304}\x{0301}\x{006E}"),
    '==', 4,
    'composed characters count correctly'
);

note 'u_pad';

is( Actium::u_pad( text => 'x', width => 2 ),
    'x ', 'Pad one halfwidth character' );
is( Actium::u_pad( text => "\x{FF24}", width => 4 ),
    "\x{FF24}  ", 'Pad one fullwidth character' );

note 'u_wrap';

my $text
  = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

my $lines_defaults_r = [
'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor',
'incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis',
'nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
'Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu',
'fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in',
    'culpa qui officia deserunt mollit anim id est laborum.',
];

my $lines_scalar = join( "\n", @{$lines_defaults_r} );

my $lines_50w_r = [
    'Lorem ipsum dolor sit amet, consectetur adipiscing',
    'elit, sed do eiusmod tempor incididunt ut labore',
    'et dolore magna aliqua. Ut enim ad minim veniam,',
    'quis nostrud exercitation ullamco laboris nisi ut',
    'aliquip ex ea commodo consequat. Duis aute irure',
    'dolor in reprehenderit in voluptate velit esse',
    'cillum dolore eu fugiat nulla pariatur. Excepteur',
    'sint occaecat cupidatat non proident, sunt in',
    'culpa qui officia deserunt mollit anim id est',
    'laborum.'
];

#<<<
my $lines_indent_r = [
    '     Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod',
    'tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam,',
    'quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo',
    'consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse',
    'cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non',
    'proident, sunt in culpa qui officia deserunt mollit anim id est laborum.',
];

my $lines_hanging_r = [
    'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor',
    '     incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis',
    '     nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo',
    '     consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse',
    '     cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat',
    '     non proident, sunt in culpa qui officia deserunt mollit anim id est',
    '     laborum.',
];
#>>>

is_deeply( [ Actium::u_wrap($text) ],
    $lines_defaults_r, 'Wraps at default characters' );
is( scalar Actium::u_wrap($text), $lines_scalar, 'Wraps and returns a scalar' );
is_deeply( [ Actium::u_wrap( $text, max_columns => 50 ) ],
    $lines_50w_r, 'Wraps at specified maximum characters' );

is_deeply( [ Actium::u_wrap( $text, indent => 5, addspace => 1 ) ],
    $lines_indent_r, 'Wraps with positive indent and space' );

is_deeply(
    [ Actium::u_wrap( $text, max_columns => 74, indent => -5, addspace => 1 ) ],
    $lines_hanging_r,
    'Wraps with negative indent and space'
);

my $multiline = "
    Lorem ipsum dolor sit amet, consectetur adipiscing elit.
Vestibulum varius libero nec emitus. Mauris eget ipsum eget quam sodales ornare. Suspendisse nec nibh. Duis lobortis mi at augue. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas.
";

#<<<
my $multiline_lines = [
    '',
    '    Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
    'Vestibulum varius libero nec emitus. Mauris eget ipsum eget quam sodales',
    'ornare. Suspendisse nec nibh. Duis lobortis mi at augue. Pellentesque habitant',
    'morbi tristique senectus et netus et malesuada fames ac turpis egestas.',
];
#>>>

is_deeply( [ Actium::u_wrap($multiline) ],
    $multiline_lines, 'Multiple lines wrap' );

exit;

note 'u_trim_to_columns';

is( Actium::u_trim_to_columns( columns => 4, string => 'abcde' ),
    'abcd', 'Trims regular characters correctly' );

my $two_full = "\x{FF24}\x{FF25}";
is( Actium::u_trim_to_columns( columns => 2, string => $two_full ),
    "\x{FF24}", 'Trims full-width characters correctly' );

is( Actium::u_trim_to_columns( columns => 3, string => $two_full ),
    "\x{FF24}",
    'Trims full-width characters correctly when a column left over' );

is( Actium::u_trim_to_columns(
        string =>
          "\x{006B}\x{0301}\x{0075}\x{032D}\x{006F}\x{0304}\x{0301}\x{006E}",
        columns => 2
    ),
    "\x{006B}\x{0301}\x{0075}\x{032D}",
    'Trims decomposed characters correctly'
);

note 'define';

is_deeply(
    [ Actium::define( 'a', undef, 'b' ) ],
    [ 'a', '', 'b' ],
    'defines undefined values correctly'
);

note 'feq';

ok( Actium::feq( 'a', 'a' ), 'feq: lc equal to lc' );
ok( Actium::feq( 'B', 'b' ), 'feq: uc equal to lc' );
ok( Actium::feq( 'c', 'C' ), 'feq: lc equal to uc' );
ok( Actium::feq( 'D', 'D' ), 'feq: uc equal to uc' );
ok( not( Actium::feq( 'e', 'F' ) ), 'feq: different things are different' );

note 'fne';

ok( not( Actium::fne( 'a', 'a' ) ), 'fne: lc equal to lc' );
ok( not( Actium::fne( 'B', 'b' ) ), 'fne: uc equal to lc' );
ok( not( Actium::fne( 'c', 'C' ) ), 'fne: lc equal to uc' );
ok( not( Actium::fne( 'D', 'D' ) ), 'fne: uc equal to uc' );
ok( Actium::fne( 'e', 'F' ), 'fne: different things are different' );

note 'display_percent';

is( Actium::display_percent(0.4),    "40%",  'correct whole decimal' );
is( Actium::display_percent(0.03),   "3%",   'correct single-digit decimal' );
is( Actium::display_percent(0.252),  "25%",  'correct decimal rounded down' );
is( Actium::display_percent(0.388),  "39%",  'correct decimal rounded up' );
is( Actium::display_percent(-0.72),  "-72%", 'correct negative decimal' );
is( Actium::display_percent(1.8383), "184%", 'correct decimal over 100%' );
is( Actium::display_percent( 40, 100 ), "40%", 'correct number and total' );
is( Actium::display_percent( 273, 50 ),
    "546%", 'correct number and total over 100%' );

note 'hashref';

my %sample = ( a => 1, b => 2 );

is_deeply( Actium::hashref(%sample),
    \%sample, 'hashref: result of hash is correct' );
is_deeply( Actium::hashref( \%sample ),
    \%sample, 'hashref: result of hashref is correct' );

note 'dumpstr';

my %samplehash   = ( x => 1, b => 15 );
my @samplearray  = qw/one two three/;
my $samplescalar = "z";

my $hashstr   = Actium::dumpstr(%samplehash);
my $arraystr  = Actium::dumpstr(@samplearray);
my $scalarstr = Actium::dumpstr($samplescalar);

my $hashstr_test = q|{
    b => 15,
    x => 1
}|;

my $arraystr_test = q|[
    [0] "one",
    [1] "two",
    [2] "three"
]|;

my $scalarstr_test = q|"z"|;

is( $hashstr,   $hashstr_test,   'Correct hash string' );
is( $arraystr,  $arraystr_test,  'Correct array string' );
is( $scalarstr, $scalarstr_test, 'Correct scalar string' );

done_testing;

__END__

=head1 COPYRIGHT & LICENSE

Copyright 2018

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

