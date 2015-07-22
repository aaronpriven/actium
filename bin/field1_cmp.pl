#!/usr/bin/env perl

use 5.012;
use warnings;

our $VERSION = 0.003;

use autodie; ### DEP ###
use FindBin('$Bin'); ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

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
    my $firstline;

    #next unless $line_of{$first_column};
    if (not $line_of{$first_column}) {
        $firstline = "(NUL)\t0";
    }
    else {
        $firstline = $line_of{$first_column};
    }

    #say "< $line_of{$first_column}\n> $line";
    say "$firstline\t$line";

}
