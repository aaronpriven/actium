# /Actium/Cmd/CalculateFieldsTest.pm
#
# Takes XML files exported from Hastus and imports them

# Subversion: $Id: XheaImport.pm 319 2014-04-03 22:07:44Z aaronpriven $

package Actium::Cmd::CalculateFieldsTest 0.003;

use Actium::Preamble;
use Actium::Import::CalculateFields;
use Actium::O::Folders::Signup;
use Actium::Files::TabDelimited ('read_aoas');

sub HELP {
    say 'Help not implemented.';
    return;
}

const my $STOPSFILE  => 'stop.txt';
const my $PLACESFILE => 'place.txt';

const my $STOPSPCFILE  => 'stop_pc';
const my $PLACESPCFILE => 'place_pc';

sub START {

    my $signup     = Actium::O::Folders::Signup->new();
    my $tab_folder = $signup->subfolder('xhea/tab');

    my ( $headers_of, $values_of ) = read_aoas(
        {   files  => [ $STOPSFILE, $PLACESFILE ],
            folder => $tab_folder,
        }
    );

    my %tabstring_of;

    my ( $new_s_heads_r, $new_s_records_r )
      = Actium::Import::CalculateFields::hastus_stops_import(
        $headers_of->{$STOPSFILE},
        $values_of->{$STOPSFILE} );

    $tabstring_of{$STOPSPCFILE}
      = Actium::Util::aoa2tsv( $new_s_records_r, $new_s_heads_r );

    my ( $new_p_heads_r, $new_p_records_r )
      = Actium::Import::CalculateFields::hastus_places_import(
        $headers_of->{$PLACESFILE},
        $values_of->{$PLACESFILE} );

    $tabstring_of{$PLACESPCFILE}
      = Actium::Util::aoa2tsv( $new_p_records_r, $new_p_heads_r );

    $tab_folder->write_files_from_hash( \%tabstring_of, qw(tab txt) );

    return;

} ## tidy end: sub START

1;
