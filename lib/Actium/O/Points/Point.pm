package Actium::O::Points::Point 0.013;

# This object is used for *display*, and should probably be called something
# that relates to that.

# The object Actium::O::Points is used to hold unformatted data.

# This really needs to be refactored to get rid of the awful use of
# global variables.
use warnings;
use strict;

use 5.022;

use sort ('stable');

use Actium::Moose;

use Actium::Sorting::Line (qw(byline sortbyline));
use List::Compare::Functional('get_unique');    ### DEP ###
use Actium::EffectiveDate ('newest_date');
use Actium::O::DateTime;

const my $IDPOINTFOLDER => 'idpoints2016';
const my $KFOLDER       => 'kpoints';

use Actium::O::Points::Column;

use Actium::Text::InDesignTags;
const my $IDT          => 'Actium::Text::InDesignTags';
const my $BOXBREAK     => $IDT->boxbreak;
const my $BLANK_COLUMN => ( $BOXBREAK x 2 );
const my $NBSP         => $IDT->nbsp;

has [qw/stopid signid delivery agency/] => (
    is  => 'ro',
    isa => 'Str',
);

has effdate => (
    is     => 'ro',
    writer => '_set_effdate',
    isa    => 'Actium::O::DateTime',
);

has signup => (
    is  => 'ro',
    isa => 'Actium::O::Folders::Signup',
);

has nonstoplocation => (
    is  => 'ro',
    isa => 'Maybe[Str]',
);

has smoking => (
    is      => 'ro',
    isa     => 'Str',
    default => $EMPTY,
);

has error_r => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        errors     => 'elements',
        push_error => 'push',
    },
);

has heights => (
    is  => 'rw',
    isa => 'Str',
);

has region_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'omitted_of_stop_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    default => sub { {} },
    handles => {
        allstopids       => 'keys',
        omitted_of       => 'get',
        _allstopid_count => 'count',
        _get_allstopid   => 'get',
    },
);

has 'is_simple_stopid' => (
    is      => 'ro',
    builder => '_build_is_simple_stopid',
    lazy    => 1,
);

sub _build_is_simple_stopid {
    my $self = shift;
    return 0 if $self->_allstopid_count > 1;
    my $only_multi_stopid = ( $self->allstopids )[0];
    return 0 if $only_multi_stopid ne $self->stopid;
    return 1;
}

has 'note600' => (
    traits  => ['Bool'],
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
    handles => { set_note600 => 'set', },
);

has 'has_ab' => (
    traits  => ['Bool'],
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
    handles => { set_has_ab => 'set', },
);

has 'column_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Maybe[Actium::O::Points::Column]]',
    default => sub { [] },
    handles => {
        columns      => 'elements',
        push_columns => 'push',
        sort_columns => 'sort_in_place',
    },
);

has 'marker_of_footnote_r' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    default => sub { {} },
    handles => {
        get_marker_of_footnote      => 'get',
        set_marker_of_footnote      => 'set',
        elements_marker_of_footnote => 'elements',
    },

);

has 'highest_footnote' => (
    traits  => ['Counter'],
    default => 0,
    is      => 'rw',
    isa     => 'Num',
    handles => { inc_highest_footnote => 'inc', }
);

has 'formatted_side' => (
    traits  => ['String'],
    default => $EMPTY_STR,
    is      => 'rw',
    isa     => 'Str',
);

has 'formatted_bottom' => (
    traits  => ['String'],
    default => $EMPTY_STR,
    is      => 'rw',
    isa     => 'Str',
);

has 'width' => (
    isa     => 'Num',
    is      => 'rw',
    default => 0,
);

has subtype => (
    isa => 'Str',
    is  => 'rw',
);

sub add_to_width {
    my $self = shift;
    $self->set_width( $self->width + $_[0] );
    return;
}

my $i18n_all_cr = sub {
    my $i18n_id = shift;

    no warnings 'once';
    my @all = $Actium::Cmd::MakePoints::actiumdb->i18n_all_indd($i18n_id);

};

