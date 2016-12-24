package Actium::O::Sked 0.012;

# the Sked object, containing everything that is a schedule

use Actium::Moose;

use overload '""' => sub { shift->id };

use Actium::Moose;

use MooseX::Storage;              ### DEP ###
with Storage(
    traits   => ['OnlyWhenBuilt'],
    'format' => 'Storable',
    io       => 'File'
);

use Actium::Time(qw<:all>);
use Actium::Sorting::Line qw<linekeys>;

use Actium::Types (qw/DirCode ActiumDir ActiumDays/);
use Actium::O::Sked::Trip;
use Actium::O::Dir;
use Actium::O::Days;
use Actium::O::Sked::Stop;
use Actium::O::Sked::Stop::Time;

with 'Actium::O::Sked::Prehistoric';
# allows prehistoric skeds files to be read and written.

###################################
## CONSTRUCTION

sub BUILD {

    my $self = shift;

    $self->_add_placetimes_from_stoptimes;
    $self->_delete_blank_columns;
    $self->_combine_duplicate_timepoints;

}

sub _add_placetimes_from_stoptimes {
    my $self       = shift;
    my @trips      = $self->trips;
    my @stopplaces = $self->stopplaces;
    $_->_add_placetimes_from_stoptimes(@stopplaces) foreach @trips;

    return;
}

sub _delete_blank_columns {
    my $self = shift;

    if ( not $self->trip(0)->placetimes_are_empty ) {
        my @placetime_cols_to_delete;

        my @columns_of_times = $self->_placetime_columns;
        my $has_place8s      = not $self->place8s_are_empty;
        my $has_place4s      = not $self->place4s_are_empty;

        my $place_id_count = $self->place_count;
        my $placecount = u::max( $place_id_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $placecount ) ) {
            if ( u::none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @placetime_cols_to_delete, $i;
                next                      if $i > $place_id_count;
                $self->_delete_place8($i) if ($has_place8s);
                $self->_delete_place4($i) if ($has_place4s);

            }
        }

        foreach my $trip ( $self->trips ) {
            my $placetime_count = $trip->placetime_count;
            foreach my $i (@placetime_cols_to_delete) {
                next if $i > $placetime_count;
                $trip->_delete_placetime($i);
            }
        }
    } ## tidy end: if ( not $self->trip(0...))

    if ( not $self->trip(0)->stoptimes_are_empty ) {

        my @stoptimes_cols_to_delete;

        my @columns_of_times = $self->_stoptime_columns;
        my $stopid_count     = $self->stop_count;
        my $stopcount        = u::max( $stopid_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $stopcount ) ) {
            if ( u::none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @stoptimes_cols_to_delete, $i;
                next if $i > $stopid_count;
                $self->_delete_stopid($i);
                $self->_delete_stopplace($i);
            }
        }

        foreach my $trip ( $self->trips ) {
            my $stoptime_count = $trip->stoptime_count;
            foreach my $i (@stoptimes_cols_to_delete) {
                next if $i > $stoptime_count;
                $trip->_delete_stoptime($i);
            }
        }

    } ## tidy end: if ( not $self->trip(0...))

    return;

}    ## <perltidy> end sub delete_blank_columns

sub _placetime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->placetime_count - 1 ) {
            push @{ $columns[$i] }, $trip->placetime($i);
        }
    }

    return @columns;
}

sub _stoptime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->stoptime_count - 1 ) {
            push @{ $columns[$i] }, $trip->stoptime($i);
        }
    }

    return @columns;
}

