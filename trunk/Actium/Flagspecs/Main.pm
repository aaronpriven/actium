# Actium/Flagspecs/Main.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Flagspecs::Main 0.001;

use Actium::Signup;
use Actium::Files::HastusASI;
use Actium::Files::FMPXMLResult;

use Carp;
use Readonly;

sub flagspecs_START {

    my $signup     = Actium::Signup->new();
    my $flagfolder = $signup->subdir('flags');

    my $xml_db = load_xml($signup);
    my $hasi_db  = load_hasi($signup);

    build_place_and_stop_lists( $hasi_db, $xml_db );
    build_trip_quantity_lists($hasi_db);

    cull_placepats();

    delete_last_stops();

    build_placelist_descriptions();

    build_pat_combos();
    process_combo_overrides($flagfolder);

    build_color_of($signup);

    output_specs( $flagfolder, $xml_db );

    return;

} ## tidy end: sub flagspecs_START

sub load_xml {
    my $signup = shift;
    my $xmldir = $signup->subdir('xml');
    my $xml_db = Actium::Files::FMPXMLResult->new( $xmldir->get_dir());
    $xml_db->ensure_loaded(qw(Stops Timepoints));
    return $xml_db;
}

sub load_hasi {
    my $signup = shift;
    my $hasidir = $signup->subdir('hasi');
    my $hasi_db = Actium::Files::HastusASI->new( $hasidir->get_dir());
    $hasi_db->ensure_loaded(qw(PAT TRP));
    return $hasi_db;
}




1;
