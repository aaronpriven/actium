#!/Actium/KML.pm

# Routines for dealing with KML files

#Subversion: $Id$

# Legacy status: 4

package Actium::KML 0.003;

use Actium::Preamble;
use XML::Twig;

# Sadly, Geo::XML errors out on AC Transit's KML files.
# I don't know why.

use Sub::Exporter -setup => { exports => [qw(unify write_kml)] };

sub unify {
	my @files = @_;


	foreach my $file (@files) {
		
		my $twig = XML::Twig->new();    # create the twig
		$twig->parsefile($file);        # build it
		


		last;

	}

}

sub write_kml {
	
	1; # no-op
	
}

1;

__END__
