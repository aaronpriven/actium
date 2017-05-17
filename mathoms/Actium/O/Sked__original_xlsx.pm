__END__

### ORIGINAL XLSX SCHEDULES ###

const my $xlsx_window_height => 950;
const my $xlsx_window_width  => 1200;

sub xlsx {
    my $self = shift;
    my $timesub = timestr_sub( XB => 1 );

    #require Excel::Writer::XLSX;    ### DEP ###
    require Actium::Excel;

    my $outdata;
    open( my $out, '>', \$outdata ) or die "$!";

    my $workbook = Excel::Writer::XLSX->new($out);
    $workbook->set_size( $xlsx_window_width, $xlsx_window_height );

    my $textformat = $workbook->add_format( num_format => 0x31 );    # text only

    ### INTRO

    my $intro = $workbook->add_worksheet('intro');

    my @all_attributes   = qw(id sortable_days dircode linegroup md5);
    my @all_output_names = qw(id days dir linegroup md5);

    my @output_names;
    my @output_values;

    foreach my $i ( 0 .. $#all_attributes ) {
        my $output_name = $all_output_names[$i];
        my $attribute   = $all_attributes[$i];
        my $value       = $self->$attribute;

        if ( defined $value ) {
            push @output_names,  $output_name;
            push @output_values, $value;
        }
    }

    $intro->actium_write_col_string( 0, 0, \@output_names,  $textformat );
    $intro->actium_write_col_string( 0, 1, \@output_values, $textformat );

    ### TPSKED

    my $tpsked = $workbook->add_worksheet('tpsked');

    my @place_records;

    my ( $columns_r, $shortcol_of_r )
      = $self->attribute_columns(qw(line day vehicletype daysexceptions));
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    push @place_records, [ ($EMPTY_STR) x scalar @columns, $self->place4s ];
    push @place_records, [ @shortcol_of{@columns}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        push @place_records,
          [ ( map { $trip->$_ } @columns ), $timesub->( $trip->placetimes ) ];
    }

    $tpsked->actium_write_col_string( 0, 0, \@place_records, $textformat );
    $tpsked->freeze_panes( 2, 0 );
    $tpsked->set_zoom(125);

    ### STOPSKED

    my $stopsked = $workbook->add_worksheet('stopsked');

    my @stop_records;

    push @stop_records, [ $self->stopids ];
    push @stop_records, [ $self->stopplaces ];

    foreach my $trip (@trips) {
        push @stop_records, [ $timesub->( $trip->stoptimes ) ];
    }

    $stopsked->actium_write_row_string( 0, 0, \@stop_records, $textformat );
    $stopsked->freeze_panes( 0, 2 );

    $tpsked->activate();

    $workbook->close();
    close $out;
    return $outdata;

} ## tidy end: sub xlsx

sub xlsx_layers {':raw'}
