# /Actium/Cmd/KmlUnite.pm

# Takes Ajay Martin's KML files and turns them into a new KML file,
# with each stop as a single placemark, not just one placemark per line.

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::KmlUnite 0.003;

use Actium::Preamble;
use Actium::KML;
use Actium::O::Folder;

sub HELP { say "actium.pl kmlunite path_to_original_kml new_kml_file"; }

sub START {

	my $class = shift;

	my $kml_path = shift;
	die "No path specified" unless $kml_path;
	my $kml_dir
	  = Actium::O::Folder->new( { folderlist => $kml_path, must_exist => 1 } )
	  ;
	my @kml_files = $kml_dir->glob_plain_files('*.km*');

	die "No kml files found in $kml_path" unless @kml_files;

	my $new_kml_file = shift;
	die "No output file specified" unless $new_kml_file;
	$new_kml_file = $kml_dir->make_filespec($new_kml_file);

	my $new_kml = Actium::KML::unify(@kml_files);
	Actium::KML::write_kml( $new_kml_file, $new_kml );

} ## tidy end: sub START

1;

__END__
