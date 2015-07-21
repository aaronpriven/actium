#!/Activeperl/bin/perl

# Process school notes

use 5.012;
use warnings; ### DEP ###

our $VERSION = 0.010;

use Text::Trim; ### DEP ###
use Lingua::EN::NameCase ('nc'); ### DEP ###
use Text::Wrap; ### DEP ###

my @entries;

# reads from @ARGV
while (<>) {
    chomp;
    trim;
    s/^Notes:\s+//;
    s/\s+/ /g;
    if (/^S-\d/) {
        push @entries, q{};
    }
    $entries[-1] .= "$_ ";
}

$Text::Wrap::columns = 72;

foreach my $entry (@entries) {
    trim($entry);
    $entry =~ s (\\)(/)g;
    $entry =~ s ( ([LR]) / ) ($1/)gx;
    $entry = nc($entry);
    $entry =~ s/\bInto\b/into/g;
    $entry =~ s/\bVia\b/via/g;
    $entry = wrap('','',$entry);
    say $entry ;
    say '';
}
