# /Actium/Cmd/CustomDecalCount.pm
#
# Makes spreadsheet to calculate decal count

# Subversion: $Id$

package Actium::Cmd::CustomDecalCount 0.008;

use Actium::Preamble;
use Actium::Sorting::Line         ('sortbyline');
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use File::Spec;
use File::Basename;
use Spreadsheet::ParseXLSX;
use Excel::Writer::XLSX;
use Excel::Writer::XLSX::Utility;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my $actium_db = actiumdb($config_obj);

    my ( $input_file, $output_file ) = get_paths( $params{argv} );

    my %lines_of = %{ read_input_xlsx($input_file) };

    my $db_decals_of_r = $actium_db->all_in_column_key(qw/Stops_Neue p_decals/);

    my ( $decals_of_r, $found_decals_of_r ) =
      figure_decals( \%lines_of, $db_decals_of_r );

    my $count_of_r = count_decals($found_decals_of_r);

    write_xlsx(
        output_file     => $output_file,
        decals_of       => $decals_of_r,
        found_decals_of => $found_decals_of_r,
        count_of        => $count_of_r
    );

    return;

}

sub write_xlsx {
    my %params          = @_;
    my $output_file     = $params{output_file};
    my %decals_of       = %{ $params{decals_of} };
    my %found_decals_of = %{ $params{found_decals_of} };
    my %count_of        = %{ $params{count_of} };

    my $workbook    = Excel::Writer::XLSX->new($output_file);
    my $count_sheet = $workbook->add_worksheet('Count');
    my $stop_sheet  = $workbook->add_worksheet('Stops');

    my $text_format = $workbook->add_format( num_format => '@' );

    my @decals = sortbyline keys %count_of;

    $count_sheet->write_row( 0, 0, [ 'Decal', '# stops', '# to print' ] );

    foreach my $idx ( 0 .. $#decals ) {
        my $decal      = $decals[$idx];
        my $stops_cell = xl_rowcol_to_cell( $idx + 1, 1 );
        my $formula    = "=CEILING($stops_cell*2.1,1)";
        my $row        = $idx + 1;
        $count_sheet->write_string( $row, 0, $decal, $text_format );
        $count_sheet->write_number( $row, 1, $count_of{$decal} );
        $count_sheet->write_formula( $row, 2, $formula );

    }

    my $start_sum = xl_rowcol_to_cell( 1, 2 );
    my $end_sum = xl_rowcol_to_cell( scalar @decals, 2 );
    my $sumformula = "=SUM($start_sum:$end_sum)";
    $count_sheet->write_formula( 1+ scalar @decals, 2, $sumformula );

    $stop_sheet->write_row( 0, 0,
        [ 'Stop ID', 'Decals to use', 'All decals' ] );

    my @stopids = sort keys %decals_of;

    foreach my $row ( 1 .. @stopids ) {
        my $stopid = $stopids[ $row - 1 ];
        my @items  = (
            $stopid,
            join( " ", @{ $found_decals_of{$stopid} } ),
            join( " ", @{ $decals_of{$stopid} } )
        );

        for my $col ( 0 .. @items ) {
            $stop_sheet->write( $row, $col, $items[$col], $text_format );
        }
    }

    return $workbook->close();

}

sub count_decals {

    my %found_decals_of = %{ +shift };

    my %count_of;

    foreach my $stopid ( keys %found_decals_of ) {
        my @decals = @{ $found_decals_of{$stopid} };

        $count_of{$_}++ foreach @decals;
    }

    return \%count_of;

}

sub figure_decals {

    my %lines_of       = %{ +shift };
    my $db_decals_of_r = shift;

    my ( %decals_of, %found_decals_of );

    foreach my $stopid ( sort keys %lines_of ) {

        my $decals = $db_decals_of_r->{$stopid} // $EMPTY_STR;
        my ( @decals, @found_decals, @lines );
        @decals = split( /\s+/, $decals );

        if ( $lines_of{$stopid} ) {

            @lines = split( /[\W_]/, $lines_of{$stopid} );

          DECAL:
            foreach my $decal (@decals) {
                foreach my $line (@lines) {

                    if ( $decal =~ /\A$line-/ ) {
                        push @found_decals, $decal;
                        next DECAL;
                    }

                }

            }

        }
        else {
            @found_decals = @decals;
        }

        $decals_of{$stopid}       = \@decals;
        $found_decals_of{$stopid} = \@found_decals;

    }

    return ( \%decals_of, \%found_decals_of );

}    ## tidy end: sub START

sub get_paths {

    my $argv_r     = shift;
    my $input_path = shift @{$argv_r};

    my ( $volume, $folders, $input_name ) = File::Spec->splitpath($input_path);

    my ( $basename, undef, $suffix ) =
      fileparse( $input_name, qr/(?i:\.xlsx)/ );

    my $output_path =
      File::Spec->catpath( $volume, $folders, "$basename-counted$suffix" );

    return ( $input_path, $output_path );
}

sub read_input_xlsx {

    my $input_file = shift;

    my $parser   = Spreadsheet::ParseXLSX->new;
    my $workbook = $parser->parse($input_file);

    my $sheet = $workbook->worksheet(0);

    if ( !defined $workbook ) {
        die $parser->error(), ".\n";
    }

    my ( $minrow, $maxrow ) = $sheet->row_range();
    my ( $mincol, $maxcol ) = $sheet->col_range();

    my (%lines_of);

    foreach my $row ( $minrow .. $maxrow ) {

        my @cells =
          map { $sheet->get_cell( $row, $_ ) } $mincol, $mincol + 1;

        foreach (@cells) {
            if ( defined $_ ) {
                $_ = $_->value;
            }
            else {
                $_ = $EMPTY_STR;
            }
        }

        my ( $stopid, $lines ) = @cells;
        next if $stopid !~ /\d+/;

        $lines_of{$stopid} = $lines;

    }

    return \%lines_of;
}

1;

__END__
