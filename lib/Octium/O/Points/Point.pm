package Octium::O::Points::Point 0.013;

# This object is used for *display*, and should probably be called something
# that relates to that.

# The object Octium::O::Points is used to hold unformatted data.

# This really needs to be refactored to get rid of the awful use of
# global variables.

use Actium ('class');
use Octium;

const my @HASTUS_DIRS => ( 0, 1, 3, 2, 4 .. scalar @DIRCODES );

use sort ('stable');

use List::Compare::Functional('get_unique');    ### DEP ###
use Octium::O::DateTime;

const my $IDPOINTFOLDER => 'idpoints2016';
const my $KFOLDER       => 'kpoints';

use Octium::O::Points::Column;

use Octium::Text::InDesignTags;
const my $IDT          => 'Octium::Text::InDesignTags';
const my $BOXBREAK     => $IDT->boxbreak;
const my $BLANK_COLUMN => ( $BOXBREAK x 2 );
const my $NBSP         => $IDT->nbsp;

has [
    qw/stopid signid delivery agency signtype
      description description_nocity city tidfile/
] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has copyquantity => (
    is      => 'ro',
    isa     => 'Int',
    default => '1',
);

has [qw/tallcolumnnum tallcolumnlines/] => (
    is      => 'ro',
    isa     => 'Int',
    default => 10,
);

has effdate => (
    is       => 'ro',
    isa      => 'Octium::O::DateTime',
    required => 1,
);

has signup => (
    is       => 'ro',
    isa      => 'Octium::O::Folders::Signup',
    required => 1,
);

