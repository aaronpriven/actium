# Actium/Sked/Sked.pm

# the Sked object, containing everything that is a schedule

# Subversion: $Id$

# legacy status 3

package Actium::Sked 0.002;

use 5.012;
use strict;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use English '-no_match_vars';

use List::MoreUtils qw<none>;
use List::Util ( 'first', 'max' );

use Actium::Util(qw<:all>);
use Actium::Time(qw<:all>);
use Actium::Sorting::Line qw<sortbyline linekeys>;
use Actium::Constants;

use Actium::Types (qw/DirCode HastusDirCode ActiumSkedDir ActiumSkedDays/);

use Actium::Sked::Trip;
use Actium::Sked::Dir;
use Actium::Sked::Days;

use Actium::Term;

with 'Actium::Sked::Prehistoric';
# allows prehistoric skeds files to be read and written.

###################################
## MOOSE ATTRIBUTES

# comes from AVL, not headways
has 'place4_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        place4s           => 'elements',
        place_count       => 'count',
        place4s_are_empty => 'is_empty',
        delete_place4     => 'delete',
    },
);

# comes from AVL or headways
has 'place8_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        place8s           => 'elements',
        place8s_are_empty => 'is_empty',
        _place8_count     => 'count',
        delete_place8     => 'delete',
    },
);

# from AVL or headways
has [qw<origlinegroup linegroup linedescrip>] => (
    is  => 'rw',
    isa => 'Str',
);

# direction
has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumSkedDir,
    handles  => {
        'direction' => 'dircode',
        'dircode'   => 'dircode',
        'to_text'   => 'as_to_text'
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

# days
has 'days_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumSkedDays,
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
    isa     => 'ArrayRef[Actium::Sked::Trip]',
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
        stop_count    => 'count',
        stopids       => 'elements',
        delete_stopid => 'delete'
    },
);

has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { stopplaces => 'elements', delete_stopplace => 'delete' },
);

has 'earliest_timenum' => (
    is       => 'ro',
    lazy     => 1,
    builder  => '_build_earliest_timenum',
    required => 0,
    init_arg => undef,
);

#### BUILDERS

sub _build_linedir {

    my $self = shift;
    return jk( $self->linegroup, $self->dircode );

}

sub _build_linedays {

    my $self = shift;
    return jk( $self->linegroup, $self->sortable_days );

}

sub _build_earliest_timenum {

    my $self  = shift;
    my $trip  = $self->trip(0);
    my @times = $trip->placetimes;

    my $timenum = first { defined $_ } @times;
    return $timenum;

}

sub build_placetimes_from_stoptimes {
    my $self  = shift;
    my @trips = $self->trips;

    my @stopplaces = $self->stopplaces;

    foreach my $trip (@trips) {

        next unless $trip->placetimes_are_empty;

        my @stoptimes          = $trip->stoptimes;
        my $previous_stopplace = $EMPTY_STR;
        my @placetimes;

        for my $i ( 0 .. $#stoptimes ) {

            my $stopplace = $stopplaces[$i];
            my $stoptime  = $stoptimes[$i];

            if ($stopplace) {
                push @placetimes, $stoptime;

                #    if ( $stopplace ne $previous_stopplace ) {
                #        push @placetimes, $stoptime;
                #        $previous_stopplace = $stopplace;
                #    }
                #    elsif ($stoptime) {
                #        $placetimes[-1] = $stoptime;
                #    }

            }
        }

        $trip->set_placetime_r( \@placetimes );
    } ## tidy end: foreach my $trip (@trips)

} ## tidy end: sub build_placetimes_from_stoptimes

#################################
## METHODS

sub lines {

    # It would be nice to make this a lazy attribute, but the Trip objects
    # can change.

    # Trips are kept read-write so that AVL and headways can be merged --
    # would it be better to have them be readonly,
    # and create new sked objects each time?

    my $self = shift;

    my $line_r;
    my %seen_line;

    foreach my $trip ( $self->trips() ) {
        $seen_line{ $trip->line() } = 1;
    }

    return sortbyline( keys %seen_line );

} ## tidy end: sub lines