sub _combine_duplicate_timepoints {

    my $self = shift;

    my @places = $self->place4s;

    # assemble runs of identical times

    my $prevplace         = $places[0];
    my $in_a_run_of_dupes = 0;

    my @runs_of_dupes;

  PLACE:
    for my $i ( 1 .. $#places ) {
        if ( $places[$i] ne $prevplace ) {
            $in_a_run_of_dupes = 0;
            $prevplace         = $places[$i];
            next PLACE;
        }

        if ( not $in_a_run_of_dupes ) {
            push @runs_of_dupes, { FIRSTCOL => $i - 1, LASTCOL => $i };
        }
        else {
            $runs_of_dupes[-1]{LASTCOL} = $i;
        }

        $in_a_run_of_dupes = 1;
    }

    foreach my $run ( reverse @runs_of_dupes ) {

        my $firstcolumn = $run->{FIRSTCOL};
        my $lastcolumn  = $run->{LASTCOL};
        my $numcolumns  = $lastcolumn - $firstcolumn + 1;

        my $place4 = $self->place4($firstcolumn);
        my $place8 = $self->place8($firstcolumn);

        my $has_double = 0;

        my ( @single_list, @double_list );

      TRIP:
        foreach my $trip ( $self->trips ) {

            my @alltimes = $trip->placetimes();

            my @thesetimes = sort { $a <=> $b }
              grep { defined($_) } @alltimes[ $firstcolumn .. $lastcolumn ];

            # so @thesetimes contains all the nonblank times
            # for this timepoint

            if ( not scalar @thesetimes ) {

                # no valid times
                push @single_list, undef;
                push @double_list, [ undef, undef ];
                next TRIP;
            }

            if ( scalar @thesetimes != 1 ) {

                @thesetimes
                  = @thesetimes[ 0, -1 ];    ## no critic 'ProhibitMagicNumbers'
                     # first and last only -- discard any middle times.
                     # Unlikely to actually happen

                if ( $thesetimes[0] == $thesetimes[1] ) {
                    @thesetimes = ( $thesetimes[0] );

                    # if they're the same, just keep one.
                }

            }

            # now @thesetimes contains one time
            # or two times that are different.

            if ( scalar @thesetimes == 2 ) {
                push @single_list, $thesetimes[1];
                push @double_list, [@thesetimes];
                $has_double = 1;
                next TRIP;
            }

            push @single_list, $thesetimes[0];

            # if this isn't the last column, and there are any times
            # defined later...
            if ( $#alltimes > $lastcolumn
                and u::any { defined($_) }
                @alltimes[ $lastcolumn + 1 .. $#alltimes ] )
            {

                # Then set the single time to be the departure time
                @thesetimes = ( undef, $thesetimes[0] );
            }
            else {

                # otherwise set it to be the arrival time
                @thesetimes = ( $thesetimes[0], undef );
            }

            push @double_list, [@thesetimes];

        }    ## <perltidy> end foreach my $trip ( $page->trips)

        if ($has_double) {
            $self->_splice_place4s( $firstcolumn, $numcolumns, $place4,
                $place4 );
            $self->_splice_place8s( $firstcolumn, $numcolumns, $place8,
                $place8 );
            foreach my $trip ( $self->trips ) {
                my $thesetimes_r = shift @double_list;
                my @thesetimes   = @{$thesetimes_r};
                next if $trip->placetime_count < $firstcolumn;
                $trip->_splice_placetimes( $firstcolumn, $numcolumns,
                    @thesetimes );
            }
        }
        else {
            $self->_splice_place4s( $firstcolumn, $numcolumns, $place4 );
            $self->_splice_place8s( $firstcolumn, $numcolumns, $place8 );
            foreach my $trip ( $self->trips ) {
                my $thistime = shift @single_list;
                next if $trip->placetime_count < $firstcolumn;
                # otherwise will splice off the end...
                $trip->_splice_placetimes( $firstcolumn, $numcolumns,
                    $thistime );
            }
        }

    }    ## <perltidy> end foreach my $run ( reverse @runs)

    return;

} ## tidy end: sub _combine_duplicate_timepoints

###################################
## MOOSE ATTRIBUTES

# comes from AVL, not headways
has 'place4_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        place4            => 'get',
        place4s           => 'elements',
        place_count       => 'count',
        place4s_are_empty => 'is_empty',
        _delete_place4    => 'delete',
        _splice_place4s   => 'splice',
    },
);

# comes from AVL or headways
has 'place8_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        place8            => 'get',
        place8s           => 'elements',
        place8s_are_empty => 'is_empty',
        place8_count      => 'count',
        _delete_place8    => 'delete',
        _splice_place8s   => 'splice',
    },
);

# from AVL or headways
has [qw<origlinegroup linegroup linedescrip>] => (
    is  => 'ro',
    isa => 'Str',
);

# direction
has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumDir,
    handles  => {
        direction                       => 'dircode',
        dircode                         => 'dircode',
        to_text                         => 'as_to_text',
        should_preserve_direction_order => 'should_preserve_direction_order',
    },
);

has 'linedir' => (
    lazy    => 1,
    builder => '_build_linedir',
    is      => 'ro',
);

has 'linedays' => (
    lazy    => 1,
    builder => '_build_linedays',
    is      => 'ro',
);

has 'lines_r' => (
    lazy    => 1,
    builder => '_build_lines',
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    handles => { lines => 'elements' },
);

has 'daysexceptions_r' => (
    lazy    => 1,
    builder => '_build_daysexceptions',
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    handles => { daysexceptions => 'elements' },
);

