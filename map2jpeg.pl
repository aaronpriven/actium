#!/ActivePerl/bin/perl

use 5.012;
use warnings;

use File::Copy;

my $gsargs = '-sDEVICE=jpeg -dGraphicsAlphaBits=4 -dTextAlphaBits=4';

my $output_folder = '/Volumes/SHARE$/District Public Share/APRIVEN/Maps_For_Web';

my $resolution = 288;

#my %percent_of = ( 288 => '100pct' ,
#                   144 => '50pct' ,
#                   72  => '25pct' ,
#                   36 => '12.5pct',
#                  );

foreach (@ARGV) {

    next unless /\.pdf\z/;
    
    my $input_line = $_;

    $input_line =~ s/-.*//;
    $input_line =~ s/\.pdf\z//;
    
    my @output_lines = split( /_/, $input_line );

    my $first_output_line    = shift @output_lines;
    my $first_output_pdf     = $first_output_line . '.pdf';
    my $first_output_pdfspec = "$output_folder/$first_output_pdf";
    my $first_jpeg           = "$first_output_line.jpg";
    my $first_jpeg_spec      = "$output_folder/$first_jpeg";

    say "\n$_ -> ${first_output_line}.jpg \n";
    say qq{gs -r$resolution $gsargs -o "$first_jpeg_spec" "$_"};
    system qq{gs -r$resolution $gsargs -o "$first_jpeg_spec" "$_"};

    say "\nCopying $_ to $first_output_pdf";
    copy( $_, $first_output_pdfspec ) or die "$!";

    foreach my $output_line (@output_lines) {
        my $output_pdf     = $output_line . '.pdf';
        my $output_pdfspec = "$output_folder/$output_pdf";
        my $jpeg = "$output_line.jpg";
        my $jpeg_spec = "$output_folder/$jpeg";
        
        say "Copying $_ to $output_pdf";
        copy( $_, $output_pdfspec ) or die "$!";
        
        say "Copying $first_jpeg to $jpeg";
        copy( $first_jpeg_spec, $jpeg_spec ) or die "$!";

    }

} ## tidy end: foreach (@ARGV)

