# Actium/Sked/Sked.pm

# the Sked object, containing everything that is a schedule

# Subversion: $Id$

# legacy status 4

package Actium::O::Sked 0.002;

use 5.012;
use strict;

use Moose;
#use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use namespace::autoclean;

use MooseX::Storage;
with Storage( traits => ['OnlyWhenBuilt'], 'format' => 'JSON' );

use English '-no_match_vars';

use List::MoreUtils qw<none any>;
use List::Util ( 'first', 'max' );

use Actium::Util(qw<:all>);
use Actium::Time(qw<:all>);
use Actium::Sorting::Line qw<sortbyline linekeys>;
use Actium::Constants;

use Actium::Types (qw/DirCode HastusDirCode ActiumDir ActiumDays/);
use Actium::O::Sked::Trip;
use Actium::O::Dir;
use Actium::O::Days;
use Actium::O::Sked::Stop;
use Actium::O::Sked::Stop::Time;

use Actium::Term;

use Const::Fast;

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
        my $placecount = max( $place_id_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $placecount ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
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
        my $stopcount        = max( $stopid_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $stopcount ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
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
                and any { defined($_) }
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

has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
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
    require Digest::MD5;

    my @data = ( jt( $self->place4s ), jt( $self->stopids ) );

    foreach my $trip ( $self->trips ) {
        push @data, jt( $trip->stoptimes );
        push @data, jt( $trip->placetimes );
    }

    my $digest = Digest::MD5::md5_hex( jk(@data) );
    return $digest;

}

sub _build_linedir {
    my $self = shift;
    return jk( $self->linegroup, $self->dircode );
}

sub _build_linedays {
    my $self = shift;
    return jk( $self->linegroup, $self->sortable_days );
}

sub _build_earliest_timenum {
    my $self    = shift;
    my $trip    = $self->trip(0);
    my @times   = $trip->placetimes;
    my $timenum = first { defined $_ } @times;
    return $timenum;
}

sub _build_lines {
    my $self = shift;

    my $line_r;
    my %seen_line;

    foreach my $trip ( $self->trips() ) {
        $seen_line{ $trip->line() } = 1;
    }

    return [ sortbyline( keys %seen_line ) ];

}

sub _build_has_multiple_lines {
    my $self  = shift;
    my @lines = $self->lines;
    return @lines > 1;
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

sub _build_skedid {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->dircode, $self->daycode ) );
}