sub new_from_kpoints {
    my ($class, $stopid, $signid,
        # $effdate,
        $agency, $omitted_of_stop_r,
        $nonstoplocation, $smoking, $delivery,
        $signup
    ) = @_;

    my $self = $class->new(
        stopid => $stopid,
        signid => $signid,
        #effdate           => $effdate,
        agency            => $agency,
        nonstoplocation   => $nonstoplocation,
        smoking           => $smoking,
        omitted_of_stop_r => $omitted_of_stop_r,
        delivery          => $delivery,
        signup            => $signup,
    );
    my $is_simple = $self->is_simple_stopid;

    foreach my $stop_to_import ( $self->allstopids ) {

        my $column_stopid = $is_simple ? $EMPTY_STR : $stop_to_import;

        my %do_omit_line
          = map { $_, 1 } @{ $self->omitted_of($stop_to_import) };
        my ( %found_line, @found_linedirs );

        my $kpointdir = substr( $stop_to_import, 0, 3 ) . 'xx';

        my $kpointfile = "$KFOLDER/$kpointdir/$stop_to_import.txt";

        my $kpoint = $signup->open_read($kpointfile);

        my (%bsn_columns);

        while (<$kpoint>) {

            chomp;
            my $column = Actium::O::Points::Column->new( $_, $column_stopid );

            my $linegroup = $column->linegroup;

            push @found_linedirs, $linegroup;
            my $dircode = $column->dircode;

            my $transitinfo_dir = $DIRCODES[ $HASTUS_DIRS[$dircode] ];

            my $linedir = "$linegroup-$transitinfo_dir";
            push @found_linedirs, $linedir;

            next if $do_omit_line{$linedir};
            next if $do_omit_line{$linegroup};

            # BSH handling

            if ( $agency eq 'BroadwayShuttle' ) {
                if ( $linegroup eq 'BSD' or $linegroup eq 'BSH' ) {
                    $self->push_columns($column);
                }
                elsif ( $linegroup eq 'BSN' ) {
                    $bsn_columns{ $column->days } = $column;
                }
                next;
            }
            else {
                next
                  if ( $linegroup eq 'BSD'
                    or $linegroup eq 'BSH'
                    or $linegroup eq 'BSN' );
            }

            if ( $agency eq 'DumbartonExpress' ) {
                if ( $linegroup =~ /^DB/ ) {
                    $self->push_columns($column);
                }
                next;
            }
            else {
                next if ( $linegroup =~ /^DB/ );
            }

            next if $linegroup =~ /^4\d\d/;

            if ( $linegroup !~ /^6\d\d/ ) {
                $self->push_columns($column);
            }    # skip 600-series lines
            else {
                $self->set_note600;
            }

            if ( $dircode eq '14' or $dircode eq '15' ) {
                $self->set_has_ab;
            }

        } ## tidy end: while (<$kpoint>)

        close $kpoint or die "Can't close $kpointfile: $!";

        # ugly kludge for BSH weekday/Friday/Saturday skeds

        if ( scalar keys %bsn_columns ) {
            my $weekday  = $bsn_columns{'12345'};
            my $friday   = $bsn_columns{'5'};
            my $saturday = $bsn_columns{'6'};

            $self->push_columns($weekday);
         # the header formatting is changed so it changes it to "M-TH only"
         # This will really screw up if there are any day exceptions in it later

            my %is_a_fri_time
              = map { $_ => 1 } ( $weekday->times, $friday->times );

            my @sat_exceptions;

            foreach my $i ( 0 .. $saturday->time_count - 1 ) {
                my $sat_time = $saturday->time($i);
                push @sat_exceptions, $is_a_fri_time{$sat_time} ? '' : '6';
            }

            $saturday->_set_exception_r( \@sat_exceptions );

            $self->push_columns($saturday);

        } ## tidy end: if ( scalar keys %bsn_columns)

        my @notfound
          = get_unique( [ [ keys %do_omit_line ], \@found_linedirs ] );

        if (@notfound) {
            my $linetext = @notfound > 1 ? 'Lines' : 'Line';
            my $lines = u::joinseries(@notfound);
            $self->push_error(
                "$linetext $lines found in omit list but not in schedule data."
            );
        }

    } ## tidy end: foreach my $stop_to_import ...

    my @all_lines = u::uniq( map { $_->lines } $self->columns );

    my @dates
      = map { $Actium::Cmd::MakePoints::lines{$_}{TimetableDate} } @all_lines;
      
    $self->_set_effdate( Actium::O::DateTime->new( newest_date(@dates) ) );

    return $self;

}    ## <perltidy> end sub new_from_kpoints

