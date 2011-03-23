# Actium/Flagspecs/Main.pm

# Subversion: $Id$

use warnings;
use strict;

package Actium::Flagspecs::Main;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Actium::HiddenHash;
use Actium::Signup;
use Actium::Term;
use Actium::Constants;

use Carp;
use Readonly;

sub flagspecs_START {

    my $signup     = Actium::Signup->new();
    my $flagfolder = $signup->subdir('flags');

    my $merges_hh = load_merges($signup);
    my $hasi_db  = load_hasi($signup);

    build_place_and_stop_lists( $hasi_db, $merges_hh->get('Stops') );
    build_trip_quantity_lists($hasi_db);

    cull_placepats();

    delete_last_stops();

    build_placelist_descriptions();

    build_pat_combos();
    process_combo_overrides($flagfolder);

    build_color_of($signup);

    output_specs( $flagfolder, $merges_hh->get('Stops') );

    return;

} ## tidy end: sub flagspecs_START

sub load_merges {
    my $signup = shift;
    my $merges_hh = Actium::Hiddenhash->new();
    foreach my $file (qw/Stops Timepoints/) {
        my $mergedata = $signup->mergeread("$file.csv");
        $merges_hh->set($file => $mergedata);
    }
    return $merges_hh;
}

sub load_hasi {
    my $signup = shift;
    my $hasidir = $signup->subdir('hasi');
    my $hasi_db = Actium::HastusASI::Db->new( $hasidir->get_dir(),
        ( '/tmp/' . $hasidir->get_signup() . '_' ) );
    $hasi_db->load(qw(PAT TRP));
    return $hasi_db;
}




1;
