# /Actium/TheaImport.pm

# Takes the THEA files and imports them so Actium can use them.

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::TheaImport 0.001;

use Actium::Term ':all';
use Actium::Signup;
use Text::Trim;
use Actium::Util('filename');

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium theaimport -- read THEA files from Scheduling, creating
long-format Sked files for use by the rest of the Actium system,
as well as processing stops and places files for import.
HELP

    Actium::Term::output_usage();

}

my @thea_filetypes
  = qw( trips trippatterns trippatternstops tripstops stops places );

my %required_headers = (
    trippatterns => [
        qw<tpat_route tpat_id tpat_direction
          tpat_in_serv tpat_via tpat_trips_match>
    ],
);

my %dircode_of_thea = (
    Northbound       => 'NB',
    Southbound       => 'SB',
    Eastbound        => 'EB',
    Westbound        => 'WB',
    Counterclockwise => 'CC',
    Clockwise        => 'CW',
    '1'              => 'D1',
);

sub START {

    my $signup     = Actium::Signup->new;
    my $theafolder = $signup->subfolder('thea');

    my %files_of = get_file_names($theafolder);

    my %patterns = get_patterns( $theafolder, \%files_of );
    
    # TODO - load trippatternstops to add what the stops are for each pattern

    use Data::Dumper;

    print Dumper( \%patterns );

}

sub get_patterns {
    my $theafolder = shift;
    my $files_of_r = shift;

    emit 'Reading THEA trippattern files';

    my %patterns;

    foreach my $file ( @{ $files_of_r->{'trippatterns'} } ) {

        emit_over $file;

        my ( $fh, @headers )
          = open_thea_file( $file, 'trippatterns', $theafolder );

        while (<$fh>) {
            trim;

            my %patvalue_of;
            @patvalue_of{@headers} = split("\t");
            next unless $patvalue_of{tpat_in_serv};
            next unless $patvalue_of{tpat_trips_match};

            my $key       = "$patvalue_of{tpat_route}:$patvalue_of{tpat_id}";
            my $direction = $dircode_of_thea{ $patvalue_of{tpat_direction} }
              or emit_text("Unknown direction: $patvalue_of{tpat_direction}");

            $patterns{$key} = $direction;

        }

    } ## tidy end: foreach my $file ( @{ $files_of_r...})

    emit_done;

    return %patterns;

} ## tidy end: sub get_patterns

sub get_file_names {
    emit 'Assembling list of THEA files';

    emit_done;
    my $theafolder = shift;
    my %files_of;
    foreach my $filetype (@thea_filetypes) {
        my @files = $theafolder->glob_plain_files("*$filetype.txt");

        foreach my $file (@files) {
            push @{ $files_of{$filetype} }, filename($file);
        }
    }
    emit_done;
    return %files_of;
}

sub open_thea_file {

    my ( $file, $filetype, $theafolder ) = @_;

    my $fh      = $theafolder->open_read($file);
    my $line    = trim(scalar(<$fh>));
    my @headers = split( "\t", $line );

    foreach my $required_header ( @{ $required_headers{$filetype} } ) {
        if ( not $required_header ~~ @headers ) {
            die "Required header $required_header not found in file $file";
        }

    }

    return $fh, @headers;

}

__END__