sub has_multiple_lines {
    my $self   = shift;
    my @lines = $self->lines;
    return @lines > 1;
}

sub daysexceptions {

    my $self = shift;

    my %seen_daysexceptions;

    foreach my $trip ( $self->trips() ) {
        $seen_daysexceptions{ $trip->daysexceptions } = 1;
    }

    return sort keys %seen_daysexceptions;

}

sub has_multiple_daysexceptions {
    my $self           = shift;
    my @daysexceptions = $self->daysexceptions;
    return @daysexceptions > 1;
}

sub divide_sked {
    my $self = shift;

    my @lines = $self->lines();

    my %linegroup_of;
    foreach (@lines) {
        $linegroup_of{$_} = ( $LINES_TO_COMBINE{$_} || $_ );

        #        $linegroup_of{$_} = ( $_ );
    }

    my %linegroups;
    $linegroups{$_} = 1 foreach ( values %linegroup_of );
    my @linegroups = keys %linegroups;

    if ( scalar(@linegroups) == 1 ) {  # there's just one linegroup, return self
        $self->set_linegroup( $lines[0] );

        if ( $linegroups{'97'} ) {
            print '';                  # DEBUG - breakpoint
        }

        $self->delete_blank_columns;

        # override Scheduling's linegroup with the first line
        return $self;
    }

    # More than one linegroup! Split apart

    my ( %trips_of, @newskeds );

    # collect trips for each one in %trips_of
    foreach my $trip ( $self->trips ) {
        my $linegroup = $linegroup_of{ $trip->line };
        push @{ $trips_of{$linegroup} }, $trip;
    }

    foreach my $linegroup (@linegroups) {

        my %value_of;

        # collect all other attribute values in %values_of
        # This is a really primitive clone routine and might arguably
        # be better replaced by something based on MooseX::Clone or some other
        # "real" deep clone routine.

        foreach my $attribute ( $self->meta->get_all_attributes ) {

            # meta-objects! woohoo! screw you, Mouse!

            my $attrname = $attribute->name;
            next if $attrname eq 'trip_r' or $attrname eq 'linegroup';

            my $value = $self->$attrname;
            if ( ref($value) eq 'ARRAY' ) {
                $value = [ @{$value} ];
            }
            elsif ( ref($value) eq 'HASH' ) {
                $value = { %{$value} };
            }    # purely speculative as there are no hash attributes right now

            # use of "ref" rather than "reftype" is intentional here. We don't
            # want to clone objects this way.

            $value_of{$attrname} = $value;
        }    ## <perltidy> end foreach my $attribute ( $self...)

        my $newsked = Actium::Sked->new(
            trip_r    => $trips_of{$linegroup},
            linegroup => $linegroup,
            %value_of,
        );

        $newsked->delete_blank_columns;

        push @newskeds, $newsked;

    }    ## <perltidy> end foreach my $linegroup (@linegroups)

    return @newskeds;

}    ## <perltidy> end sub divide_sked

sub placetime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->placetime_count - 1 ) {
            push @{ $columns[$i] }, $trip->placetime($i);
        }
    }

    return @columns;
}

sub stoptime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->stoptime_count - 1 ) {
            push @{ $columns[$i] }, $trip->stoptime($i);
        }
    }

    return @columns;
}

sub attribute_columns {

    my $self    = shift;
    my @readers = @_;
    # reader method, generally the same as the attribute name
    my %column_of;

    my @trips = $self->trips;

    foreach my $trip ( $self->trips ) {
        foreach my $reader (@readers) {
            push @{ $column_of{$reader} }, $trip->$reader;
        }
    }

    foreach my $reader (@readers) {
        if ( none { defined and $_ ne $EMPTY_STR } @{ $column_of{$reader} } ) {
            delete $column_of{$reader};
        }
    }
    return \%column_of;

} ## tidy end: sub attribute_columns

