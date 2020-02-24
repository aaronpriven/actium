package Octium::O::Sked 0.013;
# the Sked object, containing everything that is a schedule

use Octium ('class');

use overload '""' => sub { shift->id }, fallback => 1;

use MooseX::Storage;    ### DEP ###
with Storage(
    traits   => ['OnlyWhenBuilt'],
    'format' => 'Storable',
    io       => 'File',
);
use Octium::Sorting::Line qw<linekeys>;

use Octium::Types (qw/DirCode ActiumDir ActiumDays/);
use Octium::O::Sked::Trip;
use Octium::Time;
use Octium::O::Dir;
use Octium::O::Days;
use Octium::O::2DArray;

###################################
## CONSTRUCTION

sub BUILD {

    my $self = shift;

    $self->_add_placetimes_from_stoptimes;
    $self->_delete_blank_columns;
    $self->_combine_duplicate_timepoints;

    return;

}

###################################
### TRIP FINALIZING

# These should be moved to O::Sked::TripCollection and
# the trip_r attribute replaced by a TripCollection object

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
            if (u::none { defined($_) }
                @{ $columns_of_times[$i] }
              )
            {
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
            if (u::none { defined($_) }
                @{ $columns_of_times[$i] }
              )
            {
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

                @thesetimes = @thesetimes[ 0, -1 ];
                # first and last only -- discard any middle times.
                # Unlikely to actually happen

                if ( $thesetimes[0] == $thesetimes[1] ) {
                    @thesetimes = ( $thesetimes[0] );

                    # if they're the same, just keep one.
                }

            }

            # now @thesetimes contains one time
            # or two times that are different.

            if ( 2 == scalar @thesetimes ) {
                push @single_list, $thesetimes[1];
                push @double_list, [@thesetimes];
                $has_double = 1;
                next TRIP;
            }

            push @single_list, $thesetimes[0];

            # if this isn't the last column, and there are any times
            # defined later...
            if ($#alltimes > $lastcolumn
                and u::any { defined($_) }
                @alltimes[ $lastcolumn + 1 .. $#alltimes ]
              )
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
            $self->_splice_place4s( $firstcolumn, $numcolumns,
                $place4, $place4 );
            $self->_splice_place8s( $firstcolumn, $numcolumns,
                $place8, $place8 );
            foreach my $trip ( $self->trips ) {
                my $thesetimes_r = shift @double_list;
                my @thesetimes   = @{$thesetimes_r};
                next if $trip->placetime_count < $firstcolumn;
                $trip->_splice_placetimes( $firstcolumn,
                    $numcolumns, @thesetimes );
            }
        }
        else {
            $self->_splice_place4s( $firstcolumn, $numcolumns, $place4 );
            $self->_splice_place8s( $firstcolumn, $numcolumns, $place8 );
            foreach my $trip ( $self->trips ) {
                my $thistime = shift @single_list;
                next if $trip->placetime_count < $firstcolumn;
                # otherwise will splice off the end...
                $trip->_splice_placetimes( $firstcolumn,
                    $numcolumns, $thistime );
            }
        }

    }    ## <perltidy> end foreach my $run ( reverse @runs)

    return;

} ## tidy end: sub _combine_duplicate_timepoints

###################################
## MOOSE ATTRIBUTES

# supplied attributes

has 'place4_r' => (
    traits  => ['Array'],
    is      => 'ro',
    reader  => '_place4_r',
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

has 'place8_r' => (
    traits  => ['Array'],
    is      => 'ro',
    reader  => '_place8_r',
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

has 'stopid_r' => (
    traits  => ['Array'],
    is      => 'ro',
    reader  => '_stopid_r',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        stopid         => 'get',
        stop_count     => 'count',
        stopids        => 'elements',
        _delete_stopid => 'delete',
    },
);

# stopplaces -- either the place associated with the stop, or nothing
# if there is no place associated with the stop
has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'ro',
    reader  => '_stopplace_r',
    isa     => 'ArrayRef[Maybe[Str]]',
    default => sub { [] },
    handles => {
        stopplaces        => 'elements',
        _delete_stopplace => 'delete'
    },
);

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

has 'linegroup' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

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
    },
);

has 'trip_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Octium::O::Sked::Trip]',
    default => sub { [] },
    handles => {
        trips      => 'elements',
        trip       => 'get',
        trip_count => 'count'
    },
);

### built attributes

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

has 'place_md5' => (
    is      => 'ro',
    lazy    => 1,
    builder => '_build_place_md5',
);

################################
#### BUILDERS