has 'specdays_r' => (
    lazy    => 1,
    builder => '_build_specdays_r',
    traits  => ['Hash'],
    is      => 'bare',
    reader  => '_specdays_r',
    isa     => 'HashRef[Str]',
    handles => {
        specdayletters => 'keys',
        specdays       => 'values',
        specday_count  => 'count',
    },
);

has 'specday_definitions_r' => (
    lazy    => 1,
    builder => '_build_specday_definitions_r',
    traits  => ['Array'],
    is      => 'bare',
    handles => { 'specday_definitions' => 'elements' },
);

sub _build_specday_definitions_r {

    my $self = shift;
    \my %specday_of = $self->_specdays_r;

    my @definitions;
    foreach my $letter ( keys %specday_of ) {
        push @definitions, $letter . " \x{2014} " . $specday_of{$letter};
    }
    @definitions = sort @definitions;
    return \@definitions;

}

# days
has 'days_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumDays,
    handles  => {
        daycode       => 'daycode',
        schooldaycode => 'schooldaycode',
        sortable_days => 'as_sortable',
    }
);

# from AVL or headways, but specific data in trips varies
has 'trip_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Actium::O::Sked::Trip]',
    default => sub { [] },
    handles => { trips => 'elements', trip => 'get', trip_count => 'count' },
);

# from AVL only

has 'stopid_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        stopid         => 'get',
        stop_count     => 'count',
        stopids        => 'elements',
        _delete_stopid => 'delete'
    },
);

# stopplaces -- either the place associated with the stop, or nothing
# if there is no place associated with the stop
has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Maybe[Str]]',
    default => sub { [] },
    handles => { stopplaces => 'elements', _delete_stopplace => 'delete' },
);

has 'earliest_timenum' => (
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_earliest_timenum',
    init_arg => undef,
);

has 'has_multiple_lines' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_has_multiple_lines',
);

has 'has_multiple_daysexceptions' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_has_multiple_daysexceptions',
);

has 'has_multiple_specdays' => (
    # badly named - actually it needs only one specday,
    # but that means there are two sets of days: regular and special
    is      => 'ro',
    lazy    => 1,
    builder => '_build_has_multiple_specdays',
);

has 'skedid' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_skedid',
);

has 'sortable_id' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_sortable_id',
);

has 'md5' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_md5',
);

################################
#### BUILDERS

sub _build_md5 {
    my $self = shift;
    # build an MD5 digest from the placetimes, stoptimes, places, and stops
    require Digest::MD5;    ### DEP ###

    my @data = ( u::jointab( $self->place4s ), u::jointab( $self->stopids ) );

    foreach my $trip ( $self->trips ) {
        push @data, u::jointab( $trip->stoptimes );
        push @data, u::jointab( $trip->placetimes );
    }

    my $digest = Digest::MD5::md5_hex( join( $KEY_SEPARATOR, @data ) );
    return $digest;

}

sub _build_linedir {
    my $self = shift;
    return join( $KEY_SEPARATOR, $self->linegroup, $self->dircode );
}

sub _build_linedays {
    my $self = shift;
    return join( $KEY_SEPARATOR, $self->linegroup, $self->sortable_days );
}

sub _build_earliest_timenum {
    my $self    = shift;
    my $trip    = $self->trip(0);
    my @times   = $trip->placetimes;
    my $timenum = u::first { defined $_ } @times;
    return $timenum;
}

sub _build_lines {
    my $self = shift;

    my $line_r;
    my %seen_line;

    foreach my $trip ( $self->trips() ) {
        $seen_line{ $trip->line() } = 1;
    }

    return [ u::sortbyline( keys %seen_line ) ];

}

sub _build_has_multiple_lines {
    my $self  = shift;
    my @lines = $self->lines;
    return @lines > 1;
}

sub _build_specdays_r {

    my $self     = shift;
    my $days_obj = $self->days_obj;
    my %specday_of;
    foreach my $trip ( $self->trips() ) {
        my ( $specdayletter, $specday ) = $trip->specday($days_obj);
        next unless $specdayletter;
        $specday_of{$specdayletter} = $specday;
    }
    return \%specday_of;

}

sub _build_daysexceptions {

    my $self = shift;
    my %seen_daysexceptions;
    foreach my $trip ( $self->trips() ) {
        $seen_daysexceptions{ $trip->daysexceptions } = 1;
    }
    return [ sort keys %seen_daysexceptions ];

}

sub _build_has_multiple_daysexceptions {
    my $self           = shift;
    my @daysexceptions = $self->daysexceptions;
    return @daysexceptions > 1;
}

sub _build_has_multiple_specdays {
    my $self = shift;
    return $self->specday_count;
}

sub _build_skedid {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->dircode, $self->daycode ) );
}

