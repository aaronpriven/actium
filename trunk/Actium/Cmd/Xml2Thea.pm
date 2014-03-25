# /Actium/Cmd/Xml2Thea.pm
#
# Takes XML files exported from Hastus and turns them into tab-delimited files
# that are just like the Thea files.

# Subversion: $Id$

package Actium::Cmd::Xml2Thea 0.003;

use Actium::Preamble;
use Actium::Files::Hxml2tsv;
use Actium::O::Folders::Signup;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $signup      = Actium::O::Folders::Signup->new();
    my $thea_folder = $signup->subfolder('thea');

    my %results_of
      = Actium::Files::Hxml2tsv::convert_xml_in_folder($thea_folder);

    foreach my $fname ( keys %results_of ) {

        my $fh = $thea_folder->open_write( $fname . ".txt" );
        
        say $fh jt( @{ $results_of{$fname}{headers} } );
        foreach my $record_r ( @{ $results_of{$fname}{records} } ) {
            
            say $fh jt( @{$record_r} );
        }

    }

    return;

} ## tidy end: sub START

1;
