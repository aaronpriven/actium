package Actium::Cmd::PRAddStop 0.010;

use Actium::Preamble;

use Actium::Photos;

use File::Glob(':bsd_glob');         ### DEP ###
use Image::ExifTool('ImageInfo');    ### DEP ###

const my %IS_VALID_EXT => map { fc($_) => 1 } qw/gif jpeg jpg png/;
const my $IMAGE_INFO_OPTIONS => { PrintConv => 0, CharsetEXIF => 'UTF8', };

sub OPTIONS {
    return (
        [   'repository=s',
            'Location of repository in file system',
            '/Volumes/Bireme/Photos/Repository'
        ],
        'actiumdb',
    );
}

sub HELP {
    my ( $class, $env ) = @_;
    my $command = $env->command;
    say "Adds photo files to the photo repository.";
    say "Usage: $command pr_import <file> <file> >...";
    say "If a directory is given, will import all photos in that directory.";
    return;
}

sub START {

    my ( $class, $env ) = @_;
    my $actium_db = $env->actiumdb;

    my @argv = $env->argv;
    goto &HELP if not @argv;

    my @photos_to_process = get_photos_to_process(@argv);
    die "No files to process.\n" unless @photos_to_process;

    foreach my $photo_file (@photos_to_process) {
        my ( $lat, $long ) = get_geoloc($photo_file);

        if ( not defined $lat or not defined $long ) {
            warn "Couldn't determine geolocation for $photo_file\n";
            next;
        }

        say "$photo_file: $lat $long";

        \my %stop = $actium_db->ss_nearest_stop( $lat, $long );

        say '  ' . $stop{h_stp_511_id} . " " . $stop{c_description_full};

    }
} ## tidy end: sub START

sub get_geoloc {
    my $photo_file = shift;

    my $info
      = ImageInfo( $photo_file,
        qw/Composite:GPSLatitude Composite:GPSLongitude File:/,
        $IMAGE_INFO_OPTIONS );

    my $lat  = $info->{GPSLatitude};
    my $long = $info->{GPSLongitude};

    return ( $lat, $long );

}

sub get_photos_to_process {

    my @argv = @_;
    my @photos_to_process;

    foreach my $arg (@argv) {

        if ( -d $arg ) {
            my @dirfiles = bsd_glob("$arg/*");
            @dirfiles = grep { check_ext($_) } @dirfiles;
            if (@dirfiles) {
                push @photos_to_process, @dirfiles;
            }
            else {
                warn "No files found in directory $arg.\n";
            }
        }
        elsif ( -f $arg ) {
            if ( check_ext($arg) ) {
                push @photos_to_process, $arg;
            }
            else {
                warn "Unknown file extension (or no extension) in $arg.\n";
            }
        }
        else {
            warn "File or directory not found: $arg.\n";
        }

    } ## tidy end: foreach my $arg (@argv)

    return @photos_to_process;

} ## tidy end: sub get_photos_to_process

sub check_ext {
    my $file = shift;
    my $ext  = u::file_ext($file);
    return $IS_VALID_EXT{ fc($ext) };
}

1;

__END__
