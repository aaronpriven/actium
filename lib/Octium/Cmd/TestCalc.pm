package Octium::Cmd::TestCalc 0.19;

use Actium;

use Array::2D;
use DDP;
use Octium::Import::CalculateFields;

sub START {

    my $aoa
      = Array::2D->new_from_file( '/Volumes/signups/su22t/xhea/tab/stop.txt',
        'tsv' );

    my $headers_r = shift @$aoa;

    my ( $ret_headers_r, $ret_records_r )
      = Octium::Import::CalculateFields::hastus_stops_import( $headers_r,
        $aoa );


    Array::2D->xlsx(
        $ret_records_r,
        headers     => $ret_headers_r,
        output_file => '/Volumes/signups/su22t/xhea/tab/stop_i.xlsx',
    );

}

1;