has [qw/smoking workzone shelternum sidenote/] => (
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

has actiumdb => (
    is       => 'ro',
    isa      => 'Octium::O::Files::ActiumDB',
    required => 1,
);

has region_count => (
    is      => 'rw',
    isa     => 'Int',
    default => 0,
);

has 'omitted_of_stop_r' => (
    traits   => ['Hash'],
    is       => 'bare',
    isa      => 'HashRef[ArrayRef[Str]]',
    default  => sub { {} },
    required => 1,
    handles  => {
        allstopids       => 'keys',
        omitted_of       => 'get',
        _allstopid_count => 'count',
        _get_allstopid   => 'get',
    },
);

has 'templates_of_r' => (
    traits   => ['Hash'],
    is       => 'ro',
    isa      => 'HashRef',
    required => 1,
    handles  => {
        no_templates => 'is_empty',
        subtypes     => 'keys',
    },
);

has 'nonstop' => (
    traits   => ['Bool'],
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
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
    isa     => 'ArrayRef[Maybe[Octium::O::Points::Column]]',
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
    default => $EMPTY,
    is      => 'rw',
    isa     => 'Str',
);

has 'formatted_bottom' => (
    traits  => ['String'],
    default => $EMPTY,
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

sub _i18n_all {
    my $self    = shift;
    my $i18n_id = shift;

    no warnings 'once';
    my @all = $self->actiumdb->i18n_all_indd($i18n_id);

}

sub new_from_kpoints {

    my $class = shift;

    my $self = $class->new(@_);

    my $is_simple = $self->is_simple_stopid;

    foreach my $stop_to_import ( $self->allstopids ) {

        my $column_stopid = $is_simple ? $EMPTY : $stop_to_import;

        my %do_omit_line
          = map { $_, 1 } @{ $self->omitted_of($stop_to_import) };
        my ( %found_line, @found_linedirs );

        my $kpointdir = substr( $stop_to_import, 0, 3 ) . 'xx';

        my $kpointfile = "$KFOLDER/$kpointdir/$stop_to_import.txt";

        my $kpoint = $self->signup->open_read($kpointfile);

        my (%bsn_columns);

        while (<$kpoint>) {

            chomp;
            my $column = Octium::O::Points::Column->new( $_, $column_stopid );

            my $linegroup = $column->linegroup;

            my $line_agency
              = $Octium::Cmd::MakePoints::lines{$linegroup}{agency_id};
            next if $line_agency ne $self->agency;

            push @found_linedirs, $linegroup;
            my $dircode = $column->dircode;

            my $transitinfo_dir = $DIRCODES[ $HASTUS_DIRS[$dircode] ];

            my $linedir = "$linegroup-$transitinfo_dir";
            push @found_linedirs, $linedir;

            next if $do_omit_line{$linedir};
            next if $do_omit_line{$linegroup};

            #            # BSH handling
            #
            #            if ( $self->agency eq 'BroadwayShuttle' ) {
            #                if ( $linegroup eq 'BSD' or $linegroup eq 'BSN' ) {
            #                    $self->push_columns($column);
            #                }
            #                next;
            #            }

            #if ( $self->agency eq 'BroadwayShuttle' ) {
            #    if ( $linegroup eq 'BSD' or $linegroup eq 'BSH' ) {
            #        $self->push_columns($column);
            #    }
            #    elsif ( $linegroup eq 'BSN' ) {
            #        $bsn_columns{ $column->days } = $column;
            #    }
            #    next;
            #}
            #else {
            #    next
            #      if ( $linegroup eq 'BSD'
            #        or $linegroup eq 'BSH'
            #        or $linegroup eq 'BSN' );
            #}

            #            if ( $self->agency eq 'DumbartonExpress' ) {
            #                if ( $linegroup =~ /^DB/ ) {
            #                    $self->push_columns($column);
            #                }
            #                next;
            #            }
            #            else {
            #                next if ( $linegroup =~ /^DB/ );
            #            }

            next if $linegroup =~ /^[4]\d\d/;

            if ( $linegroup !~ /^6\d\d/ and not $column->has_note ) {
                $self->push_columns($column);
            }    # skip 600-series lines
                 # also skip columns with notes, since hte only note left
                 # is "drop off only" and the flags should cover that
            else {
                $self->set_note600;
            }

            if ( $dircode eq '14' or $dircode eq '15' ) {
                $self->set_has_ab;
            }

        }

        close $kpoint or die "Can't close $kpointfile: $!";

#        # ugly kludge for BSH weekday/Friday/Saturday skeds
#
#        if ( scalar keys %bsn_columns ) {
#            my $weekday  = $bsn_columns{'12345'};
#            my $friday   = $bsn_columns{'5'};
#            my $saturday = $bsn_columns{'6'};
#
#            $self->push_columns($weekday);
#         # the header formatting is changed so it changes it to "M-TH only"
#         # This will really screw up if there are any day exceptions in it later
#
#            my %is_a_fri_time
#              = map { $_ => 1 } ( $weekday->times, $friday->times );
#
#            my @sat_exceptions;
#
#            foreach my $i ( 0 .. $saturday->time_count - 1 ) {
#                my $sat_time = $saturday->time($i);
#                push @sat_exceptions, $is_a_fri_time{$sat_time} ? '' : '6';
#            }
#
#            $saturday->_set_exception_r( \@sat_exceptions );
#
#            $self->push_columns($saturday);
#
#        }

        my @notfound
          = get_unique( [ [ keys %do_omit_line ], \@found_linedirs ] );

        if (@notfound) {
            my $linetext = @notfound > 1 ? 'Lines' : 'Line';
            my $lines = Actium::joinseries( items => \@notfound );
            $self->push_error(
                "$linetext $lines found in omit list but not in schedule data."
            );
        }

    }

    return $self;

}

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

        my @head_lines = Actium::sortbyline keys %{ $seen{line} };
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
                $foot_of{$attr} = $item eq $primaryitem ? $EMPTY : $item;
            }

            if ( join( $EMPTY, values %foot_of ) eq $EMPTY ) {
                $column->set_foot( $i, $EMPTY );
            }
            else {
                my $foot = join( ':', @foot_of{@attrs} );
                $column->set_foot( $i, $foot );

                #$seen_feet{$foot} = 1;
            }

        }

    }

    #$self->set_seen_foot_r( [ keys %seen_feet ] );

    return;

}

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

    if ( $self->no_templates ) {
        $self->no_subtype($signtype);
        return;
    }

    my @subtypes = sort $self->subtypes;

    my $subtype = $self->determine_subtype( $signtype, @subtypes );
    unless ($subtype) {
        $self->no_subtype($signtype);
        return "!";
    }

    $self->set_subtype($subtype);

    return $subtype;

}

sub no_subtype {

    my $self     = shift;
    my $signtype = shift;

    foreach my $column ( $self->columns ) {
        $column->set_formatted_height( $self->tallcolumnlines );
    }

    return $self->sort_columns_by_route_etc;

}

my $takes_up_columns_cr = sub {

    my ( $col_height, @heights ) = @_;

    my $fits_in_cols = 0;

    foreach my $height (@heights) {
        $fits_in_cols += Actium::ceil( $height / $col_height );
    }

    return $fits_in_cols;

};

