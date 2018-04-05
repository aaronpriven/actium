#!/usr/bin/env perl

use utf8;
use 5.016;
use warnings;

# save as plain text (utf-8, LF), after converting the table to text separated by tabs

use autodie;
use HTML::Entities;

my $table = 0;
my $nextpara;

my $infile  = shift @ARGV;
my $outfile = shift @ARGV;

unless ($outfile) {
    $outfile = $infile =~ s/(?:\.txt)?\z/.html/r;
}

my $myargvfh;

if ( !open( $myargvfh, '<:encoding(UTF-8)', $infile ) ) {
    warn "Can't open $infile: $!\n";
    next;
}

open my $out, '>:encoding(UTF-8)', $outfile or die $!;
select $out;

my $prev_elem = 'p';
say '<p><a href="#es">Español</a><br/><a href="#zh">中文</a></p>';

while (<$myargvfh>) {
    chomp;
    s/\cM//g;
    s/\x{FEFF}//;
    next unless $_;
    encode_entities($_);

    my $this_elem
      = /\cI/        ? 'table'
      : /^\s*&bull;/ ? 'ul'
      : /^\s*\.ES/   ? ':es'
      : /^\s*\.ZH/   ? ':zh'
      :                'p';

    say STDOUT $this_elem;

    if ( $prev_elem ne $this_elem ) {
        end_elem($prev_elem);
        start_elem($this_elem);
    }
    $prev_elem = $this_elem;

    if ( $this_elem eq 'table' ) {
        my ( $line, $change ) = split( /\t/, $_, 2 );
        $line = line_link($line);
        if ( $line =~ /Other|Otros|&#x5176;&#x4ED6;/ ) {
            $change = line_link($change);
        }
        if ( $change =~ /^\!/ ) {
            $change =~ s/^\!//;
            $change = line_link($change);
        }
        $_
          = "<tr><td align=center valign=top>$line</td><td align=left valign=top>$change</td></tr>";
    }
    elsif ( $this_elem eq 'ul' ) {
        s/\s*&bull;//;
        $_ = "<li>$_</li>";
    }
    elsif ( $this_elem eq ':es' or $this_elem eq ':zh' ) {
        # don't do anything
    }
    else {
        if ( $nextpara or $_ eq 'AC Transit Service Changes' ) {
            $nextpara //= 'EN';
            $_ = "<h3 id=$nextpara>$_</h3>";
            undef $nextpara;
        }
        else {
            $_ = "<p>$_</p>";
        }
    }

    say;
}    ## tidy end: while (<$myargvfh>)

sub end_elem {
    my $elem = shift;
    if ( $elem eq 'table' ) {
        say "</table>";
    }
    elsif ( $elem eq 'ul' ) {
        say "</ul>";
    }

}

sub start_elem {
    my $elem = shift;
    if ( $elem eq 'table' ) {
        $_ =~ s{\cI}{</th><th>}g;
        $_ = "<table cellpadding=6 cellspacing=0 border=1><tr><th>$_</th></tr>";
        say;
        $_ = <$myargvfh>;
        chomp $_;
        encode_entities($_);
    }
    elsif ( $elem eq ':zh' ) {
        $nextpara = 'zh';
        $_        = '';
    }
    elsif ( $elem eq ':es' ) {
        $nextpara = 'es';
        $_        = '';
    }
    elsif ( $elem eq 'ul' ) {
        say "<ul>";
    }

}    ## tidy end: sub start_elem

sub line_link {
    my $text = shift;
    # commented out because schedules aren't active yet
    $text
      =~ s#\b([A-Z0-9]{1,3})\b#<a href="http://www.actransit.org/maps/schedule_results.php?&quick_line=$1">$1</a>#g;
    return $text;
}

