# Actium/Cmd/DecalCount.pm

# Produces counts of decals in a file

# Subversion: $Id$

use 5.016;
use warnings;

package Actium::Cmd::DecalCount 0.003;

use Actium::Preamble;
use Actium::Options (qw<option add_option>);
use Actium::Sorting::Line ('sortbyline');

use Archive::Zip qw(:ERROR_CODES);

add_option( 'zip=s',
    'Make a zip file of the appropriate deals, with the name specified' );

add_option( 'countonly',
    'Only count the decals, do not adjust for number to print' );

const my $EPSFOLDER =>
  '/Volumes/Bireme/Flag Projects/Flags 2011-02/Decals/export_eps_bleed';

sub HELP { say "Count the decals listed in a file." }

sub START {
	
	my %params = @_;

	my @argv = @{$params{argv}};
    
    my $countonly = option('countonly');

    my $inputfilespec = shift @argv;
    die "No input file given" unless $inputfilespec;

    open my $input_h, '<', $inputfilespec
      or die "Can't open file $inputfilespec: $OS_ERROR";

    my (%count_of);
    while (<$input_h>) {
        chomp;
        my @decals = split( /\s+/, $_ );
        for my $decal (@decals) {
            $count_of{$decal}++;
        }
    }

    my @sorted = sortbyline keys %count_of;
    my @records = [ 'DECAL', $countonly ? 'COUNT' : 'TO PRINT' ];

    my $total = 0;

    for my $decal (@sorted) {
        my $count      = $count_of{$decal};
        
        if ($countonly) {
        push @records, [ $decal, $count ];
        $total += $count;
        } else {
            
        my $decals_req = 2 * $count;
        my $to_print   = ceil( $decals_req * 1.1 );

        push @records, [ $decal, $to_print ];
        $total += $to_print;
        }
    }

    push @records, [ 'TOTAL', $total ];

    say jn @{ Actium::Util::tabulate(@records) };

    my $zipfile = option('zip');
    return unless $zipfile;

    my $zipobj = Archive::Zip->new();

    foreach my $decal (@sorted) {
        my $newfile  = "$decal.outl.eps";
        my $diskfile = "$EPSFOLDER/$newfile";
        $zipobj->addFile( $diskfile, $newfile ) ;
    }

    $zipfile .= ".zip" unless $zipfile =~ /\.zip\z/;

    my $result = $zipobj->writeToFileNamed($zipfile);
    die "Couldn't write zip file $zipfile"
      unless $result == AZ_OK;

} ## tidy end: sub START

1; 
__END__