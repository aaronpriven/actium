#!/usr/bin/perl

use 5.010;

use strict;
use warnings;

my $simplefile = '/volumes/bireme/actium/db/current/SimpleStops.tab';

open my $in, '<', $simplefile
  or die "Can't open $simplefile";

$/ = "\r";    # FileMaker exports CRs

use constant { PHONEID => 0, STOPID => 1, DESC => 2, LAT => 3, LONG => 4 };

my ( %of_phoneid, %of_stopid );

die "Usage: $0 [-n] id [ id ] ...\nid can be a phoneid or stopid.\n"
  unless @ARGV;

while (<$in>) {

    chomp;
    next unless $_;
    my @fields  = split(/\t/);
    my $stopid  = $fields[STOPID];
    my $phoneid = $fields[PHONEID];
    $of_phoneid{$phoneid} = \@fields;
    $of_stopid{$stopid}   = \@fields;
}

my $dump = 0;

close $in
  or die "Can't open $simplefile";

foreach (@ARGV) {
    if ( $_ eq "-d" ) {
        $dump = 1;
        next;
    }

    if (/\A\d{5}\z/) {
        display( $of_phoneid{$_} );
        next;
    }

    if (/\A\d{6}\z/) {
        display( $of_stopid{"0$_"} );
        next;
    }

    if (/\A\d{7,8}\z/) {
        display( $of_stopid{"$_"} );
        next;
    }

    if ($dump) {
            say "0||||";
    } else {
       #warn "Unknown id type: $_\n";
      foreach my $fields_r (values %of_stopid) {
       
          my $desc = $fields_r ->[DESC];
          display($fields_r)  if $desc =~ /$_/i;
       
      } 
       
       
       
       
    } 

} ## tidy end: foreach (@ARGV)

sub display {
 
    my $fields_r = shift;
    if ( ref($fields_r) ne 'ARRAY' ) {
        if ($dump) {
            say "0||||";
        } else {
        say "Unknown id $_";
        }
        return;
    }
    if ($dump) {
        say( join( q{|}, @{$fields_r} ) );

    }
    else {
        print ( $fields_r->[PHONEID], '  ', $fields_r->[STOPID] , '  ' );
        say( $fields_r->[DESC] );
    }

}
