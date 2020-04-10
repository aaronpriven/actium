package Octium::Cmd::CompareSkeds 0.014;

use Actium;
use Octium;
use Octium::Sked::Collection;

sub OPTIONS {
    return (
        'signup_with_old',
        {   spec        => 'excel',
            description => 'Save as Excel workbook instead of output to stdout',
        }
    );
}

sub START {

    my $signup     = Octium::env->signup;
    my $old_signup = Octium::env->oldsignup;

    my $collection = Octium::Sked::Collection->load_storable(
        signup     => $signup,
        collection => 'received'
    );

    my $oldcollection = Octium::Sked::Collection->load_storable(
        signup     => $old_signup,
        collection => 'received'
    );

    my $compcollection = $collection->compare_from($oldcollection);

    if ( env->option('excel') ) {    # Excel
        my $filename
          = $old_signup->signup . "-" . $signup->signup . '-diff.xlsx';
        my $excelcry = env->cry('Writing excel comparison');
        $excelcry->wail($filename);

        $compcollection->excel( file => $filename );
        $excelcry->done;

    }
    else {                           # Text
        say $compcollection->text;
    }

}    ## tidy end: sub START

1;
