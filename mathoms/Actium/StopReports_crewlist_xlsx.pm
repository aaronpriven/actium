# exerpted from Actium::StopReports

##################################################################
### CREW LIST

__END__
to avoid Eclipse errors

const my @HEADERS    => (qw/Group Order StopID Location Decals/);
const my $PAPER_SIZE => 1;                                          # letter

const my @COLUMN_WIDTHS => 6.5, 7.5, 5.5, 47.5, 14;

sub crewlist_xlsx {

    my %params = u::validate(
        @_,
        {   actiumdb         => { can  => 'all_in_columns_key' },
            outputfile       => { type => $PV_TYPE{SCALAR} },
            stops_of_linedir => { type => $PV_TYPE{HASHREF} },
            signup_display =>
              { type => $PV_TYPE{SCALAR}, default => $EMPTY },
        }
    );
    my $actiumdb       = $params{actiumdb};
    my $signup_display = $params{signup_display};

    my $promote_lines_r = $actiumdb->all_in_column_key(
        {   TABLE  => 'Lines',
            COLUMN => 'crewlist_promote',
            WHERE  => q{Active = 'Yes' AND crewlist_promote = 1},
        }
    );

    my @promote_lines = sortbyline keys %{$promote_lines_r};

    my $stops_r = $actiumdb->all_in_columns_key(
        {   TABLE   => 'Stops_Neue',
            COLUMNS => [qw/c_description_fullabbr c_crew_assignment p_decals/],
            WHERE   => 'p_active = 1',
        }
    );

    my %stops_of_assignment;

    foreach my $stopid ( keys %{$stops_r} ) {
        my $stop_record = $stops_r->{$stopid};
        next if not defined $stop_record->{c_crew_assignment};
        next if $stop_record->{c_description_fullabbr} =~ /Virtual/i;
        my $crew_assignment = $stop_record->{c_crew_assignment};
        push @{ $stops_of_assignment{$crew_assignment} }, $stopid;
    }

    my $outputfile = $params{outputfile};
    $outputfile .= '.xlsx' unless $outputfile =~ /[.]xlsx\z/si;

    my $workbook = Excel::Writer::XLSX->new($outputfile);

    my @common_formats = ( valign => 'top', num_format => '@' );
    my $data_format = $workbook->add_format( text_wrap => 1, @common_formats );
    my $header_format = $workbook->add_format( bold => 1, @common_formats );

    foreach my $crew_assignment ( sort keys %stops_of_assignment ) {

        my @travelsorted = travelsort(
            stops            => $stops_of_assignment{$crew_assignment},
            stops_of_linedir => $params{stops_of_linedir},
            promote          => \@promote_lines,
            demote600s       => 1,
        );

        #@sorted = sort { $a->[0] cmp $b->[0] } @sorted;

        my @to_line_sort;
        foreach my $linedir_and_stops (@travelsorted) {
            my $linedir = $linedir_and_stops->[0];
            my ( $line, $dir ) = split( /-/, $linedir );
            push @to_line_sort, [ $linedir_and_stops, linekeys($line), $dir ];
        }

        # creates new array @to_line_sort, where first element is ref to
        # original array, second element is the line to be sorted,
        # third element is the direction to be sorted

        @to_line_sort
          = sort { $a->[1] cmp $b->[1] or $a->[2] cmp $b->[2] } @to_line_sort;

        # sort that, first by the line, then by the direction

        my @sorted = map { $_->[0] } @to_line_sort;

        # make @sorted just the original arrays
        # So this is basically an exploaded Schwarzian transform

        #@sorted = map { $_->[0] }
        #  sort { $a->[1] cmp $b->[1] }
        #  map { [ $_, linekeys( $_->[0] ) ] } @sorted;

        my @output_stops;

        while ( my $ref = shift @sorted ) {
            my ( $linedir, @stops ) = @{$ref};
            my $numstops = scalar @stops;
            foreach my $i ( 1 .. $numstops ) {
                my $stopid = $stops[ $i - 1 ];
                my $decals = u::define( $stops_r->{$stopid}{p_decals} );
                $decals =~ s/-/\x{2011}/g;

                push @output_stops,
                  [ $linedir, "$i of $numstops",
                    $stopid,  $stops_r->{$stopid}{c_description_fullabbr},
                    $decals,
                  ];

            }
        }

        my $sheet = $workbook->add_worksheet("Assignment $crew_assignment");

        $sheet->write_row( 0, 0, \@HEADERS, $header_format );
        $sheet->write_col( 1, 0, \@output_stops, $data_format );

        for my $column ( 0 .. @COLUMN_WIDTHS ) {
            $sheet->set_column( $column, $column, $COLUMN_WIDTHS[$column] );
        }

        $sheet->set_page_view;
        $sheet->set_paper($PAPER_SIZE);
        $sheet->set_header("&LAssignment #$crew_assignment");
        $sheet->set_footer("&L&D&C$signup_display&R&P of &N");
        $sheet->repeat_rows(0);
        $sheet->hide_gridlines(0);

    } ## tidy end: foreach my $crew_assignment...

    for my $worksheet ( $workbook->sheets() ) {

    }

    return $workbook->close;

} ## tidy end: sub crewlist_xlsx

