#!/usr/bin/env perl
#
# remove specday notes from prehistoric schedules, for comparison

use 5.024;

my @files = glob('*.txt');

foreach my $file (@files) {
    open my $ifh, '<', $file;
    open my $ofh, '>', "out/$file";

    for (qw/specline notedefsline headerline/) {
        my $line = <$ifh>;
        print $ofh $line;
    }

    while (<$ifh>) {
        my @fields = split(/\t/);
        $fields[0] =~ s/-.*//;
        print $ofh join( "\t", @fields );
    }

}
