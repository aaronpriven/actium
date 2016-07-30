package Actium::Cmd::NewSignup 0.011;

# Prepares a new signup directory

use Actium::Preamble;
use Actium::Files::Xhea;
use Archive::Zip;    ### DEP ###

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        'newsignup',
        {   spec        => 'xhea=s',
            description => 'ZIP file containing Xhea export ',
            fallback    => $EMPTY,
        },
    );
}

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium newsignup -- prepare new signup directories and extract files
HELP

    return;

}

sub START {

    my $class   = shift;
    my $env     = shift;
    my $xheazip = $env->option('xhea');

    my $cry = cry("Making signup and subdirectories");

    my $signup      = $env->signup;
    my $hasi_folder = $signup->subfolder('hasi');
    my $xhea_folder = $signup->subfolder('xhea');

    $cry->done;

    if ($xheazip) {

        my $xcry = cry("Extracting XHEA files");

        unless ( -e $xheazip ) {
            die "Can't find xhea zip file $xheazip";
        }

        my $zipobj = Archive::Zip->new($xheazip);

        foreach my $member ( $zipobj->members ) {
            next if $member->isDirectory;

            my $filename = u::filename( $member->fileName );

            $xcry->over( $filename . '...' );
            my $filespec = $xhea_folder->make_filespec($filename);

            $member->extractToFileNamed("$filespec");

        }

        $xcry->over('');

        $xcry->done;

    } ## tidy end: if ($xheazip)

    my $sch_cal_folder = $signup->subfolder('sch_cal');

    $sch_cal_folder->glob_plain_files('*.xlsx');

    my $calendar_of_block_r;

    if ( $sch_cal_folder->glob_plain_files('*.xlsx') ) {

        my $suppcry = cry("Importing supplementary calendars");
        require Actium::Files::SuppCalendar;

        $calendar_of_block_r
          = Actium::Files::SuppCalendar::read_supp_calendars($sch_cal_folder);

        $suppcry->done;
    }

    if ( $xheazip or $xhea_folder->glob_plain_files('*.xml') ) {

        my $impcry = cry("Importing xhea files");

        my $tab_folder = $xhea_folder->subfolder('tab');

        my %xhea_import_specs = (
            signup      => $signup,
            xhea_folder => $xhea_folder,
            tab_folder  => $tab_folder,
        );
        $xhea_import_specs{sch_cal_data} = $calendar_of_block_r
          if $calendar_of_block_r;
          
        Actium::Files::Xhea::xhea_import(%xhea_import_specs);

        $impcry->done;

        my $hasicry = cry("Creating HASI files from XHEA files");

        Actium::Files::Xhea::to_hasi( $tab_folder, $hasi_folder );

        $hasicry->done;

    } ## tidy end: if ( $xheazip or $xhea_folder...)

} ## tidy end: sub START

1;
