# /Actium/Cmd/NewSignup.pm
#
# Prepares a new signup directory

# Subversion: $Id$

package Actium::Cmd::NewSignup 0.009;

use Actium::Preamble;
use Actium::O::Folders::Signup;
use Actium::Options('option');
use Actium::Util('filename');
use Actium::Files::Xhea;
use Archive::Zip;
use Actium::Term;

sub OPTIONS {
    return ( [ 'xhea=s', 'ZIP file containing Xhea export ', ], );
}

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium newsignup -- prepare new signup directories and extract files
HELP

    Actium::Term::output_usage();

    return;

}

sub START {

    emit "Making signup and subdirectories";

    my $signup      = Actium::O::Folders::Signup->new;
    my $hasi_folder = $signup->subfolder('hasi');
    my $xhea_folder = $signup->subfolder('xhea');

    emit_done;

    my $xheazip = option('xhea');

    if ($xheazip) {

        emit "Extracting XHEA files";

        unless ( -e $xheazip ) {
            die "Can't find xhea zip file $xheazip";
        }

        my $zipobj = Archive::Zip->new($xheazip);

        foreach my $member ( $zipobj->members ) {
            next if $member->isDirectory;

            my $filename = filename( $member->fileName );

            emit_over( $filename . '...' );
            my $filespec = $xhea_folder->make_filespec($filename);

            $member->extractToFileNamed("$filespec");

        }

        emit_over('');

        emit_done;

        emit "Importing xhea files";

        my $tab_folder = $xhea_folder->subfolder('tab');

        Actium::Files::Xhea::xhea_import(
            signup      => $signup,
            xhea_folder => $xhea_folder,
            tab_folder  => $tab_folder
        );

        emit_done;

        emit "Creating HASI files from XHEA files";

        Actium::Files::Xhea::to_hasi( $tab_folder, $hasi_folder );

        emit_done;

    }

}    ## tidy end: sub START

1;
