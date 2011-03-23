#!/usr/bin/perl


my %ajays;

open (my $ajay, '<' , '/Volumes/Bireme/ACTium/db/sp10/ajay_stops2.txt');

my $nothing = <$ajay>; # throw away first line

while (<$ajay>) {
    chomp;
    my ($id, $rest) = split (/\t/ , $_ , 2);
    $ajays{$id} = $rest;
}

close $ajay;

my %comps;

open (my $comp, '<' , '/Volumes/Bireme/ACTium/db/sp10/comparestops-x.txt');

$nothing = <$comp>; # throw away first line

while (<$comp>) {
    chomp;
    my ($type, $id, $rest) = split (/\t/ , $_ , 3);
    next if $type eq 'AS' or $type eq 'RS';
    $comps{$id} = $rest;
}

print "\n\nIn Ajay's list but not in Aaron's:\n\n";

foreach $id (keys %ajays) {
   print "$id\t$ajays{$id}\n" unless exists $comps{$id};
}

print "\n\nIn Aaron's list but not in Ajay's:\n\n";

foreach $id (keys %comps) {
   print "$id\t$comps{$id}\n" unless exists $ajays{$id};
}