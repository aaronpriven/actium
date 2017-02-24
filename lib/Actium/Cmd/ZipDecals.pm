package Actium::Cmd::ZipDecals 0.012;

# Creates a Zip archive of the relevant decals

use 5.016;
use warnings;


use Actium::Preamble;
use Actium::O::Folder;
use Actium::Util('file_ext');
use Actium::Sorting::Line ('sortbyline');
use Spreadsheet::ParseXLSX; ### DEP ###

use Archive::Zip qw(:ERROR_CODES); ### DEP ###

const my $EPSFOLDER =>
  '/Volumes/Bireme/Actium/flagart/Decals/export_eps_bleed';

sub HELP { say "Make an archive of the decals in an Excel file." }

sub START {
    my $class = shift;
	
	my $env = shift;
	my @argv = $env->argv;

    my $filespec = shift @argv;
    die "No input file given" unless $filespec;
    
    my ($folder, $filename) = Actium::O::Folder->new_from_file($filespec);
    
    my $sheet = $folder->load_sheet($filename);
    my @decals = sortbyline $sheet->col(0);
    
    my $zipobj = Archive::Zip->new();
    
    foreach my $decal (@decals) {
        next if (! $decal and $decal ne '0');
        next if $decal =~ /decal/i;
        my $zip_internal_filename  = "${decal}_outl.eps";
        my $diskfile = "$EPSFOLDER/$zip_internal_filename";
        
        die "Can't find file $diskfile" unless -e $diskfile;
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
