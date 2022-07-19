use strict;
use warnings;

use Scalar::Util(qw/refaddr/);

use FindBin qw($Bin);
use lib "$Bin/lib";

BEGIN {
    require 'samples.pl';
}

our ( $sample_ref, $sample_obj );

my $sample_test = [
    [ 'Joshua',      29, 'San Mateo',     undef,             'Hannah' ],
    [ 'Christopher', 59, 'New York City', undef,             'Alexis' ],
    [ 'Emily',       25, 'Dallas',        'Aix-en-Provence', 'Michael' ],
    [ 'Nicholas',    -14, ],
    [ 'Madison', 8, 'Vallejo' ],
    [ 'Andrew',  -15, ],
    [ 'Hannah', 38, 'Romita',     undef, 'Joshua', ],
    [ 'Ashley', 57, 'Ray' ],
    [ 'Alexis', 50, 'San Carlos', undef, 'Christopher' ],
    [ 'Joseph', 0,  'San Francisco' ],
];

# $sample_test is the reference to which things are compared

plan( tests => 25 );

##########
# ->clone

a2dcan('clone');

my $clone_from_ref = Array::2D->clone($sample_ref);

is_deeply( $clone_from_ref, $sample_test,
    "Array::2D->clone clones from a reference AoA" );
is_blessed( $clone_from_ref, "Clone from reference AoA" );
isnt( refaddr($clone_from_ref),
    refaddr($sample_ref), 'Clone is not the same reference as reference AoA' );
ok( all_row_refs_are_different( $clone_from_ref, $sample_ref ),
    'No reference in clone is the same as the reference AoA'
);

my $clone_from_obj = $sample_obj->clone();

is_deeply( $clone_from_obj, $sample_test, '$obj->clone clones from an object' );
is_blessed( $clone_from_obj, "Clone from object" );
isnt( refaddr($clone_from_obj),
    refaddr($sample_ref), 'Clone is not the same reference as object' );
ok( all_row_refs_are_different( $clone_from_obj, $sample_ref ),
    'No reference in clone is the same as in the object'
);

##############
# ->unblessed

a2dcan('unblessed');

my $unblessed_from_ref = Array::2D->unblessed($sample_ref);
is_deeply( $unblessed_from_ref, $sample_test,
    'unblessed() from ref returns AoA' );
isnt_blessed( $unblessed_from_ref, "unblessed from reference" );

cmp_ok( $unblessed_from_ref, '==', $sample_ref,
    'Returned same reference when passed unblessed' );

my $unblessed_from_obj = $sample_obj->unblessed();
is_deeply( $unblessed_from_obj, $sample_test, '$obj->unblessed returns AoA' );
isnt_blessed( $unblessed_from_obj, "unblessed from object" );
cmp_ok( $unblessed_from_obj, '!=', $sample_obj,
    'Returned difference reference when passed blessed' );

####################
# ->clone_unblessed

a2dcan('clone_unblessed');

my $unblessedclone_from_ref = Array::2D->clone_unblessed($sample_ref);

is_deeply( $unblessedclone_from_ref, $sample_test,
    "Array::2D->clone clones from a reference AoA" );
isnt_blessed( $unblessedclone_from_ref, "Clone from reference AoA" );
isnt( refaddr($unblessedclone_from_ref),
    refaddr($sample_ref), 'Clone is not the same reference as reference AoA' );
ok( all_row_refs_are_different( $unblessedclone_from_ref, $sample_ref ),
    'No reference in clone is the same as the reference AoA'
);

my $unblessedclone_from_obj = $sample_obj->clone_unblessed();

is_deeply( $unblessedclone_from_obj, $sample_test,
    '$obj->clone_unblessed clones from an object' );
isnt_blessed( $unblessedclone_from_obj, "Unblessed clone from object" );
isnt( refaddr($unblessedclone_from_obj),
    refaddr($sample_ref), 'Clone is not the same reference as object' );
ok( all_row_refs_are_different( $unblessedclone_from_obj, $sample_ref ),
    'No reference in clone is the same as in the object' );

sub all_row_refs_are_different {
    my $aoa  = shift;
    my $aoa2 = shift;
    for my $row_idx ( 0 .. $#{$aoa} ) {
        return 0
          if refaddr( $aoa->[$row_idx] ) == refaddr( $aoa2->[$row_idx] );
    }
    return 1;
}
