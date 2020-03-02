package Octium::Cmd::TimetableMatrixText 0.011;

# Reads the timetable matrix and produces text for it.

use Actium;
use Octium;
use Octium::O::Folder;
use Text::Trim ('trim');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
Reads a timetable matrix file specified on the command line and outputs
the appropriate text.
HELP

    return;
}

my %factor_of;

my %color_text = (
    BWY => 'white, blue and yellow',
    BW  => 'white and blue',
    BY  => 'blue and yellow,',
    WY  => 'white and yellow',
    B   => 'blue',
    Y   => 'yellow',
    W   => 'white',
);

sub START {
    my @argv = env->argv;

    my $filespec = shift @argv;
    die "No input file given" unless $filespec;

    my ( $folder,   $filename ) = Octium::O::Folder->new_from_file($filespec);
    my ( $filepart, $fileext )  = Octium::file_ext($filespec);

    my $sheet = $folder->load_sheet($filename);

    $sheet->prune_space;

    my @tt_names = $sheet->shift_row;
    s#\s+#/#g foreach @tt_names;    # spaces to slash
    s#/+#/#g  foreach @tt_names;    # consecutive slashes to one slash

    my @groups = $sheet->shift_row;

    #my @colors = $sheet->shift_row;

  #foreach my $column_idx ( 0 .. $#colors ) {
  #
  #    my $colors
  #      = join( $EMPTY, grep {/[A-Z]/} ( split( //, $colors[$column_idx] ) ) );
  #
  #    #say "$column_idx $colors[$column_idx] $colors";
  #
  #    next unless $colors;
  #
  #    my $color_text
  #      = exists $color_text{$colors}
  #      ? $color_text{$colors}
  #      : $colors;
  #    $tt_names[$column_idx] .= " $color_text";
  #}

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

            my $thisgroup = uc( $groups[$idx] );

            next if not $thisgroup;

            $group = $thisgroup if ( not $group ) or $group gt $thisgroup;

            push @timetables, $tt_name;
            push @{ $centers_of{$tt_name} }, $center;

        }    ## tidy end: foreach my $idx ( 2 .. $#entries)

        next ROW if not @timetables;

        $timetables_of{$group}{$center} = \@timetables;

        $each_of{$center} = $each;

    }    ## tidy end: ROW: foreach my $row_r ( @{$sheet...})

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

            print $textfh
              "$center.$grouptext Weight: _________________________\\r";

            if ( 1 == scalar keys %tts_of_quantity ) {
                print $textfh "$each of these timetables: ";
                print $textfh Actium::joinseries(
                    conjunction => '&',
                    items       => \@timetables
                  ),
                  " ";
            }
            else {

                my @tt_texts = map {"$quantity_of{$_} of $_"} @timetables;
                print $textfh "These timetables: ";

                my @all_quantities = sort { $a <=> $b } keys %tts_of_quantity;
                foreach my $quantity (@all_quantities) {
                    print $textfh "$quantity each of ";
                    my @thesetts = @{ $tts_of_quantity{$quantity} };

                    print $textfh Actium::joinseries(
                        conjunction => '&',
                        items       => \@thesetts
                      ),
                      ". ";

                }

            }
            print $textfh "(total: $total)\n\n";

        }    ## tidy end: foreach my $center ( sort keys...)

    }    ## tidy end: foreach my $group ( sort keys...)
    close $textfh or die "Can't close $outfile: $!";

    my $ttlistfile = "$filepart-ttlist.txt";

    my $listfh = $folder->open_write($ttlistfile);

    foreach my $timetable ( Actium::sortbyline keys %centers_of ) {
        my @centers = @{ $centers_of{$timetable} };
        say $listfh "Timetable for $timetable:";

        foreach my $center (@centers) {

            my $quantity = quantity( $center, $timetable, $each_of{$center} );
            say $listfh "$center: $quantity";
        }
        print $listfh "\n";
    }

}    ## tidy end: sub START

sub quantity {
    my ( $center, $tt_name, $each ) = @_;

    my $factor = $factor_of{"$center\0$tt_name"} // 1;
    my $quantity = Actium::ceil( $factor * $each );

    return $quantity;

}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

