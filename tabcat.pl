#!/ActivePerl/bin/perl 

use 5.016;
use warnings;

binmode STDERR, ':encoding(UTF-8)';
binmode STDOUT, ':encoding(UTF-8)';
binmode STDIN,  ':encoding(UTF-8)';

use utf8;
use autodie;
use open ':encoding(UTF-8)';
use Encode;
my @args = map { decode( 'UTF-8', $_ ) } @ARGV;

#@args = qw(StopID /Users/apriven/actium/db/sp13/compare/OX-Transbay
#  /Users/apriven/actium/db/sp13/compare/comparestops-action.txt);

use List::Util('max');

my $fieldsep = "\t";
my $nul      = q{};

my $key_field    = shift @args;
my $fc_key_field = fc($key_field);

my %lines_of;
my @tabcounts;    # represents separators, not fields

foreach my $file_idx ( 0 .. $#args ) {
    my $file = $args[$file_idx];

    open my $fh, "<:eol(LF)", $file;

    my $headerline = readline($fh);
    chomp $headerline;
    $headerline =~ s/$fieldsep*\z//;
    my @headers = splittab($headerline);

    my $key_idx;
    for my $head_idx ( 0 .. $#headers ) {
        my $this_head = $headers[$head_idx];
        if ( fc($this_head) eq $fc_key_field ) {
            $key_idx = $head_idx;
            last;
        }
    }
    die "Can't find key field $key_field in file $file"
      if not defined $key_idx;

    splice( @headers, $key_idx, 1 );    # delete key header from line

    $headerline = jointab(@headers);
    $lines_of{$nul}[$file_idx] = $headerline;

    my $tabcount = counttab($headerline);

    while ( my $line = readline($fh) ) {
        chomp $line;
        $line =~ s/$fieldsep*\z//;

        my @fields   = splittab($line);
        my $keyvalue = $fields[$key_idx];
        splice( @fields, $key_idx, 1 );    # delete key from line
        $lines_of{$keyvalue}[$file_idx] = jointab(@fields);

        $tabcount = max( $tabcount, (counttab($line) -1 ));

    }

    $tabcounts[$file_idx] = $tabcount;

    close $fh;

} ## tidy end: foreach my $file_idx ( 0 .....)

foreach my $key_value ( sort keys %lines_of ) {

    my @lines = @{ $lines_of{$key_value} };

    for my $file_idx ( 0 .. $#lines ) {
        if ( not defined $lines[$file_idx] ) {
            $lines[$file_idx] = $fieldsep x $tabcounts[$file_idx];
        }
        else {
            my $tabcount = counttab( $lines[$file_idx] );
            if ( $tabcount < $tabcounts[$file_idx] ) {
                my $moretabs = $tabcounts[$file_idx] - $tabcount;
                $lines[$file_idx] .= $fieldsep x $moretabs;
            }
        }
    }

    $key_value = $key_field if $key_value eq $nul;
    say jointab( $key_value, @lines );
} ## tidy end: foreach my $key_value ( sort...)

sub splittab {
    my $line = shift;
    return split( /$fieldsep/, $line );
}

sub counttab {
    my $line = shift;
    my $count = () = $line =~ /$fieldsep/g;
    return $count

}

sub jointab {
    return join( $fieldsep, @_ );
}