sub _build_sortable_id {
    my $self = shift;

    if ( $self->should_preserve_direction_order ) {
        return $self->sortable_id_with_timenum(0);
    }

    my $timenum = $self->earliest_timenum;
    $timenum = 0 if $timenum < 0;
    return $self->sortable_id_with_timenum($timenum);

}

sub sortable_id_with_timenum {
    my $self    = shift;
    my $timenum = shift;

    my $linegroup = linekeys( $self->linegroup || $self->oldlinegroup );
    $linegroup =~ s/\0/ /g;
    my $dir = $self->dir_obj->as_sortable;

    return join( "\t", $linegroup, $self->daycode, $timenum, $dir );

}

#################################
## METHODS

sub id {
    my $self = shift;
    return $self->skedid;
}

sub attribute_columns {
    # return only non-empty attributes of trips, for creating
    # columnar output

    my $self           = shift;
    my @arg_attributes = @_;

    my @trips = $self->trips;
    my $meta  = $trips[0]->meta;

    my %shortcol_of;
    my @attributes_to_search;

    my $day;

    if ( not @arg_attributes ) {
        @attributes_to_search = $meta->get_all_attributes;
        $day                  = 1;
    }
    else {
        foreach my $attrname (@arg_attributes) {
            if ( $attrname eq 'day' ) {
                $day = 1;
            }
            else {
                my $attr = $meta->find_attribute_by_name($attrname);
                push @attributes_to_search, $attr if defined $attr;
            }
        }
    }

  ATTRIBUTE:
    foreach my $attr (@attributes_to_search) {
        next unless $attr->meta->find_attribute_by_name('short_column');
        next unless $attr->has_read_method;
        my $reader = $attr->get_read_method;

        my $anydefined = 0;
        for my $trip (@trips) {
            my $value = $trip->$reader;
            next if ( not defined $value ) or ( $value eq $EMPTY_STR );
            $anydefined = 1;
            last;
        }
        next ATTRIBUTE unless $anydefined;

        $shortcol_of{$reader}
          = $attr->has_short_column ? $attr->short_column : $attr->name;

    }

    my @colorder = grep { $_ ne 'line' } ( sort keys %shortcol_of );
    unshift @colorder, 'line' if exists $shortcol_of{line};

    if ($day) {
        splice( @colorder, 1, 0, 'sortable_days' );
        $shortcol_of{sortable_days} = 'DAY';
    }

    return \@colorder, \%shortcol_of;

} ## tidy end: sub attribute_columns

####################
#### OUTPUT METHODS

sub tidydump {
    # cool, but very slow
    my $self   = shift;
    my $dumped = $self->dump;

    require Perl::Tidy;    ### DEP ###
    my $tidy;
    Perl::Tidy::perltidy(
        source      => \$dumped,
        destination => \$tidy,
        argv        => '',
    );
    return $tidy;

}

sub dump {
    my $self = shift;
    require Data::Dump;    ### DEP ###
    my $dumped = Data::Dump::dump($self);

    return $dumped;

}

sub spaced {
    my $self = shift;

    my $outdata;
    open( my $out, '>', \$outdata );

    say $out $self->id;

    my @simplefields;
    my %value_of_simplefield = (
        dir           => $self->dircode,
        days          => $self->sortable_days,
        linegroup     => $self->linegroup,
        origlinegroup => $self->origlinegroup,
        linedescrip   => $self->linedescrip,
    );

    foreach my $field ( sort keys %value_of_simplefield ) {
        my $value = $value_of_simplefield{$field};
        next unless defined($value);
        push @simplefields, "$field:$value";
    }

    say $out "@simplefields";

    require Actium::O::2DArray;

    my $timesub = timestr_sub( SEPARATOR => $EMPTY_STR, XB => 1 );

    my $place_records = Actium::O::2DArray->new();

    my ( $columns_r, $shortcol_of_r ) = $self->attribute_columns;
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    push @$place_records, [ ($EMPTY_STR) x scalar @columns, $self->place4s ];
    push @$place_records, [ @shortcol_of{@columns}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        push @$place_records,
          [ ( map { $trip->$_ } @columns ), $timesub->( $trip->placetimes ) ];
    }

    say $out $place_records->tabulated, "\n";

    my $stop_records = Actium::O::2DArray->new();

    push @$stop_records, [ $self->stopids ];
    push @$stop_records, [ $self->stopplaces ];

    foreach my $trip (@trips) {
        push @$stop_records, [ $timesub->( $trip->stoptimes ) ];
    }

    say $out $stop_records->tabulated;

    close $out;

    return $outdata;

} ## tidy end: sub spaced

my $xlsx_timesub = timestr_sub( XB => 1 );

