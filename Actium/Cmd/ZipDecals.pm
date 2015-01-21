# Actium/Cmd/ZipDecals.pm

# Creates a Zip archive of the relevant decals

# Subversion: $Id$

use 5.016;
use warnings;

package Actium::Cmd::ZipDecals 0.003;

use Actium::Preamble;
use Actium::O::Folder;
use Actium::Util('file_ext');
use Actium::Sorting::Line ('sortbyline');
use Spreadsheet::ParseXLSX;

use Archive::Zip qw(:ERROR_CODES);

const my $EPSFOLDER =>
  '/Volumes/Bireme/Flag Projects/Flags 2011-02/Decals/export_eps_bleed';

sub HELP { say "Make an archive of the decals in an Excel file." }

sub START {
    my $class = shift;
	
	my %params = @_;

	my @argv = @{$params{argv}};
    
    my $filespec = shift @argv;
    die "No input file given" unless $filespec;
    
    my ($folder, $filename) = Actium::O::Folder->new_from_file($filespec);
    
    my $sheet = $folder->load_sheet($filename);
    my @decals = sortbyline $sheet->column(0);
    
    my $zipobj = Archive::Zip->new();
    
    foreach my $decal (@decals) {
        next if (! $decal and $decal ne '0');
        next if $decal =~ /decal/i;
        my $zip_internal_filename  = "$decal.outl.eps";
        my $diskfile = "$EPSFOLDER/$zip_internal_filename";
        $zipobj->addFile( $diskfile, $zip_internal_filename ) ;
    }
    
    my ($zipfile, undef)  = file_ext($filename);
    $zipfile =~ s/-counted\z//i;
    $zipfile = "$zipfile-decals.zip";
    $zipfile =~ s/-decals-decals/-decals/i;

    my $result = $zipobj->writeToFileNamed($zipfile);
    die "Couldn't write zip file $zipfile"
      unless $result == AZ_OK;
      
    say "Decals written to $zipfile";

} ## tidy end: sub START

1; 
__END__