#!/ActivePerl/bin/perl

use 5.012;
use warnings;

use autodie;
use FindBin('$Bin');
use lib ($Bin);

my $firstfile = shift(@ARGV);

my %line_of;

open my $in, '<', $firstfile;

while ( my $line = <$in> ) {
    chomp $line;
    my ($id) = split( /\t/, $line );
    $line_of{$id} = $line;
}

my $lastargv = q{};

my %results;

while ( my $line = <> ) {
    chomp $line;
    if ( $lastargv ne $ARGV ) {
        say "---\n$ARGV\n---";
        $lastargv = $ARGV;
    }

    my ($first_column) = split( /\t/, $line );

    next unless $line_of{$first_column};

    #say "< $line_of{$first_column}\n> $line";
    say "$line_of{$first_column}\t$line";

}