sub add_stop_xlsx_sheet {
    my $self     = shift;
    my $workbook = shift;
    my $format   = shift;

    my $id = $self->skedid;

    my $stopsked = $workbook->add_worksheet($id);

    my @stop_records;

    push @stop_records, [ $self->stopids ];
    push @stop_records, [ $self->stopplaces ];

    foreach my $trip ( $self->trips ) {
        push @stop_records, [ $xlsx_timesub->( $trip->stoptimes ) ];
    }

    my $stop_count = $self->stop_count;
    my $trip_count = $self->trip_count;

    if ( $stop_count > 2.5 * $self->trip_count ) {
        # if stops are wider than trips, then
        $stopsked->actium_write_row_string( 0, 0, \@stop_records, $format );
        $stopsked->freeze_panes( 0, 2 );
    }
    else {
        # otherwise stops at the top
        $stopsked->actium_write_col_string( 0, 0, \@stop_records, $format );
        $stopsked->freeze_panes( 2, 0 );
    }

    return;

} ## tidy end: sub add_stop_xlsx_sheet

sub add_place_xlsx_sheet {

    my $self     = shift;
    my $workbook = shift;
    my $format   = shift;

    my $id = $self->skedid;

    my $tpsked = $workbook->add_worksheet($id);

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
          [ ( map { $trip->$_ } @columns ),
            $xlsx_timesub->( $trip->placetimes )
          ];
    }

    $tpsked->actium_write_col_string( 0, 0, \@place_records, $format );
    $tpsked->freeze_panes( 2, 0 );
    $tpsked->set_zoom(125);

    return;

} ## tidy end: sub add_place_xlsx_sheet

### OLD XLSX SCHEDULES, TO BE DELETED ###

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

    my @all_attributes
      = qw(id sortable_days dircode linegroup origlinegroup linedescrip md5);
    my @all_output_names
      = qw(id days dir linegroup origlinegroup linedescrip md5);

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

sub storable {
    my $self = shift;
    return $self->freeze;    # uses MooseX::Storage;
}

sub transitinfo_id {

    my $self             = shift;
    my $linegroup        = $self->linegroup;
    my $dir              = $self->dircode;
    my $days_transitinfo = $self->days_obj->as_transitinfo;

    return join( '_', $linegroup, $dir, $days_transitinfo );

}

