# /Actium/Cmd/XheaImport.pm
#
# Takes XML files exported from Hastus and imports them

# Subversion: $Id$

package Actium::Cmd::XheaImport 0.004;

use Actium::Preamble;
use Actium::Files::Xhea;
use Actium::Import::CalculateFields;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

const my $STOPS     => 'stop';
const my $STOPS_PC  => 'stop_with_i';
const my $PLACES    => 'place';
const my $PLACES_PC => 'place_with_i';

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $xhea_folder = $signup->subfolder('xhea');

    my ( $fieldnames_of_r, $fields_of_r, $adjusted_values_of_r )
      = Actium::Files::Xhea::load_adjusted($xhea_folder);

    my $tab_strings_r
      = Actium::Files::Xhea::tab_strings( $fieldnames_of_r, $fields_of_r,
        $adjusted_values_of_r );

    if (exists ($fieldnames_of_r->{$STOPS})) {
    my ( $new_s_heads_r, $new_s_records_r )
      = Actium::Import::CalculateFields::hastus_stops_import(
        $fieldnames_of_r->{$STOPS},
        $adjusted_values_of_r->{$STOPS} );

    $tab_strings_r->{$STOPS_PC}
      = Actium::Util::aoa2tsv( $new_s_records_r, $new_s_heads_r );
      
    }
      
    if (exists ($fieldnames_of_r->{$PLACES})) {

    my ( $new_p_heads_r, $new_p_records_r )
      = Actium::Import::CalculateFields::hastus_places_import(
        $fieldnames_of_r->{$PLACES},
        $adjusted_values_of_r->{$PLACES} );

    $tab_strings_r->{$PLACES_PC}
      = Actium::Util::aoa2tsv( $new_p_records_r, $new_p_heads_r );
    }

    my $tab_folder = $xhea_folder->subfolder('tab');

    $tab_folder->write_files_from_hash( $tab_strings_r, qw(tab txt) );

    $tab_folder->json_store_pretty( $fields_of_r, 'records.json' );

    return;

} ## tidy end: sub START

1;