sub make_headers_and_footnotes {

    my $self = shift;

    # make header items

    #my %seen_feet;

  COLUMN:
    foreach my $column ( $self->columns ) {

        next COLUMN if ( $column->has_note );

        my ( %seen, %primary );

        my @attrs = (qw<line destination exception approxflag>);

        foreach my $attr (@attrs) {
            foreach my $i ( 0 .. $column->time_count - 1 ) {
                $seen{$attr}{ $column->$attr($i) }++;
            }
            $primary{$attr} = most_frequent( %{ $seen{$attr} } );
            my $set_primary_attr = "set_primary_$attr";
            $column->$set_primary_attr( $primary{$attr} );
        }

        my @head_lines = sortbyline keys %{ $seen{line} };
        $column->set_head_line_r( \@head_lines );

        # if more than one line, mark the footnote to it as being seen
        #if ($#head_lines) {
        #    $seen_feet{ "." . $column->primary_line }++;
        #}

        # footnote to column header is shown as ".line" .
        # So if it has a period, it's a note to column header;
        # if it has a colon, it's a note to one of the times
        # in the column.

        foreach my $i ( 0 .. $column->time_count - 1 ) {

            my %foot_of;

            foreach my $attr (@attrs) {
                my $item        = $column->$attr($i);
                my $primaryattr = "primary_$attr";
                my $primaryitem = $column->$primaryattr;
                $foot_of{$attr} = $item eq $primaryitem ? $EMPTY_STR : $item;
            }

            if ( join( $EMPTY_STR, values %foot_of ) eq $EMPTY_STR ) {
                $column->set_foot( $i, $EMPTY_STR );
            }
            else {
                my $foot = join( ':', @foot_of{@attrs} );
                $column->set_foot( $i, $foot );

                #$seen_feet{$foot} = 1;
            }

        }    ## <perltidy> end foreach my $i ( 0 .. $column...)

    }    ## <perltidy> end foreach my $column ( $self->columns)

    #$self->set_seen_foot_r( [ keys %seen_feet ] );

    return;

}    ## <perltidy> end sub make_headers_and_footnotes

sub most_frequent {
    my %hash = @_;
    my @list = sort { $hash{$b} <=> $hash{$a} } keys %hash;
    return $list[0];
}

sub adjust_times {

    # TODO later

    return;

}

my $ewreplace = sub {
    my $dircode = shift;
    $dircode =~ tr/23/32/;
    # we want westbound sorted before eastbound,
    # because transbay lines work that way. Usually.
    #
    # I think the right thing to do here would actually be to sort
    # directions by the earliest time in the column... but too hard
    # for now.
    return $dircode;
};

sub sort_columns_and_determine_heights {

    my ( $self, $signtype ) = @_;

    $signtype =~ s/=.*\z//;
    # Don't allow specifying a subtype manually
    # -- it will just treat it as though it were a main type

    #my @subtypes = sort grep {/$signtype=[A-Z]+\z/}
    #  keys %Actium::Cmd::MakePoints::signtypes;

    if ( not( exists( $Actium::Cmd::MakePoints::templates_of{$signtype} ) ) ) {

        $self->no_subtype($signtype);
        return;
    }

    my @subtypes
      = sort keys %{ $Actium::Cmd::MakePoints::templates_of{$signtype} };

    if ( @subtypes == 0 ) {
        $self->no_subtype($signtype);
        return;
    }

    my $subtype = $self->determine_subtype( $signtype, @subtypes );
    unless ($subtype) {
        $self->no_subtype($signtype);
        return "!";
    }

    $self->set_subtype($subtype);

    return $subtype;

} ## tidy end: sub sort_columns_and_determine_heights

sub no_subtype {

    my $self     = shift;
    my $signtype = shift;

    foreach my $column ( $self->columns ) {
        $column->set_formatted_height(
            $Actium::Cmd::MakePoints::signtypes{$signtype}{TallColumnLines} );
    }

    return $self->sort_columns_by_route_etc;

}

my $takes_up_columns_cr = sub {

    my ( $col_height, @heights ) = @_;

    my $fits_in_cols = 0;

    foreach my $height (@heights) {
        $fits_in_cols += u::ceil( $height / $col_height );
    }

    return $fits_in_cols;

};

my $columnsort_cr = sub {
    my ( $aa, $bb ) = @_;
    return (
             byline( $aa->head_line(0), $bb->head_line(0) )
          or $ewreplace->( $aa->dircode ) <=> $ewreplace->( $bb->dircode )
          or $aa->days cmp $bb->days
          or $aa->primary_destination cmp $bb->primary_destination
    );

};

