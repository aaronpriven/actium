#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use DDP;

use 5.024;

my $filepfx = '/Users/Shared/Dropbox (AC_PubInfSys)/B/ACTium/signups/';

my @additions = (
    $filepfx . 'dumbarton_stops/dbs-active.txt',
    $filepfx . 'flex/flex-active.txt',
    $filepfx . 'su18/stoplines-600s.txt',
);

my %lines_of;
my %linedirs_of;

foreach my $file (@additions) {
    open my $addfile, '<', $file;

    $_ = <$addfile>;
    chomp;
    my @headers = split(/\t/);

    while (<$addfile>) {
        chomp;
        my %record;
        @record{@headers} = split(/\t/);
        my ( $stopid, $lines, $linedirs )
          = @record{qw/h_stp_511_id p_lines p_linedirs/};

        next if $stopid =~ /[^0-9]/;

        if ( $file =~ /600/ ) {
            my @lines = split( ' ', $lines );
            @lines = grep {/^6\d\d$/} @lines;
            $lines = join( " ", @lines );
            my @linedirs = split( ' ', $linedirs );
            @linedirs = grep {/^6\d\d-/} @linedirs;
            $linedirs = join( " ", @linedirs );

        }

        push $lines_of{$stopid}->@*,    $lines;
        push $linedirs_of{$stopid}->@*, $linedirs;
    } ## tidy end: while (<$addfile>)

    close $addfile;

} ## tidy end: foreach my $file (@additions)

open my $in,  '<', $filepfx . 'su18/stoplines.txt';
open my $out, '>', $filepfx . 'su18/stoplines-added.txt';

$_ = <$in>;
chomp;
my @headers = split(/\t/);
say $out $_;

RECORD:
while (<$in>) {
    chomp;
    my %record;
    @record{@headers} = split(/\t/);
    my $stopid = $record{h_stp_511_id};

    if ( not exists $lines_of{$stopid} ) {
        say $out $_;
        next RECORD;
    }

    $record{p_lines}    .= ' ' . join( " ", $lines_of{$stopid}->@* );
    $record{p_linedirs} .= ' ' . join( " ", $linedirs_of{$stopid}->@* );
    $record{p_active} = 1;

    $record{$_} //= '' foreach @headers;

    say $out join( "\t", @record{@headers} );

} ## tidy end: RECORD: while (<$in>)