sub delete_blank_columns {
    my $self = shift;

    if ( not $self->trip(0)->placetimes_are_empty ) {
        my @placetime_cols_to_delete;

        my @columns_of_times = $self->placetime_columns;
        my $has_place8s      = not $self->place8s_are_empty;
        my $has_place4s      = not $self->place4s_are_empty;

        my $place_id_count = $self->place_count;
        my $placecount = max( $place_id_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $placecount ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @placetime_cols_to_delete, $i;
                next                     if $i > $place_id_count;
                $self->delete_place8($i) if ($has_place8s);
                $self->delete_place4($i) if ($has_place4s);

            }
        }

        foreach my $trip ( $self->trips ) {
            my $placetime_count = $trip->placetime_count;
            foreach my $i (@placetime_cols_to_delete) {
                next if $i > $placetime_count;
                $trip->delete_placetime($i);
            }
        }
    } ## tidy end: if ( not $self->trip(0...))

    if ( not $self->trip(0)->stoptimes_are_empty ) {

        my @stoptimes_cols_to_delete;

        my @columns_of_times = $self->stoptime_columns;
        my $stopid_count     = $self->stop_count;
        my $stopcount        = max( $stopid_count, $#columns_of_times );

        for my $i ( reverse( 0 .. $stopcount ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @stoptimes_cols_to_delete, $i;
                next if $i > $stopid_count;
                $self->delete_stopid($i);
                $self->delete_stopplace($i);
            }
        }

        foreach my $trip ( $self->trips ) {
            my $stoptime_count = $trip->stoptime_count;
            foreach my $i (@stoptimes_cols_to_delete) {
                next if $i > $stoptime_count;
                $trip->delete_stoptime($i);
            }
        }

    } ## tidy end: if ( not $self->trip(0...))

    return;

}    ## <perltidy> end sub delete_blank_columns

sub id {
    my $self = shift;
    return $self->skedid;
}

sub skedid {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->dircode, $self->daycode ) );
}

sub sortable_id {
    my $self = shift;
    my $linegroup = linekeys( $self->linegroup || $self->oldlinegroup );
    $linegroup =~ s/\0/ /g;
    my $dir = $self->dir_obj->as_sortable;

    my $earliest_timenum = $self->earliest_timenum;
    $earliest_timenum = 0 if $earliest_timenum < 0;
    $earliest_timenum = linekeys( $self->earliest_timenum );

    return join( "\t", $linegroup, $self->daycode, $earliest_timenum, $dir );
}

sub dump {
    my $self = shift;
    require Data::Dump;
    my $dumped = Data::Dump::dump($self);

    #require Perl::Tidy;
    #my $tidy;
    #Perl::Tidy::perltidy(
    #    source      => \$dumped,
    #    destination => \$tidy,
    #    argv        => '',
    #);
    #return $tidy;
    # the perltidy thing is cool but very slow

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

    my $timesub = timestr_sub( SEPARATOR => $EMPTY_STR );

    my @place_records;

    my %title_of = qw(
      blockid        BLK
      daysexceptions EXC
      from           FM
      noteletter     NOTE
      pattern        PAT
      runid          RUN
      to             TO
      type           TYPE
      typevalue      TYPVAL
      vehicledisplay VDISP
      via            VIA
      viadescription VIADESC
      sortable_days  DAY
      vehicletype    VT
      line           -LN
      internal_num   INTNUM
    );

    my %column_of = %{ $self->attribute_columns( sort keys %title_of ) };

    my @fields = sort { $title_of{$a} cmp $title_of{$b} } keys %column_of;

    push @place_records, [ ($EMPTY_STR) x scalar @fields, $self->place4s ];
    push @place_records, [ @title_of{@fields}, $self->place8s ];

    my @trips = $self->trips;

    foreach my $trip (@trips) {
        push @place_records,
          [ (map { $trip->$_ } @fields) , $timesub->( $trip->placetimes ) ];
    }

    say $out jn( @{ tabulate_arrayrefs(@place_records) } ) , "\n";
    # extra \n for a blank line to separate places and stops

    my @stop_records;

    push @stop_records, [ $self->stopids ];
    push @stop_records, [ $self->stopplaces ];

    foreach my $trip (@trips) {
        push @stop_records, [ $timesub->( $trip->stoptimes ) ];
    }

    say $out jn( @{ tabulate_arrayrefs(@stop_records) } );
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

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

