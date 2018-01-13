
use strict;
use Test::More 0.98;

BEGIN {
    note "These are tests of Actium::Storage::File.";
    use_ok 'Actium::Storage::File';
}

isa_ok( 'Actium::Storage::File', 'Path::Class::File' );

done_testing;
