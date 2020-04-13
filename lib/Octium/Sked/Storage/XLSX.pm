package Octium::Sked::Storage::XLSX 0.013;

use Actium ('role');
use Octium;
use Array::2D;

use Octium::Sked::Trip;
use Octium::Dir;
use Octium::Days;
use Actium::Time;

#############################################
#### READ FROM AN EXCEL SPREADSHEET

method new_from_xlsx ( $class : Str : $file,
    Spreadsheet::ParseExcel::Worksheet : $sheet ) {

    if ( $file and $sheet ) {
        croak 'Can only pass one of either a file or a worksheet object '
          . "to $class->new_from_xlsx";
    }
    if ( not $file and not $sheet ) {
        croak 'Must pass either a file or a worksheet object '
          . "to $class->new_from_xlsx";
    }

    if ($file) {
        require Spreadsheet::ParseXLSX;
        my $parser   = Spreadsheet::ParseXLSX->new;
        my $workbook = $parser->parse($file);
        $sheet = $workbook->worksheet(0);
    }

    my $id = $sheet->get_name;
    my ( $linegroup, $dircode, $daycode )
      = _process_id( id => $id, filename => $file );

    my ( $minrow, $maxrow ) = $sheet->row_range();
    my ( $mincol, $maxcol ) = $sheet->col_range();

    my $is_stopid_col_cr = func( Int $col! ) {
        my $cell = $sheet->get_cell( $minrow, $col );
        return 0 if not defined $cell;
        my $value = $cell->value;
        return 0 if $value =~ /\A \s* \z/x;
        return 1;
    };

    my $min_stop_col
      = Actium::first { $is_stopid_col_cr->($_) } ( $mincol .. $maxcol );

    \my ( @stops, @place4s, @stopplaces ) = _read_stops_and_places(
        mincol    => $min_stop_col,
        maxcol    => $maxcol,
        stop_row  => $minrow,
        place_row => $minrow + 1,
        sheet     => $sheet,
        filename  => $file,
    );

    \my @attributes = _read_attribute_names(
        mincol => $mincol,
        maxcol => $min_stop_col - 1,
        row    => $minrow + 1,
        id     => $id,
        sheet  => $sheet,
    );

    my $trips_r = _read_trips(
        sheet        => $sheet,
        mincol       => $mincol,
        maxcol       => $maxcol,
        minrow       => $minrow + 2,
        maxrow       => $maxrow,
        min_stop_col => $min_stop_col,
        attributes   => \@attributes,
    );

    my $dir_obj = Octium::Dir->instance($dircode);
    my $day_obj = Octium::Days->instance( $daycode, 'B' );

    my $actiumdb = env->actiumdb;
    my @place8s  = map { $actiumdb->place8($_) } @place4s;

    my $sked = $class->new(
        place4_r    => \@place4s,
        place8_r    => \@place8s,
        stopplace_r => \@stopplaces,
        stopid_r    => \@stops,
        linegroup   => $linegroup,
        direction   => $dir_obj,
        trip_r      => $trips_r,
        days        => $day_obj,
    );

    return $sked;

}    ## tidy end: method new_from_xlsx

func _cell_value ( $sheet !, Int $row!, Int $col! ) {
    my $cell = $sheet->get_cell( $row, $col );
    return $EMPTY unless defined $cell;
    return $cell->value;
}

func _cell_time ( $sheet !, Int $row!, Int $col! ) {
    my $cell = $sheet->get_cell( $row, $col );
    return $EMPTY unless defined $cell;
    my $time = Actium::Time->from_excel($cell);
    return $time->timenum;
}

