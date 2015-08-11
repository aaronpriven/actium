# Actium/Cmd/TimetableMatrixText.pm

# Reads the timetable matrix and produces text for it.

package Actium::Cmd::TimetableMatrixText 0.010;

use warnings;
use 5.016;

use Actium::Preamble;
use Actium::O::Folder;
use Actium::Sorting::Line('sortbyline');
use Text::Trim ('trim');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
Reads a timetable matrix file specified on the command line and outputs
the appropriate text.
HELP

    return;
}

my %factor_of;

sub START {
    my ( $class, $env ) = @_;
    my @argv = $env->argv;

    my $filespec = shift @argv;
    die "No input file given" unless $filespec;

    my ( $folder,   $filename ) = Actium::O::Folder->new_from_file($filespec);
    my ( $filepart, $fileext )  = u::file_ext($filespec);

    my $sheet = $folder->load_sheet($filename);

    $sheet->prune_space;

    my @tt_names = $sheet->shift_row;
    s#\s+#/#g foreach @tt_names;    # spaces to slash
    s#/+#/#g  foreach @tt_names;    # consecutive slashes to one slash

    my @columns_to_use = $sheet->shift_row;

    my %timetables_of;
    my %each_of;

    my %centers_of;

    my $type = ' BART';

  ROW:
    foreach my $row_r ( @{$sheet} ) {
        my @entries = @{$row_r};
        my $center  = $entries[0];
        next unless $center;

        my $each = $entries[1];

        if ( not $each ) {
            if ( $center =~ /LIBRARIES/ ) {
                $type = ' Library';
            }
            elsif ( $center =~ /BART/ ) {
                $type = ' BART',;
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
        my $group;

        foreach my $idx ( 2 .. $#entries ) {
            my $entry = $entries[$idx];
            next unless $entry;

            $entry =~ s/\s+//;    # remove spaces
            $entry = 1 unless $entry =~ /\A[0-9.]+\z/;
            next if $entry == 0;

            my $tt_name = $tt_names[$idx];
            $factor_of{"$center\0$tt_name"} = $entry;

            my $thisgroup = uc( $columns_to_use[$idx] );

            next if not $thisgroup;

            $group = $thisgroup if ( not $group ) or $group gt $thisgroup;

            push @timetables, $tt_name;
            push @{ $centers_of{$tt_name} }, $center;

        } ## tidy end: foreach my $idx ( 2 .. $#entries)

        next ROW if not @timetables;

        $timetables_of{$group}{$center} = \@timetables;

        $each_of{$center} = $each;

    } ## tidy end: ROW: foreach my $row_r ( @{$sheet...})

    my $numgroups = scalar keys %timetables_of;

    my $outfile = "$filepart-centers.txt";
    my $textfh  = $folder->open_write($outfile);

    foreach my $group ( sort keys %timetables_of ) {

        foreach my $center ( sort keys %{ $timetables_of{$group} } ) {

            my @timetables = @{ $timetables_of{$group}{$center} };
            my $each       = $each_of{$center};
            next unless scalar @timetables;
            my $total = 0;

            my $grouptext = $numgroups > 1 ? " (Group $group)" : $EMPTY;

            my %tts_of_quantity;
            my %quantity_of;
            foreach my $tt_name (@timetables) {
                my $quantity = quantity( $center, $tt_name, $each );
                $quantity_of{$tt_name} = $quantity;
                push @{ $tts_of_quantity{$quantity} }, $tt_name;
                $total += $quantity;
            }

            say $textfh "$center.$grouptext Weight: _________________________";

            if ( 1 == scalar keys %tts_of_quantity ) {
                print $textfh "$each of these timetables: ";
                print $textfh u::joinseries_ampersand(@timetables), " ";
            }
            else {

                my @tt_texts = map {"$quantity_of{$_} of $_"} @timetables;
                print $textfh "These timetables: ";

                my @all_quantities = sort { $a <=> $b } keys %tts_of_quantity;
                foreach my $quantity (@all_quantities) {
                    print $textfh "$quantity each of ";
                    my @thesetts = @{ $tts_of_quantity{$quantity} };

                    print $textfh u::joinseries_ampersand(@thesetts), ". ";

                }

            }
            print $textfh "(total: $total)\n\n";

        } ## tidy end: foreach my $center ( sort keys...)

    } ## tidy end: foreach my $group ( sort keys...)
    close $textfh or die "Can't close $outfile: $!";

    my $ttlistfile = "$filepart-ttlist.txt";

    my $listfh = $folder->open_write($ttlistfile);

    foreach my $timetable ( sortbyline keys %centers_of ) {
        my @centers = @{ $centers_of{$timetable} };
        say $listfh "Timetable for $timetable:";

        foreach my $center (@centers) {

            my $quantity = quantity( $center, $timetable, $each_of{$center} );
            say $listfh "$center: $quantity";
        }
        print $listfh "\n";
    }

} ## tidy end: sub START

sub quantity {
    my ( $center, $tt_name, $each ) = @_;

    my $factor = $factor_of{"$center\0$tt_name"} // 1;
    my $quantity = u::ceil( $factor * $each );

    return $quantity;

}

1;