sub determine_subtype {
    my $self     = shift;
    my $signtype = shift;
    my @subtypes = @_;

    my @all_heights;

    # A "chunk" is a set of schedules that all are the same line and direction

    # A "region" is an area of a point schedule with the same number of columns

    # The idea is to determine whether all the chunks can fit in a single region

    my ( %columns_of_chunk, %heights_of_chunk );

    foreach my $column ( $self->columns ) {
        my $chunk_id
          = $column->head_line(0) . "_" . $ewreplace->( $column->dircode );

        my $height;
        if ( $column->has_note ) {
            $height = 9;    # height of drop off only note
        }
        else {
            $height = $column->time_count || 1;
        }
        # at least one time -- that used to be there for noteonly

        push @all_heights, $height;

        push @{ $heights_of_chunk{$chunk_id} }, $height;
        push @{ $columns_of_chunk{$chunk_id} }, $column;

    }

    @all_heights = reverse sort { $a <=> $b } @all_heights;
    $self->set_heights("@all_heights");

    my ($chosen_subtype, @chosen_regions, @chunkids_by_region,
        @columns_needed, $all_chunks_singular
    );

    my $first_run = 1;

  CHUNK_GROUPING:
    until ( $chosen_subtype or $all_chunks_singular ) {

        if ($first_run) {
            $first_run = 0;
        }
        else {

            # divide chunks into single schedules and try again

            my $chunkid_to_split
              = u::first { scalar( @{ $heights_of_chunk{$_} } ) > 1 }
            sort keys %heights_of_chunk;

            if ($chunkid_to_split) {
                my @heights = @{ $heights_of_chunk{$chunkid_to_split} };
                my @columns = @{ $columns_of_chunk{$chunkid_to_split} };

                delete $heights_of_chunk{$chunkid_to_split};
                delete $columns_of_chunk{$chunkid_to_split};

                for my $i ( 0 .. $#heights ) {
                    my $thischunkid = "$chunkid_to_split $i";
                    $heights_of_chunk{$thischunkid} = [ $heights[$i] ];
                    $columns_of_chunk{$thischunkid} = [ $columns[$i] ];
                }
            }
            else {
                $all_chunks_singular = 1;
            }

        } ## tidy end: else [ if ($first_run) ]

        my %tallest_of_chunk;
        foreach my $chunk_id ( keys %heights_of_chunk ) {
            $tallest_of_chunk{$chunk_id}
              = u::max( @{ $heights_of_chunk{$chunk_id} } );
        }

        my @chunkids_by_length = reverse
          sort { $tallest_of_chunk{$a} <=> $tallest_of_chunk{$b} || $b cmp $a }
          keys %tallest_of_chunk;

        # determine minimum fitting subtype

        #my ( @chosen_regions, @chunkids_by_region, @columns_needed );

      SUBTYPE:
        foreach my $subtype ( sort @subtypes ) {

            my @regions
              = @{ $Actium::Cmd::MakePoints::templates_of{$signtype}{$subtype}
              };

            @chunkids_by_region = ( [@chunkids_by_length] );

          REGION_ASSIGNMENT:
            while ( @{ $chunkids_by_region[0] } ) {

                @columns_needed = ();


              REGION:
                foreach my $i ( reverse( 0 .. $#chunkids_by_region ) ) {

                    # get the number of formatted columns required by all the
                    # columns in the chunks assigned to this region

                    my $columns_needed = 0;
                    foreach my $chunk_id ( @{ $chunkids_by_region[$i] } ) {
                        $columns_needed += $takes_up_columns_cr->(
                            $regions[$i]{height},
                            @{ $heights_of_chunk{$chunk_id} },
                        );
                    }

                    if ( $columns_needed > $regions[$i]{columns} ) {

                        # it doesn't fit

                        if ( $i == $#regions ) {
                            # Smallest region is filled, so it can't fit at all
                            next SUBTYPE;
                        }

                        # move a chunk from this region to the following region,
                        # and try a new region assignment

                        my $chunkid_to_move
                          = pop( @{ $chunkids_by_region[$i] } );

                        push @{ $chunkids_by_region[ $i + 1 ] },
                          $chunkid_to_move;

                        next REGION_ASSIGNMENT;

                    } ## tidy end: if ( $columns_needed >...)

                    $columns_needed[$i] = $columns_needed;

                } ## tidy end: REGION: foreach my $i ( reverse( 0 ...))

                # got through the last region, so they all must fit
                $chosen_subtype = $subtype;
                @chosen_regions = @regions;

                last SUBTYPE;

            } ## tidy end: REGION_ASSIGNMENT: while ( @{ $chunkids_by_region...})

        } ## tidy end: SUBTYPE: foreach my $subtype ( sort ...)

    } ## tidy end: CHUNK_GROUPING: until ( $chosen_subtype or...)

    my @texts = map { $_ // $EMPTY } @columns_needed;
    @texts = @chosen_regions;

    if ( not $chosen_subtype ) {
        my $signid = $self->signid;

        $self->push_error("Couldn't fit in any $signtype template");
        return;

    }

    #$self->set_region_count( scalar @chunkids_by_region );
    $self->set_region_count( scalar @chosen_regions );

    my @sorted_columns;

    foreach my $i ( 0 .. $#chosen_regions ) {

        if ( not $chunkids_by_region[$i] ) {
            my $column_count = $chosen_regions[$i]{columns};
            push @sorted_columns, (undef) x $column_count;
        }
        else {
            my @chunkids = @{ $chunkids_by_region[$i] };

            my @columns = map { @{ $columns_of_chunk{$_} } } @chunkids;

            @columns = sort { $columnsort_cr->( $a, $b ) } @columns;

            my $blank_columns_to_add
              = $chosen_regions[$i]{columns} - $columns_needed[$i];

            $columns[0]->set_previous_blank_columns($blank_columns_to_add);

            my $height = $chosen_regions[$i]{height};
            $_->set_formatted_height($height) foreach @columns;

            push @sorted_columns, @columns;
        }

    } ## tidy end: foreach my $i ( 0 .. $#chosen_regions)

    $self->set_column_r( \@sorted_columns );

    return $chosen_subtype;

} ## tidy end: sub determine_subtype

sub sort_columns_by_route_etc {
    my $self = shift;

 #    my $columnsort = sub {
 #        my ( $aa, $bb ) = @_;
 #        return (
 #                 byline( $aa->head_line(0), $bb->head_line(0) )
 #              or $ewreplace->( $aa->dircode ) <=> $ewreplace->( $bb->dircode )
 #              or $aa->days cmp $bb->days
 #              or $aa->primary_destination cmp $bb->primary_destination
 #        );
 #
 #    };

    $self->sort_columns($columnsort_cr);
    return;
}

sub format_columns {

    my ( $self, $signtype ) = @_;

  COLUMN:
    foreach my $column ( $self->columns ) {

        # format header, and footnote of header

        next unless defined $column;

        $column->format_header;    # everything except footnote

        my $blanks;
        if ( $column->previous_blank_columns ) {
            $blanks
              = $IDT->parastyle('amtimes')
              . $IDT->nocharstyle
              . ( ($BLANK_COLUMN) x ( $column->previous_blank_columns ) );
        }
        else {
            $blanks = $EMPTY;
        }

        if ( not( $column->has_note ) and $column->head_line_count > 1 ) {

            my $marker
              = $self->get_marker_of_footnote( '.' . $column->primary_line );
            unless ($marker) {
                $self->inc_highest_footnote;
                $marker = $self->highest_footnote;
                $self->set_marker_of_footnote( '.' . $column->primary_line,
                    $marker );
            }

            $column->append_to_formatted_header(
                $SPACE . $IDT->combi_foot($marker) );

        }

        # format times

        if ( $column->has_note ) {

            my $notetext;

            for ( $column->note ) {
                #if ( $_ eq 'LASTSTOP' ) {
                #$notetext = "Last Stop";
                #    next;
                #}
                if ( $_ eq 'DROPOFF' or $_ eq 'LASTSTOP' ) {
                    $notetext = join( $IDT->hardreturn,
                        $i18n_all_cr->('drop_off_only') );
                    #$notetext = "Drop Off Only";
                    next;
                }
#                if ( $_ eq '72R' ) {
#                    $notetext
#                      = 'Buses arrive about every 12 minutes '
#                      . $IDT->emdash
#                      . $IDT->softreturn
#                      . 'See information elsewhere on this sign.';
#                    next;
#                }
#                if ( $_ eq '1R-MIXED' ) {
#
#                    $notetext
#                      = 'Buses arrive about every 12 minutes weekdays, and 15 minutes weekends.'
#                      . ' (Weekend service to downtown Oakland only.) '
#                      . $IDT->softreturn
#                      . 'See information elsewhere on this sign.';
#
#                    next;
#                }
#
#                if ( $_ eq '1R' ) {
#
#                    if ( $column->days eq '12345' ) {
#                        $notetext
#                          = 'Buses arrive about every 12 minutes '
#                          . $IDT->emdash
#                          . $IDT->softreturn
#                          . 'See information elsewhere on this sign.';
#                    }
#                    else {
#
#                        $notetext
#                          = 'Buses arrive about every 12 minutes weekdays, 15 minutes weekends '
#                          . $IDT->emdash
#                          . $IDT->softreturn
#                          . 'See information elsewhere on this sign.';
#                    }
#
#                    next;
#                } ## tidy end: if ( $_ eq '1R' )

                $self->push_error('Unknown note $_');

            } ## tidy end: for ( $column->note )

            $column->set_formatted_column( $blanks
                  . $column->formatted_header
                  . $BOXBREAK
                  . $IDT->parastyle('noteonly')
                  . $notetext );

            $self->add_to_width(1);
            next COLUMN;

        } ## tidy end: if ( $column->has_note)

        my $prev_pstyle = $EMPTY_STR;

        foreach my $i ( 0 .. $column->time_count - 1 ) {

            my $time = $column->time($i);
            my $foot = $column->foot($i);

            my $ampm = chop($time);
            $ampm = 'a' if $ampm eq 'x';
            $ampm = 'p' if $ampm eq 'b';

            substr( $time, -2, 0 ) = ":";
            $time = "\t${time}$ampm";

            my $pstyle = $ampm eq 'a' ? 'amtimes' : 'pmtimes';
            if ( $prev_pstyle ne $pstyle ) {
                $prev_pstyle = $pstyle;
                $time        = $IDT->parastyle($pstyle) . $time;
            }

            if ($foot) {
                my $marker = $self->get_marker_of_footnote($foot);
                unless ($marker) {
                    $self->inc_highest_footnote;
                    $marker = $self->highest_footnote;
                    $self->set_marker_of_footnote( $foot, $marker );
                }

                #$time .= $IDT->hairspace . $IDT->combi_foot($marker);
                $time .= $IDT->combi_foot($marker);
            }

            $column->set_formatted_time( $i, $time );

        }    ## <perltidy> end foreach my $i ( 0 .. $column...)

        my $column_length = $column->formatted_height;
        #my $column_length
        #  = $Actium::Cmd::MakePoints::signtypes{$signtype}{TallColumnLines};
        my $formatted_columns;

        if ($column_length) {

            my $count = $column->formatted_time_count;
            my $width = u::ceil( $count / $column_length );
            $column_length = u::ceil( $count / $width );

            my @ft;
            my $iterator = u::natatime $column_length, $column->formatted_times;
            while ( my @formatted_times = $iterator->() ) {
                push @ft, join( "\r", @formatted_times );
            }

            $self->add_to_width( scalar @ft );

            $formatted_columns = join( ( ( $BOXBREAK x 2 ) ), @ft );
            # one column to get to header, one to get to next schedule box

        }
        else {    # no entry for TallColumnLines in Signtype table
            $formatted_columns = join( "\r", $column->formatted_times );
            $self->add_to_width(1);
        }

        $column->set_formatted_column( $blanks
              . $column->formatted_header
              . $BOXBREAK
              . $formatted_columns );

    }    ## <perltidy> end foreach my $column ( $self->columns)

}    ## <perltidy> end sub format_columns

sub format_side {
    my $self    = shift;
    my $signid  = $self->signid;
    my $effdate = $self->effdate;
    my $is_bsh  = $self->agency eq 'BroadwayShuttle';

    my $formatted_side;
    open my $sidefh, '>:utf8', \$formatted_side;

    print $sidefh $self->_effective_date_indd($is_bsh);

    #my $effective_dates
    #  = $Actium::Cmd::MakePoints::actiumdb->agency_effective_date_indd(
    #    'effective_colon', $color );

    print $sidefh $IDT->hardreturn, $IDT->parastyle('sidenotes');
    # blank line to separate effective dates from side notes

#      'Light Face = a.m.', $IDT->softreturn;
#    print $sidefh $IDT->bold_word('Bold Face = p.m.'), "\r";
#
#    if ( $self->has_ab ) {
#        print $sidefh
#'Lines that have <0x201C>A Loop<0x201D> and <0x201C>B Loop<0x201D> travel in a circle, beginning ',
#          'and ending at the same point. The A Loop operates in the clockwise ',
#          'direction. The B Loop operates in the counterclockwise direction. ',
#'Look for <0x201C>A<0x201D> or <0x201C>B<0x201D> at the right end of the headsign on the bus. ',
#          "\r";
#    }

    my $sidenote = $Actium::Cmd::MakePoints::signs{$signid}{Sidenote};

    if ( $sidenote and ( $sidenote !~ /^\s+$/ ) ) {
        $sidenote =~ s/\n/\r/g;
        $sidenote =~ s/\r+/\r/g;
        $sidenote =~ s/\r+$//;
        $sidenote =~ s/\0+$//;

        $sidenote = $IDT->encode_high_chars($sidenote);

        if ($is_bsh) {
            print $sidefh $IDT->hardreturn, $IDT->parastyle('BSHsidenotes'),
              $sidenote;
        }
        else {

            print $sidefh $IDT->hardreturn, $IDT->parastyle('sidenotes'),
              $IDT->bold_word($sidenote);
        }
    }

    print $sidefh $self->format_sidenotes;

    if ( $self->note600 ) {
        print $sidefh $IDT->hardreturn,
          join( $IDT->hardreturn, $i18n_all_cr->('note_600') );
    }

    close $sidefh;

    $formatted_side =~ s/\r+$//;

    $self->set_formatted_side($formatted_side);

} ## tidy end: sub format_side

# TODO - allow all values in Actium::O::Days
my %text_of_exception = (
    SD     => 'school days only',
    SH     => 'school holidays only',
    '1234' => 'weekdays except Fridays',
    '5'    => 'Fridays only',
    '6'    => 'Saturdays only',
);

sub format_sidenotes {

    my $self = shift;
    return $EMPTY unless $self->highest_footnote;

    my %foot_of = reverse $self->elements_marker_of_footnote;

    my $formatted_sidenotes = '';
    open my $sidefh, '>:utf8', \$formatted_sidenotes;

  NOTE:
    for my $i ( 1 .. $self->highest_footnote ) {

        print $sidefh $IDT->hardreturn, $IDT->parastyle('sidenotes');

        print $sidefh $IDT->combi_side($i), $SPACE;

        my $foot = $foot_of{$i};

        if ( $foot =~ /^\./ ) {
            my $line;
            ( undef, $line ) = split( /\./, $foot );
            print $sidefh
              "Unless marked, times in this column are for line $line.";
            next NOTE;
        }

        my @attrs = qw(line destination exception approxflag);
        my (%attr);
        my $attrcode = $EMPTY_STR;

        @attr{@attrs} = split( /:/, $foot, scalar @attrs );
        # scalar @attrs sets the LIMIT field, so it doesn't delete empty
        # trailing entries, see split in perldoc perlfunc for info on LIMIT

        $attr{approxflag} = 2 if $attr{approxflag} eq '0';

        foreach ( sort @attrs ) {
            $attrcode .= substr( $_, 0, 1 ) if $attr{$_};
        }

        #print "[[$attrcode]]";

        my ( $line, $dest, $exc, $app );
        $line = $attr{line} if $attr{line};

        if ( $attr{destination} ) {
            $dest = $attr{destination};
            $dest =~ s/\.*$/\./;
        }

        # TODO - Update to allow all values in Actium::O::Days
        if ( $attr{exception} ) {
            $exc = $text_of_exception{ $attr{exception} };
        }

        #$exc = (
        #    $attr{exception} eq 'SD'
        #    ? 'school days only'
        #    : 'school holidays only'
        #) if $attr{exception};
        $app
          = $attr{approxflag} eq '1'
          ? 'approximate departure time'
          : 'scheduled departure time'
          if $attr{approxflag};

        for ($attrcode) {
            if ( $_ eq 'a' )  { print $sidefh "\u$app.";          next; }
            if ( $_ eq 'ad' ) { print $sidefh "\u$app, to $dest"; next; }
            if ( $_ eq 'ade' ) {
                print $sidefh "\u$app. Operates $exc to $dest";
                next;
            }
            if ( $_ eq 'adel' ) {
                print $sidefh "\u$app for Line $line. Operates $exc to $dest";
                next;
            }
            if ( $_ eq 'ae' ) {
                print $sidefh "\u$app. Operates $exc.";
                next;
            }
            if ( $_ eq 'ael' ) {
                print $sidefh "\u$app for Line $line. Operates $exc.";
                next;
            }
            if ( $_ eq 'al' ) {
                print $sidefh "\u$app for Line $line.";
                next;
            }
            if ( $_ eq 'd' ) { print $sidefh "To $dest"; next; }
            if ( $_ eq 'de' ) {
                print $sidefh "Operates $exc to $dest";
                next;
            }
            if ( $_ eq 'del' ) {
                print $sidefh "Line $line. Operates $exc to $dest";
                next;
            }
            if ( $_ eq 'dl' ) {
                print $sidefh "Line $line, to $dest";
                next;
            }
            if ( $_ eq 'e' ) { print $sidefh "Operates $exc."; next; }
            if ( $_ eq 'el' ) {
                print $sidefh "Line $line. Operates $exc.";
                next;
            }
            if ( $_ eq 'l' ) { print $sidefh "Line $line."; next; }
        }    ## <perltidy> end given

    }    ## <perltidy> end for my $i ( 1 .. $self->highest_footnote)

    close $sidefh;

    return $formatted_sidenotes;

}    ## <perltidy> end sub format_side

sub format_bottom {

    # As of SU16, the order of the boxes is:
    # o) Columns of text
    # o) Stop ID
    # o) Smoking blurb
    # o) bottom notes
    # o) side notes (possibly more than one)

    my $self = shift;

    my $signid = $self->signid;
    my $stopid = $self->stopid;

    my $formatted_bottom;
    open my $botfh, '>:utf8', \$formatted_bottom;

    ##### STOP ID BOX ####

    if ( $self->is_simple_stopid ) {
        print $botfh $IDT->parastyle('stopidintro'),
          join( $IDT->hardreturn, $i18n_all_cr->('stop_id') ),
          $IDT->hardreturn,
          $IDT->parastyle('stopidnumber'), $stopid;
    }
    print $botfh $BOXBREAK;    # if not simple, leave blank

    ### SMOKING BOX ####

    print $botfh $IDT->parastyle('bottomnotes'),
      $IDT->encode_high_chars_only( $self->smoking ), $BOXBREAK;

    ### BOTTOM BOX ####

    no warnings('once');
    my $stop_r = $Actium::Cmd::MakePoints::stops{$stopid};

    my $nonstoplocation = $self->nonstoplocation;

    my $description = $nonstoplocation || $stop_r->{c_description_full};

    $IDT->encode_high_chars($description);

    print $botfh $IDT->parastyle('bottomnotes'), $description;

    print $botfh ". Sign #$signid.";

    print $botfh " Stop $stopid." unless $nonstoplocation;
    
    print $botfh " Shelter site #"
      . $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum} . "."
      if $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum};
      
    if ($Actium::Cmd::MakePoints::signs{$signid}{SignType} !~ /\ATID/i ) {

       print $botfh '<DefineTextVariable:Output Date=<TextVarType:OutputDate>';
       print $botfh '<tvDateFormat:MMMM d\, yyyy>>';
       print $botfh ' Printed <cPageNumType:TextVariable>';
       print $botfh '<TextVarName:Output Date><cPageNumType:>.'; 
    
    }

    close $botfh;

    $self->set_formatted_bottom($formatted_bottom);

} ## tidy end: sub format_bottom