my $columnsort_cr = sub {
    my ( $aa, $bb ) = @_;
    return (
             Actium::byline( $aa->head_line(0), $bb->head_line(0) )
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

        push @all_heights,
          [ $height,
            join( "_", $column->linegroup, $column->days, $column->dircode )
          ];

        push @{ $heights_of_chunk{$chunk_id} }, $height;
        push @{ $columns_of_chunk{$chunk_id} }, $column;

    }

    @all_heights
      = reverse sort { $a->[0] <=> $b->[0] || Actium::byline( $a, $b ) }
      @all_heights;
    @all_heights = map { $_->[0] . ":" . $_->[1] } @all_heights;
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
              = Actium::first { scalar( @{ $heights_of_chunk{$_} } ) > 1 }
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

        }

        my %tallest_of_chunk;
        foreach my $chunk_id ( keys %heights_of_chunk ) {
            $tallest_of_chunk{$chunk_id}
              = Actium::max( @{ $heights_of_chunk{$chunk_id} } );
        }

        my @chunkids_by_length = reverse
          sort { $tallest_of_chunk{$a} <=> $tallest_of_chunk{$b} || $b cmp $a }
          keys %tallest_of_chunk;

        # determine minimum fitting subtype

        #my ( @chosen_regions, @chunkids_by_region, @columns_needed );

        my $templates_of_r = $self->templates_of_r;

      SUBTYPE:
        foreach my $subtype ( sort @subtypes ) {

          TAILFIRST:
            foreach my $tailfirst ( 1, 0 ) {

                my @regions = @{ $templates_of_r->{$subtype} };

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
                                next TAILFIRST;
                            }

                        # move a chunk from this region to the following region,
                        # and try a new region assignment
                            if ($tailfirst) {

                                my $chunkid_to_move
                                  = pop( @{ $chunkids_by_region[$i] } );

                                push @{ $chunkids_by_region[ $i + 1 ] },
                                  $chunkid_to_move;

                            }
                            else {

                                my $chunkid_to_move
                                  = shift( @{ $chunkids_by_region[$i] } );

                                unshift @{ $chunkids_by_region[ $i + 1 ] },
                                  $chunkid_to_move;

                            }

                            next REGION_ASSIGNMENT;

                        }

                        $columns_needed[$i] = $columns_needed;

                    }

                    # got through the last region, so they all must fit
                    $chosen_subtype = $subtype;
                    @chosen_regions = @regions;

                    last SUBTYPE;

                }

            }

        }

    }

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

    }

    $self->set_column_r( \@sorted_columns );

    return $chosen_subtype;

}

sub sort_columns_by_route_etc {
    my $self = shift;
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
                    $notetext = join(
                        $IDT->hardreturn,
                        $self->_i18n_all('drop_off_only')
                    );
                    #$notetext = "Drop Off Only";
                    next;
                }

                $self->push_error('Unknown note $_');

            }

            $column->set_formatted_column( $blanks
                  . $column->formatted_header
                  . $BOXBREAK
                  . $IDT->parastyle('noteonly')
                  . $notetext );

            $self->add_to_width(1);
            next COLUMN;

        }

        my $prev_pstyle = $EMPTY;

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

        }

        my $column_length = $column->formatted_height;
        my $formatted_columns;

        if ($column_length) {

            my $count = $column->formatted_time_count;
            my $width = Actium::ceil( $count / $column_length );
            $column_length = Actium::ceil( $count / $width );

            my @ft;
            my $iterator = Actium::natatime $column_length,
              $column->formatted_times;
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

    }

}

sub format_side {
    my $self   = shift;
    my $signid = $self->signid;
    my $is_bsh = $self->agency eq 'BroadwayShuttle';

    my $formatted_side;
    open my $sidefh, '>:utf8', \$formatted_side;

    print $sidefh $self->_effective_date_indd($is_bsh);

    print $sidefh $IDT->hardreturn, $IDT->parastyle('sidenotes');
    # blank line to separate effective dates from side notes

    my $sidenote = $self->sidenote;

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
          join( $IDT->hardreturn, $self->_i18n_all('note_600') );
    }

    close $sidefh;

    $formatted_side =~ s/\r+$//;

    $self->set_formatted_side($formatted_side);

}