func _read_stops_and_places (
    Int : $mincol !,
    Int : $maxcol !,
    Int : $stop_row !,
    Int : $place_row !,
    : $sheet !,
    Str : $filename !,
  ) {

    my ( @stops, @places, @stopplaces );
    for my $col ( $mincol .. $maxcol ) {
        my $stop = _cell_value( $sheet, $stop_row, $col );
        croak "Blank stop ID column found in $filename, column $col. Halting."
          if $stop eq $EMPTY;
        push @stops, $stop;

        my $place = _cell_value( $sheet, $place_row, $col );

        if ( $place eq $EMPTY ) {
            push @stopplaces, undef;
        }
        else {
            push @stopplaces, $place;
            push @places,     $place;
        }
    }

    return \@stops, \@places, \@stopplaces;

}    ## tidy end: func _read_stops_and_places

func _read_trips (
    Spreadsheet::ParseExcel::Worksheet : $sheet !,
    Int                                : $mincol !,
    Int                                : $maxcol !,
    Int                                : $minrow !,
    Int                                : $maxrow !,
    Int                                : $min_stop_col !,
    : @attributes is ref_alias,
  ) {

    my @trips;
    foreach my $row ( $minrow .. $maxrow ) {

        my %trip;
        foreach my $col ( $mincol .. $min_stop_col - 1 ) {
            my $attribute = $attributes[$col];
            next if $EMPTY eq $attribute;
            $trip{$attribute} = _cell_value( $sheet, $row, $col );
        }

        #if ( exists $trip{DAY} ) {
        #    my $day_string = delete $trip{DAY};
        #    $trip{days}
        #      = Octium::Days->instance_from_string($day_string);
        #}

        $trip{stoptime_r}
          = [ map { _cell_time( $sheet, $row, $_ ) } $min_stop_col .. $maxcol ];

        my $trip_obj = Octium::Sked::Trip->new(%trip);

        push @trips, $trip_obj;

    }    ## tidy end: foreach my $row ( $minrow .....)

    return \@trips;

}    ## tidy end: func _read_trips

func _read_attribute_names (
    Int : $mincol !,
    Int : $maxcol !,
    Int : $row !,
    : $sheet !,
    Str : $id !,
  ) {

    my @attributes;
    foreach my $col ( $mincol .. $maxcol ) {

        my $shortcol = _cell_value( $sheet, $row, $col );
        my $attribute;
        if ( $EMPTY eq $shortcol ) {
            carp "Blank column # $col in $id ignored";
            $attribute = $EMPTY;
        }
        elsif ( 'DAY' eq $shortcol ) {
            $attribute = 'days';
        }
        else {

            $attribute
              = Octium::Sked::Trip->attribute_of_short_column($shortcol);
            carp "Invalid column $shortcol in $id ignored"
              unless $attribute;
        }

        push @attributes, $attribute;

    }    ## tidy end: foreach my $col ( $mincol .....)

    return \@attributes;

}    ## tidy end: func _read_attribute_names

func _process_id ( Str : $id !, Str : $filename ! ) {
    if ($id !~ /\A
                    [A-Z0-9]+     # route indicator
                    _             # underscore
                    [A-Z0-9]+     # days
                    _             # underscore
                    [A-Z0-9]+     # direction
               \z /x
      )
    {
        croak "Can't find line, direction, and days "
          . "in sheet name $id in $filename";
    }

    my ( $line, $daycode, $dircode ) = split( /_/, $id );

    return $line, $daycode, $dircode;
}

#############################################
#### WRITE TO AN EXCEL SPREADSHEET

