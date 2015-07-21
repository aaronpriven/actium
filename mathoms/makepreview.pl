#!/ActivePerl/bin/perl

use 5.012;
use warnings;

our $VERSION = 0.010;

use Const::Fast; ### DEP ###
use File::Basename; ### DEP ###
use File::Spec; ### DEP ###

const my $COMMAND =>
  '/opt/local/bin/epstool --add-tiff6p-preview --dpi 72 --gs-args '
  . quotemeta("-dTextAlphaBits=4 -dGraphicsAlphaBits=4 -dUseCIEColor");
#  $1 preview-$1 >& $1.log &

say "Processing:";

foreach my $input_file (@ARGV) {
    my ( $volume, $path, $filename ) = File::Spec->splitpath($input_file);
    my ( $name, undef, $suffix ) = fileparse( $input_file, qr/(?i:\.eps)/ );

    my $output_file
      = File::Spec->catpath( $volume, $path, "$name-preview$suffix" );
    my $log_file
      = File::Spec->catpath( $volume, $path, "$name.makepreview-log" );

    say "   $input_file";

    for ( $input_file, $output_file, $log_file ) {
        $_ = quotemeta($_);
    }

    system "$COMMAND $input_file $output_file >& $log_file &";

}
