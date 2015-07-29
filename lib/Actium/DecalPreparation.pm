# /Actium/DecalPreparation.pm
#
# Routines for decal preparation.

package Actium::DecalPreparation 0.010;

use Actium::Preamble;
use Actium::Sorting::Line ('sortbyline');
use Actium::O::2DArray;
use Excel::Writer::XLSX; ### DEP ###
use Excel::Writer::XLSX::Utility; ### DEP ###
use Actium::Util(qw[folded_in joinseries_ampersand]);

use Sub::Exporter -setup => {
    exports => [
        qw(
          make_decal_count   make_labels
          write_decalcount_xlsx
          count_decals decals_of_stop read_decal_list
          )
    ]
};
# Sub::Exporter ### DEP ###

sub make_labels {
    my ( $input_file, $output_file, $actium_db ) = @_;

    my $in_sheet          = Actium::O::2DArray->new_from_file($input_file);
    my $lines_of_r        = $in_sheet->hash_of_row_elements( 0, 1 );
    my $instructions_of_r = $in_sheet->hash_of_row_elements( 0, 3 );
    my $db_decals_of_r = $actium_db->all_in_column_key(qw/Stops_Neue p_decals/);
    my $desc_of_r =
      $actium_db->all_in_column_key(qw/Stops_Neue c_description_fullabbr/);
   my $assignment_of_r = $actium_db->all_in_column_key(qw/Stops_Neue c_crew_assignment/);

    my ( $decals_of_r, $found_decals_of_r ) =
      decals_of_stop( $lines_of_r, $db_decals_of_r );

    my @labels;
    foreach my $stopid ( sort keys %{$lines_of_r} ) {

        my $instructions = $instructions_of_r->{$stopid};
        my $desc         = $desc_of_r->{$stopid};
        my $assignment = $assignment_of_r->{$stopid};

        if ( not $desc ) {
            next if folded_in( $stopid => 'id', 'stop id', 'stopid' );
            $desc = '[NO DESCRIPTION FOUND]';
        }

        my @found_all = @{ $found_decals_of_r->{$stopid} };
        my @found_custom = grep { m/-/ } @found_all;
        my $all_list =
          @found_all
          ? joinseries_ampersand(@found_all)
          : '(NO DECALS FOUND)';
        my $custom_list =
          @found_custom
          ? joinseries_ampersand(@found_custom)
          : '(NO CUSTOM DECALS FOUND)';
          
        $instructions =~ s/%c/$custom_list/;
        $instructions =~ s/%d/$all_list/;
          
        if ( not $instructions or $instructions =~ /\A\&/ ) {

            my $originstructions = $instructions;

            my $decal_pluralized = @found_custom > 1 ? 'decals' : 'decal';
                $instructions = "Replace generic $decal_pluralized with $custom_list";

                if ( @found_custom < @{ $decals_of_r->{$stopid} } ) {
                    $instructions .= ". Leave other decals";
                }

            if ($originstructions) {
                $originstructions =~ s/^\&\s*//;
                $instructions .= ". $originstructions";
            }

        }
        elsif ( $instructions eq 'P' ) {
            my $decal_pluralized = @found_all > 1 ? 'decals' : 'decal';
            $instructions =
                "Place $decal_pluralized $all_list on the flag";
        }

        push @labels, "[Crew area $assignment] $stopid   $desc\n$instructions";

    }

    my $out_sheet = Actium::O::2DArray->new_across( 2, @labels );
    $out_sheet->ins_col( 1, ($SPACE) x scalar @{$out_sheet});

    # blank column for space in the mdidle of the label

    my $format = { valign => 'vcenter' };

    return $out_sheet->xlsx( output_file => $output_file, format => $format );

}

sub make_decal_count {

    my ( $input_file, $output_file, $actium_db ) = @_;

    my $lines_of_r = Actium::O::2DArray->new_from_file($input_file)
      ->hash_of_row_elements( 0, 1 );

    # stop ID column, lines column

    my $db_decals_of_r = $actium_db->all_in_column_key(qw/Stops_Neue p_decals/);

    my ( $decals_of_r, $found_decals_of_r ) =
      decals_of_stop( $lines_of_r, $db_decals_of_r );

    my $count_of_r = count_decals($found_decals_of_r);

    write_decalcount_xlsx(
        output_file     => $output_file,
        decals_of       => $decals_of_r,
        found_decals_of => $found_decals_of_r,
        count_of        => $count_of_r
    );

    return;

}

sub write_decalcount_xlsx {
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

    my @columntypes = (qw[Decal Print Stops Adjust]);
    $count_sheet->write_row( 0, 0, \@columntypes );

    my %column_num_of;
    for my $col ( 0 .. $#columntypes ) {
        my $columntype = $columntypes[$col];
        $column_num_of{$columntype} = $col;
    }

    foreach my $idx ( 0 .. $#decals ) {
        my $row = $idx + 1;
        my %celladdr_of;
        for my $columntype (@columntypes) {
            my $col = $column_num_of{$columntype};
            $celladdr_of{ $columntypes[$col] } =
              xl_rowcol_to_cell( $row, $col );
        }

        my $formula =
          "=CEILING( $celladdr_of{Stops}*2.1 + $celladdr_of{Adjust} , 1)";

        my $decal = $decals[$idx];
        $count_sheet->write_string( $celladdr_of{Decal}, $decal, $text_format );
        $count_sheet->write_formula( $celladdr_of{Print}, $formula );
        $count_sheet->write_number( $celladdr_of{Stops},  $count_of{$decal} );
        $count_sheet->write_number( $celladdr_of{Adjust}, 0 );

    }

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

    my $start_sum = xl_rowcol_to_cell( 1, $column_num_of{Print} );
    my $end_sum = xl_rowcol_to_cell( scalar @decals, $column_num_of{Print} );
    my $sumformula = "=SUM($start_sum:$end_sum)";
    $count_sheet->write_formula( 1 + scalar @decals,
        $column_num_of{Print}, $sumformula );

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

sub decals_of_stop {

    my %lines_of       = %{ +shift };
    my $db_decals_of_r = shift;

    my ( %decals_of, %found_decals_of );

    foreach my $stopid ( sort keys %lines_of ) {

        my $decals = $db_decals_of_r->{$stopid} // $EMPTY_STR;

        next
          if $decals eq $EMPTY_STR
          and folded_in( $stopid => 'id', 'stop id', 'stopid' );

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

1;

__END__