sub output {

    my $self = shift;

    my $signid = $self->signid;

    my $pointdir = $self->signup->subfolder($IDPOINTFOLDER);

    my $fh = $pointdir->open_write("$signid.txt");

    print $fh $IDT->start, $IDT->nocharstyle;

    if ( not defined $self->subtype ) {
        # output blank columns at beginning
        # if subtype is defined, was already done in determine_subtype()

        my $maxcolumns
          = $Actium::Cmd::MakePoints::signtypes{
            $Actium::Cmd::MakePoints::signs{$signid}{SignType}
          }{TallColumnNum};

        if ( $maxcolumns and $maxcolumns > $self->width )
        {    # if there's an entry in SignTypes
            my $columns = $maxcolumns - ( $self->width );
            #print "[[$maxcolumns:" , $self->width , ":$columns]]";
            print $fh (
                $IDT->parastyle('amtimes'),
                $IDT->nocharstyle, $BLANK_COLUMN x $columns
            );
        }

    } ## tidy end: if ( not defined $self...)

    # output real columns

    foreach my $column ( $self->columns ) {
        if ( defined $column ) {
            print $fh $column->formatted_column;
        }
        else {
            print $fh $BOXBREAK;
        }
        print $fh $BOXBREAK;
    }

    # this order is new as of SU16

    print $fh $self->formatted_bottom;
    print $fh $BOXBREAK;
    print $fh $self->formatted_side;

    $fh->close;

} ## tidy end: sub output