# TODO - allow all values in Octium::O::Days
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
        my $attrcode = $EMPTY;

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

        # TODO - Update to allow all values in Octium::O::Days
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
        }

    }

    close $sidefh;

    return $formatted_sidenotes;

}

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
        if ( $self->agency eq 'BroadwayShuttle' ) {
            print $botfh $IDT->parastyle('BSHInfoStopID'), $stopid;
        }
        else {
            print $botfh $IDT->parastyle('stopidintro'),
              join( $IDT->hardreturn, $self->_i18n_all('stop_id') ),
              $IDT->hardreturn,
              $IDT->parastyle('stopidnumber'), $stopid;
        }
    }
    print $botfh $BOXBREAK;    # if not simple, leave blank

    ### SMOKING BOX ####

    print $botfh $IDT->parastyle('bottomnotes'),
      $IDT->encode_high_chars_only( $self->smoking ), $BOXBREAK;

    ### BOTTOM BOX ####

    no warnings('once');

    my $description = $self->description;

    $IDT->encode_high_chars($description);

    print $botfh $IDT->parastyle('bottomnotes'), "$description. Sign #$signid.";

    print $botfh " Stop $stopid." unless $self->nonstop;

    my $shelternum = $self->shelternum;

    print $botfh " Shelter site #$shelternum." if $shelternum;

    if ( $self->signtype !~ /\ATID/i ) {

        print $botfh '<DefineTextVariable:Output Date=<TextVarType:OutputDate>';
        print $botfh '<tvDateFormat:MMMM d\, yyyy>>';
        print $botfh ' Printed <cPageNumType:TextVariable>';
        print $botfh '<TextVarName:Output Date><cPageNumType:>.';

    }

    close $botfh;

    $self->set_formatted_bottom($formatted_bottom);

}

sub output {

    my $self = shift;

    my $signid = $self->signid;

    my $pointdir = $self->signup->subfolder($IDPOINTFOLDER);

    my $fh = $pointdir->open_write("$signid.txt");

    print $fh $IDT->start, $IDT->nocharstyle;

    if ( not defined $self->subtype ) {
        # output blank columns at beginning
        # if subtype is defined, was already done in determine_subtype()

        my $maxcolumns = $self->tallcolumnnum;

        if ( $maxcolumns and $maxcolumns > $self->width )
        {    # if there's an entry in SignTypes
            my $columns = $maxcolumns - ( $self->width );
            #print "[[$maxcolumns:" , $self->width , ":$columns]]";
            print $fh (
                $IDT->parastyle('amtimes'),
                $IDT->nocharstyle, $BLANK_COLUMN x $columns
            );
        }

    }

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

}

#const my %COLORS => (qw/0 Paper 1 Black/);
#

const my %STYLE_OF_MONTH => (
    qw/
      11  O
      21  O
      31  SpO
      41  O
      51  O
      61  SuO
      71  O
      81  FO
      91  O
      101  O
      111  O
      121  WO
      10  E
      20  E
      30  SpE
      40  E
      50  E
      60  SuE
      70  E
      80  FE
      90  E
      100 E
      110  E
      120  WE
      /
);

#const my %SHADINGS => (
#    qw/
#      11  Gray20
#      21  Gray20
#      31  LineFern
#      41  Gray20
#      51  Gray20
#      61  H103-Pink
#      71  Gray20
#      81  LineSky
#      91  Gray20
#      101  Gray20
#      111  Gray20
#      121  LineLavender
#      10  Grey80
#      20  Grey80
#      30/, 'New AC Green', qw/
#      40  Grey80
#      50  Grey80
#      60  LineMaroon
#      70  Grey80
#      80  LineBlue
#      90  Grey80
#      100  Grey80
#      110  Grey80
#      120  LineViolet/
#);

const my @ALL_LANGUAGES => qw/en es zh/;

sub _effective_date_indd {
    my $self   = shift;
    my $dt     = $self->effdate;
    my $is_bsh = shift;

    if ($is_bsh) {
        my $date = $dt->long_en;
        $date =~ s/ /$NBSP/g;
        return $IDT->parastyle('BSHsideeffective') . "Effective $date";
    }

    my $i18n_id = 'effective_colon';

    my $metastyle = 'Bold';

    my $month   = $dt->month;
    my $oddyear = $dt->year % 2;

    # EFFECTIVE DATE and colors
    #$color   = $COLORS{$oddyear};
    #$color   = $IDT->color($color);
    my $style = $STYLE_OF_MONTH{ $month . $oddyear };
    #$shading = "<pShadingColor:$shading>";
    #$end     = '<pShadingColor:>';

    my $retvalue = $IDT->parastyle( 'sideeffective-' . $style );

    my $i18n_row_r = $self->actiumdb->i18n_row_r($i18n_id);

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

        $phrase =~ s/<CharStyle:Chinese>/<CharStyle:ZH_Bold>/g;
        $phrase =~ s/<CharStyle:([^>]*)>/<CharStyle:$1>/g;

        push @effectives, $phrase;

    }

    return $retvalue . join( $IDT->hardreturn, @effectives );

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

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

