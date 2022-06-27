#!/usr/bin/env perl

use Actium;
use autodie;

my $xheafile = '/Users/apriven/si/f22p/xhea/tab/route.txt';

open my $xheafh, '<', $xheafile;

my $headers = scalar readline $xheafh;

my (%opd_of);

while ( my $xhealine = readline $xheafh ) {
    chomp $xhealine;

    my ( $pub1, $pub2, $color, $desc, $line, $sysrec, $type, $booking )
      = split( /\t/, $xhealine );

    $opd_of{$line}[1] = $pub1;
    $opd_of{$line}[2] = $pub2;

}

close $xheafh;

my $dirdestfile = '/Users/apriven/si/f22p/direction-destinations.txt';

open my $dirdestfh, '<', $dirdestfile;
my $ddheaders = scalar readline $dirdestfh;

my ( %to_print, %npd_of );

while ( my $dirdestline = readline $dirdestfh ) {
    chomp $dirdestline;
    my ( $line, $dir, $destination ) = split( /\t/, $dirdestline );

    my $num = ( $dir == 0 or $dir == 2 ) ? 1 : 2;
    $npd_of{$line}[$num] = $destination;

    $to_print{$line} = 1 if $destination ne $opd_of{$line}[$num];

}

close $dirdestfh;

say "Line\tX1\tPublicDirection1\tX2\tPublicDirection2\tFlipped";

foreach my $line ( Actium::sortbyline keys %to_print ) {

    my $pd1 = $npd_of{$line}[1] || '<null>';
    my $pd2 = $npd_of{$line}[2] || '<null>';

    my $opd1 = $opd_of{$line}[1] || '<null>';
    my $opd2 = $opd_of{$line}[2] || '<null>';

    my $flipped = ($opd1 eq $pd2 and $opd2 eq $pd1);

    my $chgpd1 = (not $flipped and $pd1 ne $opd1);
    my $chgpd2 = (not $flipped and $pd2 ne $opd2);
    
    foreach ($chgpd1, $chgpd2, $flipped) {
       $_ = $_ ? '*' : '';
    }

    say "$line\t$chgpd1\t$pd1\t$chgpd2\t$pd2\t$flipped";

}

