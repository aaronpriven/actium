#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use DDP;

use 5.024;

my $filepfx = '/Users/Shared/Dropbox (AC_PubInfSys)/B/ACTium/signups/';

my @additions = (
    $filepfx . 'dumbarton_stops/dbs-active.txt',
    $filepfx . 'flex/flex-active.txt'
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

        push $lines_of{$stopid}->@*,    $lines;
        push $linedirs_of{$stopid}->@*, $linedirs;
    }

    close $addfile;

}    ## tidy end: foreach my $file (@additions)

open my $in,  '<', $filepfx . 'w17/stoplines.txt';
open my $out, '>', $filepfx . 'w17/stoplines-added.txt';

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

}    ## tidy end: RECORD: while (<$in>)
