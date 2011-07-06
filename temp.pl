#!/ActivePerl/bin/perl

use strict;
use 5.012;

use FindBin qw($Bin);
use lib $Bin;

use Actium::Options ('init_options');

use Actium::Signup;

use Actium::Sked;

init_options;

my $skedsfolder = Actium::Signup->new(
    {   base       => '/Users/aaron/Dev/signups/',
        signup     => 'sp11',
        subfolders => 'skeds',
        cache => '/tmp/apriven/',
    }
);

my @skedobjs = Actium::Sked->load_prehistorics( $skedsfolder, undef , '3*' );

use Data::Dumper;

open my $outfh, '>', '/tmp/dumpy.txt' or die $!;

foreach my $object ( @skedobjs ) {

    my $id = "OBJ_" . $object->id;

    say $outfh Data::Dumper->Dump( [ \$object ], [$id] );


}

close $outfh;

