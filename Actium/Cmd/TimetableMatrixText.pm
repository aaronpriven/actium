# Actium/Cmd/TimetableMatrixText.pm

# Reads the timetable matrix and produces text for it.

# Subversion: $Id$

package Actium::Cmd::TimetableMatrixText 0.009;

use warnings;
use 5.016;

use Actium::Preamble;
use Actium::Util('joinseries_ampersand');
use Actium::O::Folder;
use Actium::Sorting::Line('sortbyline');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
Reads a timetable matrix file specified on the command line and outputs
the appropriate text.
HELP

    Actium::Term::output_usage();

    return;
}

sub START {
    my $class = shift;

    my %params = @_;

    my @argv = @{ $params{argv} };

    my $filespec = shift @argv;
    die "No input file given" unless $filespec;

    my ( $folder, $filename ) = Actium::O::Folder->new_from_file($filespec);

    my $sheet = $folder->load_sheet($filename);

    $sheet->prune_space;

    my @headers = $sheet->shift_row;
    s#\s+#/#g foreach @headers;
    s#/+#/#g  foreach @headers;

    my @columns_to_use = $sheet->shift_row;

    my %timetables_of;
    my %notready_timetables_of;
    my %each_of;

    my %centers_of;

    my $type = ' BART';

    foreach my $row_r ( @{$sheet} ) {
        my @entries = @{$row_r};
        my $center  = $entries[0];
        next unless $center;

        my $each = $entries[1];

        if ( not $each ) {
            if ( $center =~ /LIBRARIES/ ) {
                $type = ' Library';
            }
            else {
                $type = '';
            }

            next;
        }
        
        $center = "$center$type";

        #my $done = $entries[-1];
        #next if $done;

        my @timetables;
        my $notready;

        foreach my $idx ( 2 .. $#entries ) {
            next unless $entries[$idx] eq 'X';
            $notready = 1 if $columns_to_use[$idx] ne 'X';
            next unless $headers[$idx] ne '?';
            push @timetables, $headers[$idx];

            push @{ $centers_of{ $headers[$idx] } }, $center;
        }

        unless ($notready) {
            $timetables_of{$center} = \@timetables;
        }
        else {
            $notready_timetables_of{$center} = \@timetables;
        }
        $each_of{$center} = $each;

    }

    foreach my $center ( ( sort keys %timetables_of ),
        ( sort keys %notready_timetables_of ) )
    {
        my @timetables =
          @{ $timetables_of{$center} || $notready_timetables_of{$center} };
        my $each  = $each_of{$center};
        my $total = $each * scalar @timetables;
        next unless scalar @timetables;

        say "$center. Weight: _________________________";
        print "$each of these timetables: ";
        @timetables = 'None' unless @timetables;
        print joinseries_ampersand (@timetables), " (total: $total)\n\n";

    }

    say "\n";

    foreach my $timetable ( sortbyline keys %centers_of ) {
        my @centers = @{ $centers_of{$timetable} };
        say "Timetable for $timetable:";

        foreach my $center (@centers) {
            unless ($each_of{$center} <100) {
            say "$center: $each_of{$center}";
            }
        }
        say "\n";

    }

}    ## tidy end: sub START

1;