sub tabxchange {

    # tab files for AC Transit web site
    my $self = shift;

    my %params = u::validate(
        @_,
        {   destinationcode => 1,
            actiumdb        => 1,
            collection      => 1,
        }
    );

    my $dc             = $params{destinationcode};
    my $actiumdb       = $params{actiumdb};
    my $skedcollection = $params{collection};

    # line 1 - skedid

    require Actium::O::2DArray;
    my $skedid = $self->transitinfo_id;
    my $aoa = Actium::O::2DArray->bless( [ [$skedid] ] );

    my $p = sub { $aoa->push_row( @_, $EMPTY ) };
    # the $EMPTY is probably not needed but the old program
    # added a tab at the end of every line

    my $p_blank = sub { push @{$aoa}, [] };
    # to push an actual blank line

    # line 2 - days
    my $days             = $self->days_obj;
    my $days_transitinfo = $self->days_obj->as_transitinfo;
    $p->(
        $days_transitinfo, $days->as_adjectives,
        $days->as_abbrevs, $days->as_plurals
    );

    # line 3 - direction/destination
    my $final_place = $self->place4(-1);
    my $destination = $actiumdb->destination($final_place);
    my $dir_obj     = $self->dir_obj;
    my $dir         = $dir_obj->dircode;
    if ( $dir eq 'CC' ) {
        $destination = "Counterclockwise to $destination,";
    }
    elsif ( $dir eq 'CW' ) {
        $destination = "Clockwise to $destination,";
    }
    elsif ( $dir eq 'A' ) {
        $destination = "A Loop to $destination,";
    }
    elsif ( $dir eq 'B' ) {
        $destination = "B Loop to $destination,";
    }
    else {
        $destination = "To $destination,";
    }

    my $destcode = $dc->code_of($destination);
    $p->( $dir_obj->as_onechar . $destcode, $dir_obj->as_bound, $destination );

    # line 4 - upcoming/current and linegroup
    my $linegroup       = $self->linegroup;
    my $linegroup_row_r = $actiumdb->line_row_r($linegroup);

    $p->(
        'U',
        $linegroup,
        '',    # LineGroupWebNote - no longer valid
        $linegroup_row_r->{LineGroupType},
        ''     # UpComingOrCurrentLineGroup
    );

    # line 5 - all lines
    $p->( $self->lines );

    # line 6 - associated schedules
    $p->( $skedcollection->sked_transitinfo_ids_of_lg($linegroup) );

    # lines 7 - one line per bus line
    foreach my $line ( $self->lines ) {
        my $line_row_r = $actiumdb->line_row_r($line);
        my $color = $line_row_r->{Color} // 'Default';
        $color = 'Default' if not $actiumdb->color_exists($color);
        my $color_row_r = $actiumdb->color_row_r($color);

        $p->(
            $line,
            $line_row_r->{Description},
            '',    # DirectionFile
            '',    # StopListFile
            '',    # MapFileName,
            '',    # LineNote,
            $line_row_r->{TimetableDate},
            $color_row_r->{Cyan},
            $color_row_r->{Magenta},
            $color_row_r->{Yellow},
            $color_row_r->{Black},
            $color_row_r->{RGB}
        );

    } ## tidy end: foreach my $line ( $self->lines)

    # lines 8 - timepoints
    my @place4s = $self->place4s;
    $p->(@place4s);

    # lines 9 - lines per timepoint

    my @placedescs;

    foreach my $place (@place4s) {

        my $desc = $actiumdb->field_of_referenced_place(
            place => $place,
            field => 'c_description',
        );
        push @placedescs, $desc;
        my $city = $actiumdb->field_of_referenced_place(
            place => $place,
            field => 'c_city',
        );
        my $usecity = (
            $actiumdb->field_of_referenced_place(
                place => $place,
                field => 'ux_usecity_description',
            ) ? 'Yes' : 'No'
        );

        $p->(
            $place,
            $desc,
            $city,
            $usecity,
            '',    # Neighborhood
            '',    # TPNote
            '',    # fake timepoint note
        );
    } ## tidy end: foreach my $place (@place4s)

    # lines 10 - footnotes for a trip

    $p_blank->();
    # make an actual blank line

    #$p->($EMPTY);

    # lines 11 - schedule notes

    my $fullnote      = $EMPTY;
    my $schedule_note = $linegroup_row_r->{schedule_note};
    $fullnote .= $schedule_note if $schedule_note;

    my $govtopic = $linegroup_row_r->{GovDeliveryTopic};

    if ($govtopic) {
        $fullnote
          .= '<p>'
          . q{<a href="https://public.govdelivery.com/}
          . q{accounts/ACTRANSIT/subscriber/new?topic_id=}
          . $govtopic . q{">}
          . 'Get timely, specific updates about '
          . "Line $linegroup from AC Transit eNews."
          . '</a></p>';
    }

    $fullnote .= '<p>The times provided are for '
      . 'important landmarks along the route.';

    my %stoplist_url_of;

    foreach my $line ( $self->lines ) {
        my $line_row_r = $actiumdb->line_row_r($line);

        my $linegrouptype = lc( $line_row_r->{LineGroupType} );
        $linegrouptype =~ s/ /-/g;    # converted to dashes by wordpress
        if ($linegrouptype) {
            if ( $linegrouptype eq 'local' ) {
                no warnings 'numeric';
                if ( $line <= 70 ) {
                    $linegrouptype = 'local1';
                }
                else {
                    $linegrouptype = 'local2';
                }
            }

            $stoplist_url_of{$line}
              = qq{http://www.actransit.org/riderinfo/stops/$linegrouptype/#$line};
        }
        else {
            warn "No linegroup type for line $line";
        }

    } ## tidy end: foreach my $line ( $self->lines)

    my @linklines = u::sortbyline keys %stoplist_url_of;
    my $numlinks  = scalar @linklines;

    if ( $numlinks == 1 ) {
        my $linkline = $linklines[0];

        $fullnote
          .= $SPACE
          . qq{<a href="$stoplist_url_of{$linkline}">}
          . qq{A complete list of stops for Line $linkline is also available.</a>};
    }
    elsif ( $numlinks != 0 ) {

        my @stoplist_links
          = map {qq{<a href="$stoplist_url_of{$_}">$_</a>}} @linklines;

        $fullnote
          .= qq{ Complete lists of stops for lines }
          . u::joinseries(@stoplist_links)
          . ' are also available.';
    }

    $fullnote .= '</p>';

    # This was under lines 13 - special days notes, but has been moved here
    # because the PHP code is apparently broken

    my ( %specday_of_specdayletter, %trips_of_letter, @specdayletters,
        @noteletters, @lines );

    #    foreach my $daysexception ( $self->daysexceptions ) {
    #        next unless $daysexception;
    #        my ( $specdayletter, $specday ) = split( / /, $daysexception, 2 );
    #        $specday_of_specdayletter{$specdayletter} = $specday;
    #    }

    foreach my $trip ( $self->trips ) {

        my $daysexception = $trip->daysexceptions;

        my $tripdays = $trip->days_obj;
        my ( $specdayletter, $specday )
          = $tripdays->specday_and_specdayletter($days);

        if ($daysexception) {
            my ( $dspecdayletter, $dspecday ) = split( / /, $daysexception, 2 );
            $specday_of_specdayletter{$dspecdayletter} = $dspecday;
            push @specdayletters, $specdayletter;
            push @{ $trips_of_letter{$dspecdayletter} }, $trip;
        }
        elsif ($specdayletter) {
            $specday_of_specdayletter{$specdayletter} = $specday;
            push @specdayletters, $specdayletter;
            push @{ $trips_of_letter{$specdayletter} }, $trip;
        }
        else {
            push @specdayletters, $EMPTY;
        }

        push @noteletters, $EMPTY;
        push @lines,       $trip->line;

    } ## tidy end: foreach my $trip ( $self->trips)

    my ( @specdaynotes, @specdaytrips );

    my $colon_timesub = timestr_sub();

    foreach my $noteletter ( keys %specday_of_specdayletter ) {

        my $specday = $specday_of_specdayletter{$noteletter};

        push @specdaynotes,
            '<p>'
          . $noteletter
          . ' &mdash; '
          . $specday_of_specdayletter{$noteletter} . '</p>';

        my @trips = $trips_of_letter{$noteletter}->@*;

        my $specdaytrip = $specday =~ s/\.*\z/:/r;
        $specdaytrip = "<dt>$specdaytrip</dt>";

        foreach my $trip (@trips) {

            my @placetimes = $trip->placetimes;
            my $idx = u::firstidx {defined} @placetimes;

            $specdaytrip .= "<dd>Trip leaving $placedescs[$idx]" . " at "
              . $colon_timesub->( $placetimes[$idx] ) . '</dd>';
        }

        push @specdaytrips, $specdaytrip;

    } ## tidy end: foreach my $noteletter ( keys...)

    @specdaytrips = sort @specdaytrips;

    #$p->(@specdaynotes);

    #$fullnote .= u::joinempty(@specdaynotes);

    if (@specdaytrips) {
        $fullnote .= '<dl>' . u::joinempty(@specdaytrips) . '</dl>';
    }

    $p->( $fullnote, $linegroup_row_r->{LineGroupNote} );

    # lines 12 - current or upcoming schedule equivalent. Not used

    $p->('');

    # lines 13 - Definitions of special day codes

   #    my ( %specday_of_specdayletter, @specdayletters, @noteletters, @lines );
   #
   #    foreach my $daysexception ( $self->daysexceptions ) {
   #        next unless $daysexception;
   #        my ( $specdayletter, $specday ) = split( / /, $daysexception, 2 );
   #        $specday_of_specdayletter{$specdayletter} = $specday;
   #    }
   #
   #    foreach my $trip ( $self->trips ) {
   #        my $tripdays = $trip->days_obj;
   #        my ( $specdayletter, $specday )
   #          = $tripdays->specday_and_specdayletter($days);
   #
   #        if ($specdayletter) {
   #            $specday_of_specdayletter{$specdayletter} = $specday;
   #            push @specdayletters, $specdayletter;
   #        }
   #        else {
   #            push @specdayletters, $EMPTY;
   #        }
   #
   #        push @noteletters, $EMPTY;
   #        push @lines,       $trip->line;
   #
   #    }
   #
   #    my @specdaynotes;
   #
   #    foreach my $noteletter ( keys %specday_of_specdayletter ) {
   #        push @specdaynotes,
   #          u::joinkey( $noteletter, $specday_of_specdayletter{$noteletter} );
   #    }
   #
   #    $p->(@specdaynotes);
   #
    $p_blank->();    # special day notes, moved above

    # FLIPPING NOTE LETTERS AND SPECIAL DAY CODES TO SEE IF THAT WORKS

    # lines 14  - special day code for each trip

    # $p->(@specdayletters);
    # lines 15 - note letters for each trip

    $p->(@noteletters);

    $p->(@specdayletters);

    # lines 16 - lines

    $p->(@lines);

    # lines 17 - times

    my $placetimes_aoa = Actium::O::2DArray->new;
    my $timesub = timestr_sub( SEPARATOR => $EMPTY );

    foreach my $trip ( $self->trips ) {
        my @placetimes = map { $timesub->($_) } $trip->placetimes;
        $placetimes_aoa->push_col(@placetimes);
    }

    # so, the old program had a bug, I think, that added an extra tab
    # to every line.

    # Here we are being bug-compatible.

    $placetimes_aoa->push_col( $EMPTY x $placetimes_aoa->height() );

    return $aoa->tsv . $placetimes_aoa->tsv;

} ## tidy end: sub tabxchange

###################
### STOP OBJECTS

# An earlier attempt at replacing some of the work done by
# kpoints and flagspecs, I believe

sub stop_objects {
    my $self = shift;

    my @stopplaces = map {s/-[AD12]$//} $self->stopplaces;
    my @stopids    = $self->stopids;
    my $stopcount  = $self->stop_count;

    my ( @stop_objs, @time_objs );

    foreach my $trip ( $self->trips ) {

        my $tripdays = $trip->days_obj;

        my @times = $trip->stoptimes;

        my ( $origin,     $destination, $previous_place );
        my ( @previouses, @followers,   @newtimes );
        my $previous_place_idx = 0;

        for my $stop_idx ( 0 .. $stopcount ) {

            my $time         = $times[$stop_idx];
            my $stopid       = $stopids[$stop_idx];
            my $previous_idx = $stop_idx - 1;
            my $stopplace    = $stopplaces[$stop_idx];

            #### Check -- same stop as last time?
            #### If so, and last entry has values, copy them over.

            if (    $stop_idx
                and $newtimes[$previous_idx]
                and $stopid eq $stopids[$previous_idx] )
            {
                # This stop has the same stop id
                # as the previous stop, and
                # the previous time was valid.

                if ( not defined $time ) {
                    # if only the previous stop had a time, move that entry
                    # forward to this entry, and go to the next one.
                    splice( @newtimes,   -1, 0, undef );
                    splice( @previouses, -1, 0, undef );
                    if ( $followers[$previous_idx] ) {
                        splice( @followers, -1, 0, undef );
                    }
                    next;
                }

                if ( isblank($stopplace) ) {
                    # If this stop has a time but no place, and the previous
                    # stop had a place,
                    # use the previous place and go to the next stop.
                    splice( @previouses, -1, 0, undef );
                    if ( $followers[$previous_idx] ) {
                        splice( @followers, -1, 0, undef );
                    }
                    undef $newtimes[$previous_idx];
                    $newtimes[$stop_idx] = $time;
                    next;
                }

                # otherwise, just null out the previous entry as though
                # it was never there.

                undef $previouses[$previous_idx];
                undef $followers[$previous_idx];
                undef $newtimes[$previous_idx];

            } ## tidy end: if ( $stop_idx and $newtimes...)

            ###

            next unless defined($time);

            $newtimes[$stop_idx] = $time;

            if ( isblank($stopplace) ) {
                # Not a timepoint
                $previouses[$stop_idx] = $previous_place;
            }
            else {
                # Is a timepoint

                my $place = $stopplace;
                $previouses[$stop_idx] = $place;
                $followers[$stop_idx]  = $place;

                if ( defined $origin ) {
                    # Timepoint after the origin
                    $destination = $place;
                    # That gets set for every place until the last one

                    my @followers_to_set
                      = ( $previous_place_idx + 1 .. $stop_idx - 1 );
                    foreach my $j (@followers_to_set) {
                        next unless $previouses[$j];
                        $followers[$j] = $place;
                    }

                    $previous_place_idx = $stop_idx;

                }
                else {
                    # Origin timepoint
                    $origin         = $place;
                    $previous_place = $place;
                }

            } ## tidy end: else [ if ( isblank($stopplace...))]

        } ## tidy end: for my $stop_idx ( 0 .....)

        for my $stop_idx ( 0 .. $stopcount ) {
            next unless $newtimes[$stop_idx];
            push @{ $time_objs[$stop_idx] },
              Actium::O::Sked::Stop::Time->new(
                {   origin      => $origin,
                    destination => $destination,
                    follower    => $followers[$stop_idx],
                    previous    => $previouses[$stop_idx],
                    days        => $self->days_obj,
                    times       => $newtimes[$stop_idx],
                    line        => $self->line,
                    stop_index  => $stop_idx,
                }
              );
        }

    } ## tidy end: foreach my $trip ( $self->trips)

    for my $stop_idx ( 0 .. $stopcount ) {
        next unless $time_objs[$stop_idx];
        push @stop_objs,
          Actium::O::Sked::Stop->new(
            {   time_objs => $time_objs[$stop_idx],
                direction => $self->dir_obj,
                days      => $self->days_obj,
                linegroup => $self->linegroup,
            }
          );
    }

    return @stop_objs;

} ## tidy end: sub stop_objects

with 'Actium::O::Skedlike';

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__
