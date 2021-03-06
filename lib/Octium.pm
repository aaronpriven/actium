package Octium 0.015;

use Actium;

# imported into the caller's namespace
#
use parent 'Exporter';
our @EXPORT = qw/@TRANSBAY_NOLOCALS @DIRCODES /;

const our @TRANSBAY_NOLOCALS =>
  (qw/BF3 FS G H J L LA LC NX NX1 NX2 NX3 NX4 NXC OX P S SB U V W Z/);

const our @DIRCODES => qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN  A  B );
#  Hastus                 0  1  3  2  4  5  6  7  8  9  10 11 12 13 14 15

# duplicating Actium into Octium

sub add_before_extension {

    my $input_path = shift;
    my $addition   = shift;

    my ( $volume, $folders, $filename ) = File::Spec->splitpath($input_path);
    my ( $filepart, $ext ) = file_ext($filename);

    my $output_path
      = File::Spec->catpath( $volume, $folders, "$filepart-$addition.$ext" );

    return ($output_path);

}

sub filename {

    my $filespec = shift;
    my $filename;
    ( undef, undef, $filename ) = File::Spec->splitpath($filespec);
    return $filename;
}

sub file_ext {
    my $filespec = shift;                 # works on filespecs or filenames
    my $filename = filename($filespec);
    my ( $filepart, $ext )
      = $filename =~ m{(.*)    # as many characters as possible
                      [.]     # a dot
                      ([^.]+) # one or more non-dot characters
                      \z}sx;
    return ( $filepart, $ext );
}

1;