const my %COLORS => (qw/0 Paper 1 Black/);

const my %SHADINGS => (
    qw/
      11  Gray20
      21  Gray20
      31  LineFern
      41  Gray20
      51  Gray20
      61  LineYellow
      71  Gray20
      81  LineSky
      91  Gray20
      101  Gray20
      111  Gray20
      121  LineLavender
      10  Grey80
      20  Grey80
      30/, 'New AC Green', qw/
      40  Grey80
      50  Grey80
      60/, 'Rapid Red', qw/
      70  Grey80
      80  LineBlue
      90  Grey80
      100  Grey80
      110  Grey80
      120  LineViolet/
);

const my @ALL_LANGUAGES => qw/en es zh/;

sub _effective_date_indd {
    my $self   = shift;
    my $dt     = $self->effdate;
    my $is_bsh = shift;

    my $i18n_id = 'effective_colon';

    my $metastyle = 'Bold';

    my $month   = $dt->month;
    my $oddyear = $dt->year % 2;
    my ( $color, $shading, $end );

    # EFFECTIVE DATE and colors
    if ($is_bsh) {
        $color   = $EMPTY;
        $shading = $EMPTY;
        $end     = $EMPTY;
    }
    else {
        $color   = $COLORS{$oddyear};
        $color   = $IDT->color($color);
        $shading = $SHADINGS{ $month . $oddyear };
        $shading = "<pShadingColor:$shading>";
        $end     = '<pShadingColor:>';
    }

    my $retvalue = $IDT->parastyle('sideeffective') . $shading . $color;

    my $i18n_row_r = $Actium::Cmd::MakePoints::actiumdb->i18n_row_r($i18n_id);

    my @effectives;
    foreach my $lang (@ALL_LANGUAGES) {
        my $method = "long_$lang";
        my $date   = $dt->$method;
        if ( $lang eq 'en' ) {
            $date =~ s/ /$NBSP/g;
        }

        $date = $IDT->encode_high_chars_only($date);
        $date = $IDT->language_phrase( $lang, $date, $metastyle );

        my $phrase = $i18n_row_r->{$lang};
        $phrase =~ s/\s+\z//;

        if ( $phrase =~ m/\%s/ ) {
            $phrase =~ s/\%s/$date/;
        }
        else {
            $phrase .= " " . $IDT->discretionary_lf . $date;
        }

        #$phrase = $IDT->language_phrase( $lang, $phrase, $metastyle );

        $phrase =~ s/<CharStyle:Chinese>/<CharStyle:ZH_Bold>/g;
        $phrase =~ s/<CharStyle:([^>]*)>/<CharStyle:$1>$color/g;

        push @effectives, $phrase;

    } ## tidy end: foreach my $lang (@ALL_LANGUAGES)

    return $retvalue . join( $IDT->hardreturn, @effectives ) . $end;

} ## tidy end: sub _effective_date_indd

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

