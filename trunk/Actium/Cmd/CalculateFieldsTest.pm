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

const my $STOPSFILE => 'stop.txt';

sub START {

    my $signup     = Actium::O::Folders::Signup->new();
    my $tab_folder = $signup->subfolder('xhea/tab');

    my ( $headers_of, $values_of ) = read_aoas(
        {   files  => [$STOPSFILE],
            folder => $tab_folder,
        }
    );

    my ( $newheads_r, $newrecords_r )
      = Actium::Import::CalculateFields::hastus_stops_import(
        $headers_of->{$STOPSFILE},
        $values_of->{$STOPSFILE} );

    say Actium::Util::aoa2tsv ( $newrecords_r , $newheads_r);

    return;

} ## tidy end: sub START

1;
