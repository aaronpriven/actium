# Actium/Flagspecs/Main.pm

# Subversion: $Id$

# This is part of a so-far incomplete effort to refactor Flagspecs.

use 5.012;
use warnings;

package Actium::Flagspecs::Main 0.001;

use Actium::Signup;
use Actium::Files::HastusASI;
use Actium::Files::FMPXMLResult;

use Actium::Flagspecs::ProcessPatterns;

use Data::Dumper;

sub START {

    my $signup     = Actium::Signup->new();
    my $flagfolder = $signup->subdir('flags');

    my $xml_db  = load_xml($signup);
    my $hasi_db = load_hasi($signup);

    my ( $stop_obj_of_r, $route_obj_of_r )
      = Actium::Flagspecs::ProcessPatterns::process_patterns( $hasi_db,
        $xml_db );
    say Data::Dumper::Dumper ( \$stop_obj_of_r, \$route_obj_of_r );

    #    build_trip_quantity_lists($hasi_db);
    #
    #    cull_placepats();
#
    #    delete_last_stops();
    #
    #    build_placelist_descriptions();
    #
    #    build_pat_combos();
    #    process_combo_overrides($flagfolder);
    #
    #    build_color_of($signup);
    #
    #    output_specs( $flagfolder, $xml_db );

    return;

} ## tidy end: sub START

sub load_xml {
    my $signup = shift;
    my $xmldir = $signup->subdir('xml');
    my $xml_db = Actium::Files::FMPXMLResult->new( $xmldir->get_dir() );
    $xml_db->ensure_loaded(qw(Stops Timepoints));
    return $xml_db;
}

sub load_hasi {
    my $signup  = shift;
    my $hasidir = $signup->subdir('hasi');
    my $hasi_db = Actium::Files::HastusASI->new( $hasidir->get_dir() );
    $hasi_db->ensure_loaded(qw(PAT TRP));
    return $hasi_db;
}

1;
