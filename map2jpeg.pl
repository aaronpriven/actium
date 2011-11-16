#!/ActivePerl/bin/perl

use 5.012;
use warnings;

use File::Copy;

my $gsargs = '-sDEVICE=jpeg -dGraphicsAlphaBits=4 -dTextAlphaBits=4';

my $output_folder = '/b/maps/Line Maps/_maps_for_web';

#my $resolution = 288;

#my %percent_of = ( 288 => '100pct' ,
#                   144 => '50pct' ,
#                   72  => '25pct' ,
#                   36 => '12.5pct',
#                  );

my %layers = ( 288 => 0);
#my %layers = ( 288 => 0, 144 => 1, 72 => 2, 36 => 3 , 18 => 4);

foreach (@ARGV) {

    next unless /\.pdf\z/;

    my $input_line = $_;

    $input_line =~ s/-.*//;
    $input_line =~ s/\.pdf\z//;

    foreach my $resolution ( keys %layers ) {
        my $layer = $layers{$resolution};
        my @output_lines = split( /_/, $input_line );

        my $first_output_line    = shift @output_lines;
        my $first_output_pdf     = $first_output_line . '.pdf';
        my $first_output_pdfspec = "$output_folder/$first_output_pdf";
        my $first_jpeg           = "$first_output_line.jpeg";
        my $first_jpeg_spec      = "$output_folder/$first_jpeg";

        say "\n$_ -> ${first_output_line}.jpeg \n";
        say qq{gs -r$resolution $gsargs -o "$first_jpeg_spec" "$_"};
        system qq{gs -r$resolution $gsargs -o "$first_jpeg_spec" "$_"};

        if ( $layer == 0 ) {
            say "\nCopying $_ to $first_output_pdf";
            copy( $_, $first_output_pdfspec ) or die "$!";
        }

        foreach my $output_line (@output_lines) {
            my $output_pdf     = $output_line . '.pdf';
            my $output_pdfspec = "$output_folder/$output_pdf";
            my $jpeg           = "$output_line.jpeg";
            my $jpeg_spec      = "$output_folder/$jpeg";

            if ( $layer == 0 ) {
                say "Copying $_ to $output_pdf";
                copy( $_, $output_pdfspec ) or die "$!";
            }

            say "Copying $first_jpeg to $jpeg";
            copy( $first_jpeg_spec, $jpeg_spec ) or die "$!";

        }

    } ## tidy end: foreach my $resolution ( keys...)

} ## tidy end: foreach (@ARGV)

