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
use Actium::Files::TabDelimited;

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium theaimport -- read THEA files from Scheduling, creating
long-format Sked files for use by the rest of the Actium system,
as well as processing stops and places files for import.
HELP

    Actium::Term::output_usage();

}

my %required_headers = (
    trippatterns => [
        qw<tpat_route tpat_id tpat_direction
          tpat_in_serv tpat_via tpat_trips_match>
    ],
    trippatternstops => [
        qw<stp_511_id tpat_stp_rank tpat_stp_plc tpat_stp_tp_sequence>,
        'item tpat_id', 'item tpat_route',
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

    my %patterns = get_patterns( $theafolder);

    use Data::Dumper;

    say Dumper( \%patterns );

    # Pattern info and order now in %patterns

}

sub get_patterns {
    my $theafolder = shift;

    emit 'Reading THEA trippattern files';

    my %patterns;

    my $patfileobj = Actium::Files::TabDelimited->new(
        {   glob_files       => ['*trippatterns.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatterns'}
        }
    );

    while ( my $value_of_r = $patfileobj->next_line() ) {

        next unless $value_of_r->{tpat_in_serv};
        next unless $value_of_r->{tpat_trips_match};

        my $tpat_route     = $value_of_r->{tpat_route};
        my $tpat_id        = $value_of_r->{tpat_id};
        my $tpat_direction = $value_of_r->{tpat_direction};

        my $key       = "$tpat_route:$tpat_id";
        my $direction = $dircode_of_thea{$tpat_direction}
          or emit_text("Unknown direction: $tpat_direction");

        $patterns{$key}{DIRECTION} = $direction;

    }

    emit_done;

    emit 'Reading THEA trippatternstops files';

    my $patstopsfileobj = Actium::Files::TabDelimited->new(
        {   glob_files       => ['*trippatternstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatternstops'}
        }
    );

    while ( my $value_of_r = $patstopsfileobj->next_line() ) {

        my $tpat_route = $value_of_r->{'item tpat_route'};
        my $tpat_id    = $value_of_r->{'item tpat_id'};

        my $key = "$tpat_route:$tpat_id";

        next unless exists $patterns{$key};

        $patterns{$key}{STOPS}{ $value_of_r->{tpat_stp_rank} } = {
            STOPID                => $value_of_r->{stp_511_id},
            PLACE_OF_STOP         => $value_of_r->{tpat_stp_plc},
            PLACESEQUENCE_OF_STOP => $value_of_r->{tpat_stp_tp_sequence},
        };

        $patterns{$key}{PLACES}{ $value_of_r->{tpat_stp_tp_sequence} }
          = $value_of_r->{tpat_stp_plc};

    }

    emit_done;

    return %patterns;

} ## tidy end: sub get_patterns
__END__

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

            $patterns{$key}{DIRECTION} = $direction;

        }

    } ## tidy end: foreach my $file ( @{ $files_of_r...})

    emit_done;

    emit 'Reading THEA trippatternstops files';

    foreach my $file ( @{ $files_of_r->{'trippatternstops'} } ) {

        emit_over $file;
        my ( $fh, @headers )
          = open_thea_file( $file, 'trippatternstops', $theafolder );

        while (<$fh>) {
            trim;

            my %patvalue_of;
            @patvalue_of{@headers} = split("\t");

            my $key
              = "$patvalue_of{'item tpat_route'}:$patvalue_of{'item tpat_id'}";

            next unless exists $patterns{$key};

            $patterns{$key}{STOPS}[ $patvalue_of{tpat_stp_rank} ] = {
                STOPID                => $patvalue_of{stp_511_id},
                PLACE_OF_STOP         => $patvalue_of{tpat_stp_plc},
                PLACESEQUENCE_OF_STOP => $patvalue_of{tpat_stp_tp_sequence},
            };

            $patterns{$key}{PLACES}{ $patvalue_of{tpat_stp_tp_sequence} }
              = $patvalue_of{tpat_stp_plc};

        } ## tidy end: while (<$fh>)

    } ## tidy end: foreach my $file ( @{ $files_of_r...})

    emit_done;

    return %patterns;

} ## tidy end: sub get_patterns

sub get_file_names {
    emit 'Assembling list of THEA files';

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
    my $line    = trim( scalar(<$fh>) );
    my @headers = split( "\t", $line );

    foreach my $required_header ( @{ $required_headers{$filetype} } ) {
        if ( not $required_header ~~ @headers ) {
            die "Required header $required_header not found in file $file";
        }

    }

    return $fh, @headers;

}

__END__

