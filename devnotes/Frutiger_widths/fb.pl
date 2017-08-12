#!/ActivePerl/bin/perl

use 5.020;
use warnings;
use autodie;

open my $in, '<', 'fb.csv';

open my $out, '>', 'fbout';

$_ = <$in>;    # headers

my @width_of;

while (<$in>) {

    chomp;
    my @fields = split(/,/);
    foreach (@fields) {
        s/\A\s+//;
        s/\s+\z//;

    }

    my ( $unicodevalue, $glyph, $width, $sidebearing ) = @fields;

    $unicodevalue =~ s/U\+//;

    my $dec = hex($unicodevalue);

    next unless $dec <= 255;

    $width_of[$dec] = $width / 1000;

} ## tidy end: while (<$in>)

for my $row ( 0 .. 31 ) {

    for my $col ( 0 .. 7 ) {
        my $charnum = $row * 8 + $col;

        my $width = $width_of[$charnum] // 0;

        printf $out " %1.3f, ", $width;

    }
    say $out '';

}