sub _build_sortable_id {
    my $self = shift;
    my $linegroup = linekeys( $self->linegroup || $self->oldlinegroup );
    $linegroup =~ s/\0/ /g;
    my $dir = $self->dir_obj->as_sortable;

    my $earliest_timenum = $self->earliest_timenum;
    $earliest_timenum = 0
      if $earliest_timenum < 0
      or $self->should_preserve_direction_order;
      # if earliest timenum is before midnight, just call it midnight
      # or, if this is a direction where we want to keep the direction order,
      # (e.g., always use A before B, clockwise before counterclockwise,
      # up before down), treat that as midnight too.
    $earliest_timenum = linekeys($earliest_timenum);

    return join( "\t", $linegroup, $self->daycode, $earliest_timenum, $dir );
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

### METHODS THAT ALTER SKEDS

# This is commented out because it is only used in Headways,
# and alters the existing sked object, which I don't want to do

#sub divide_sked {
#    my $self = shift;
#
#    my @lines = $self->lines();
#
#    my %linegroup_of;
#    foreach (@lines) {
#        $linegroup_of{$_} = ( $LINES_TO_COMBINE{$_} || $_ );
#
#        #        $linegroup_of{$_} = ( $_ );
#    }
#
#    my %linegroups;
#    $linegroups{$_} = 1 foreach ( values %linegroup_of );
#    my @linegroups = keys %linegroups;
#
#    if ( scalar(@linegroups) == 1 ) {  # there's just one linegroup, return self
#        $self->set_linegroup( $lines[0] );
#
#        $self->delete_blank_columns;
#
#        # override Scheduling's linegroup with the first line
#        return $self;
#    }
#
#    # More than one linegroup! Split apart
#
#    my ( %trips_of, @newskeds );
#
#    # collect trips for each one in %trips_of
#    foreach my $trip ( $self->trips ) {
#        my $linegroup = $linegroup_of{ $trip->line };
#        push @{ $trips_of{$linegroup} }, $trip;
#    }
#
#    foreach my $linegroup (@linegroups) {
#
#        my %value_of;
#
#        # collect all other attribute values in %values_of
#        # This is a really primitive clone routine and might arguably
#        # be better replaced by something based on MooseX::Clone or some other
#        # "real" deep clone routine.
#
#        foreach my $attribute ( $self->meta->get_all_attributes ) {
#
#            # meta-objects! woohoo! screw you, Mouse!
#
#            my $attrname = $attribute->name;
#            next if $attrname eq 'trip_r' or $attrname eq 'linegroup';
#
#            my $value = $self->$attrname;
#            if ( ref($value) eq 'ARRAY' ) {
#                $value = [ @{$value} ];
#            }
#            elsif ( ref($value) eq 'HASH' ) {
#                $value = { %{$value} };
#            }    # purely speculative as there are no hash attributes right now
#
#            # use of "ref" rather than "reftype" is intentional here. We don't
#            # want to clone objects this way.
#
#            $value_of{$attrname} = $value;
#        }    ## <perltidy> end foreach my $attribute ( $self...)
#
#        my $newsked = Actium::O::Sked->new(
#            trip_r    => $trips_of{$linegroup},
#            linegroup => $linegroup,
#            %value_of,
#        );
#
#        $newsked->delete_blank_columns;
#
#        push @newskeds, $newsked;
#
#    }    ## <perltidy> end foreach my $linegroup (@linegroups)
#
#    return @newskeds;
#
#}    ## <perltidy> end sub divide_sked

#### OUTPUT METHODS

sub tidydump {
    # cool, but very slow
    my $self   = shift;
    my $dumped = $self->dump;

    require Perl::Tidy;
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
    require Data::Dump;
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

    while ( my ( $field, $value ) = each %value_of_simplefield ) {
        next unless defined($value);
        push @simplefields, "$field:$value";
    }

    say $out "@simplefields";

    my $timesub = timestr_sub( SEPARATOR => $EMPTY_STR, XB => 1 );

    my @place_records;

    my ( $columns_r, $shortcol_of_r ) = $self->attribute_columns;
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    push @place_records, [ ($EMPTY_STR) x scalar @columns, $self->place4s ];
    push @place_records, [ @shortcol_of{@columns}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        push @place_records,
          [ ( map { $trip->$_ } @columns ), $timesub->( $trip->placetimes ) ];
    }

    say $out jn( @{ tabulate(@place_records) } ), "\n";
    # extra \n for a blank line to separate places and stops

    my @stop_records;

    push @stop_records, [ $self->stopids ];
    push @stop_records, [ $self->stopplaces ];

    foreach my $trip (@trips) {
        push @stop_records, [ $timesub->( $trip->stoptimes ) ];
    }

    say $out jn( @{ tabulate(@stop_records) } );
#
#    my @tripfields = qw<blockid daysexceptions from noteletter pattern runid to
#      type typevalue vehicledisplay via viadescription>;
#
#    foreach my $trip (@trips) {
#        my @tripfield_outs;
#        foreach my $field (@tripfields) {
#            my $value = $trip->$field;
#            next unless defined($value);
#            push @tripfield_outs, "$field:$value";
#        }
#        say $out "@tripfield_outs";
#    }

    close $out;

    return $outdata;

} ## tidy end: sub spaced

const my $xlsx_window_height => 950 * 20;    # 20 twips to the point
const my $xlsx_window_width  => 1200 * 20;

sub xlsx {
    my $self = shift;
    my $timesub = timestr_sub( XB => 1 );

    require Excel::Writer::XLSX;

    my $outdata;
    open( my $out, '>', \$outdata ) or die "$!";

    my $workbook = Excel::Writer::XLSX->new($out);

    ### horrible breaking encapsulation of object,
    ### but there are no accessors for some reason, and
    ### this works to change the window size

    $workbook->{_window_height} = $xlsx_window_height;
    $workbook->{_window_width}  = $xlsx_window_height;

    ####

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

    $intro->write_col( 0, 0, \@output_names,  $textformat );
    $intro->write_col( 0, 1, \@output_values, $textformat );

    ### TPSKED

    my $tpsked = $workbook->add_worksheet('tpsked');

    my @place_records;

    my ( $columns_r, $shortcol_of_r )
      = $self->attribute_columns(qw(line day vehicletype));
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    push @place_records, [ ($EMPTY_STR) x scalar @columns, $self->place4s ];
    push @place_records, [ @shortcol_of{@columns}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        push @place_records,
          [ ( map { $trip->$_ } @columns ), $timesub->( $trip->placetimes ) ];
    }

    $tpsked->write_col( 0, 0, \@place_records, $textformat );
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

    $stopsked->write_col( 0, 0, \@stop_records, $textformat );
    $stopsked->freeze_panes( 2, 0 );

    $tpsked->activate();

    $workbook->close();
    close $out;
    return $outdata;

} ## tidy end: sub xlsx

sub xlsx_layers {':raw'}

sub json {
    my $self = shift;
    return $self->freeze;    # uses MooseX::Storage;
}

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
                # This stop has the same stop id as the previous stop, and
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

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__