method add_stop_xlsx_sheet (
    : $orientation where { $_ eq 'auto' or $_ eq 'top' or $_ eq 'left' }
    = 'top',
    Excel::Writer::XLSX         : $workbook !,
    Excel::Writer::XLSX::Format : $format !,
  ) {

    my $id                     = $self->skedid;
    my $trip_attribute_columns = $self->_trip_attribute_columns;
    $trip_attribute_columns->unshift_row();
    my $stop_columns = $self->_stop_columns;

    ## no critic (ProhibitMagicNumbers)
    if ( $orientation eq 'auto' ) {
        if ( $self->stop_count > 2.5 * $self->trip_count ) {
            $orientation = 'left';
        }
        else {
            $orientation = 'top';
        }
    }
    ## use critic

    my $trip_attribute_width = $trip_attribute_columns->width;

    if ( $orientation eq 'left' ) {
        my $stopsked = $workbook->add_worksheet("$id.l");
        $stopsked->actium_write_row_string( 0, 0,
            $trip_attribute_columns, $format );
        $stopsked->actium_write_row_string( $trip_attribute_width, 0,
            $stop_columns, $format );
        $stopsked->freeze_panes( 0, 2 );
    }
    else {    # top
        my $stopsked = $workbook->add_worksheet($id);
        $stopsked->actium_write_col_string( 0, 0,
            $trip_attribute_columns, $format );
        $stopsked->actium_write_col_string( 0,
            $trip_attribute_width, $stop_columns, $format );
        $stopsked->freeze_panes( 2, 0 );
    }

    return;

}    ## tidy end: method add_stop_xlsx_sheet

method add_place_xlsx_sheet (
    Excel::Writer::XLSX         : $workbook !,
    Excel::Writer::XLSX::Format : $format !,
  ) {

    my $id = $self->skedid;

    my $trip_attribute_columns = $self->_trip_attribute_columns;
    $trip_attribute_columns->unshift_row();
    my $trip_attribute_width = $trip_attribute_columns->width;
    my $place_columns        = $self->_place_columns;

    my $tpsked = $workbook->add_worksheet($id);

    $tpsked->actium_write_col_string( 0, 0, $trip_attribute_columns, $format );
    $tpsked->actium_write_col_string( 0, $trip_attribute_width, $place_columns,
        $format );
    $tpsked->freeze_panes( 2, 0 );
    $tpsked->set_zoom(125);    ## no critic (ProhibitMagicNumbers)

    return;

}    ## tidy end: method add_place_xlsx_sheet

method xlsx {

    require Octium::Storage::Excel;

    my $stop_workbook_stream;
    open( my $stop_workbook_fh, '>', \$stop_workbook_stream )
      or die "$OS_ERROR";

    my $stop_workbook = Octium::Storage::Excel::new_workbook($stop_workbook_fh);
    my $stop_text_format = $stop_workbook->actium_text_format;

    $self->add_stop_xlsx_sheet(
        workbook => $stop_workbook,
        format   => $stop_text_format,
    );

    $stop_workbook->close;

    close $stop_workbook_fh or die "$OS_ERROR";
    return $stop_workbook_stream;
}    ## tidy end: method xlsx

sub xlsx_layers {':raw'}

method _stop_columns {

    my $stop_columns = Array::2D->new( $self->_stopid_r, $self->_stopplace_r );

    foreach my $trip ( $self->trips ) {
        my @times = map { Actium::Time->from_num($_)->apbx } $trip->stoptimes;
        $stop_columns->push_row(@times);
    }

    return $stop_columns;

}

method _trip_attribute_columns {

    # note that this only has one header column, and not two.
    # Before combining it with _stop_columns or _place_columns, a
    # $trip_attribute_columns->unshift_row()
    # should be done, to avoid misalignments

    my ( $columns_r, $shortcol_of_r )
      = $self->attribute_columns(qw(line day vehicletype daysexceptions));
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    my $trip_attribute_columns
      = Array::2D->new( [ @shortcol_of{@columns} ] );

    foreach my $trip ( $self->trips ) {
        $trip_attribute_columns->push_row( map { $trip->$_ } @columns );
    }

    return $trip_attribute_columns;

}    ## tidy end: method _trip_attribute_columns

method _place_columns {

    my $place_columns = Array::2D->new( $self->_place4_r, $self->_place8_r );

    foreach my $trip ( $self->trips ) {
        my @times = map { Actium::Time->from_num($_)->apbx } $trip->placetimes;

        $place_columns->push_row(@times);
    }

    return $place_columns;
}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.013

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