sub _build_md5 {
    my $self = shift;
    # build an MD5 digest from the placetimes, stoptimes, places, and stops
    require Digest::MD5;    ### DEP ###

    my @sked_stream
      = ( u::jointab( $self->place4s ), u::jointab( $self->stopids ) );

    foreach my $trip ( $self->trips ) {
        push @sked_stream, u::jointab( $trip->stoptimes );
        push @sked_stream, u::jointab( $trip->placetimes );
    }

    my $digest = Digest::MD5::md5_hex( join( $KEY_SEPARATOR, @sked_stream ) );
    return $digest;

}

sub _build_place_md5 {
    my $self = shift;
    # build an MD5 digest from the placetimes and  places
    require Digest::MD5;    ### DEP ###

    my @sked_stream = ( u::jointab( $self->place4s ) );

    foreach my $trip ( $self->trips ) {
        push @sked_stream, u::jointab( $trip->placetimes );
    }

    my $digest = Digest::MD5::md5_hex( join( $KEY_SEPARATOR, @sked_stream ) );
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
    return ( join( '_', $self->linegroup, $self->dircode, $self->daycode ) );
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

    $timenum = sprintf '<%04d>', $timenum;
    # pad to 4 zeros

    my $linegroup = linekeys( $self->linegroup );
    $linegroup =~ s/\0/ /g;
    my $dir = $self->dir_obj->as_sortable;

    return join( "\t", $linegroup, $self->daycode, $timenum, $dir );

}

#################################
## METHODS

method id {
    $self->skedid;
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
                push @attributes_to_search, $attr
                  if defined $attr;
            }
        }
    }

  ATTRIBUTE:
    foreach my $attr (@attributes_to_search) {
        next
          unless $attr->meta->find_attribute_by_name('short_column');
        next unless $attr->has_read_method;
        my $reader = $attr->get_read_method;

        my $anydefined = 0;
        for my $trip (@trips) {
            my $value = $trip->$reader;
            next
              if ( not defined $value )
              or ( $value eq $EMPTY );
            $anydefined = 1;
            last;
        }
        next ATTRIBUTE unless $anydefined;

        $shortcol_of{$reader}
          = $attr->has_short_column
          ? $attr->short_column
          : $attr->name;

    } ## tidy end: ATTRIBUTE: foreach my $attr (@attributes_to_search)

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

# see also various Octium::O::Sked::Storage:: roles

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
        dir       => $self->dircode,
        days      => $self->sortable_days,
        linegroup => $self->linegroup,
    );

    foreach my $field ( sort keys %value_of_simplefield ) {
        my $value = $value_of_simplefield{$field};
        next unless defined($value);
        push @simplefields, "$field:$value";
    }

    local $LIST_SEPARATOR = $SPACE;
    say $out "@simplefields";

    my $place_records = Octium::O::2DArray->new();

    my ( $columns_r, $shortcol_of_r ) = $self->attribute_columns;
    my @columns     = @{$columns_r};
    my %shortcol_of = %{$shortcol_of_r};

    push @$place_records, [ ($EMPTY) x scalar @columns, $self->place4s ];
    push @$place_records, [ @shortcol_of{@columns}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        my @times = map { Octium::Time->from_num($_)->apbx_noseparator }
          $trip->placetimes;

        push @$place_records, [ ( map { $trip->$_ } @columns ), @times ];

        if ( $trip->_mergedtrip_count ) {
            foreach my $mergedtrip ( $trip->mergedtrips ) {
                my @record;
                foreach my $idx ( 0 .. $#columns ) {
                    if ( $columns[$idx] eq 'blockid' ) {
                        $record[$idx] = $mergedtrip->blockid;
                    }
                }
                push @$place_records, \@record if @record;
            }

        }

    } ## tidy end: foreach my $trip (@trips)

    say $out $place_records->tabulated, "\n";

    my $stop_records = Octium::O::2DArray->new();

    push @$stop_records, [ $self->stopids ];
    push @$stop_records, [ $self->stopplaces ];

    foreach my $trip (@trips) {
        my @times = map { Octium::Time->from_num($_)->apbx_noseparator }
          $trip->stoptimes;
        push @$stop_records, \@times;
    }

    say $out $stop_records->tabulated;

    close $out;

    return $outdata;

} ## tidy end: sub spaced

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

method compare_from (Octium::O::Sked $oldsked) {
    require Octium::O::Sked::Comparison;
    return Octium::O::Sked::Comparison->new(
        oldsked => $oldsked,
        newsked => $self
    );

}

method compare_to (Octium::O::Sked $newsked) {
    return $newsked->compare_from($self);
}

with 'Octium::O::Sked::Storage::Prehistoric', 'Octium::O::Sked::Storage::XLSX',
  'Octium::O::Sked::Storage::Tabxchange', 'Octium::O::Skedlike';

u::immut;

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

