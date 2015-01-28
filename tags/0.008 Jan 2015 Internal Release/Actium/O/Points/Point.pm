# Actium/Points/Point.pm

# legacy stages 2 and 3

# This object is used for *display*, and should probably be called something
# that relates to that.

# The object Actium::O::Points is used to hold unformatted data.

use warnings;
use strict;

use 5.010;

package Actium::O::Points::Point 0.008;

use sort ('stable');

use Moose;
use MooseX::SemiAffordanceAccessor;
use Moose::Util::TypeConstraints;

use namespace::autoclean;
use Actium::Term;

use Actium::Util('joinseries');

use Actium::Constants;
use Actium::Sorting::Line (qw(byline sortbyline));
use List::MoreUtils('natatime');
use Const::Fast;
use List::Compare::Functional('get_unique');

use POSIX ();

use Actium::O::Points::Column;

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

has [qw/effdate stopid signid/] => (
    is  => 'ro',
    isa => 'Str',
);

has 'nonstoplocation' => (
    is  => 'ro',
    isa => 'Maybe[Str]',
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
    isa     => 'ArrayRef[Actium::O::Points::Column]',
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

has [qw<is_bsh is_db>] => (
    isa     => 'Bool',
    is      => 'rw',
    default => 0,
);

sub add_to_width {
    my $self = shift;
    $self->set_width( $self->width + $_[0] );
    return;
}

sub new_from_kpoints {
    my ( $class, $stopid, $signid, $effdate, $special_type,
        $omitted_of_stop_r, $nonstoplocation )
      = @_;

    my $self = $class->new(
        stopid            => $stopid,
        signid            => $signid,
        effdate           => $effdate,
        is_bsh            => ( $special_type eq 'bsh' ),
        is_db             => ( $special_type eq 'db' ),
        nonstoplocation   => $nonstoplocation,
        omitted_of_stop_r => $omitted_of_stop_r,
    );

    my $is_simple = $self->is_simple_stopid;

    foreach my $stop_to_import ( $self->allstopids ) {

        my $column_stopid = $is_simple ? $EMPTY_STR : $stop_to_import;

        my %do_omit_line
          = map { $_, 1 } @{ $self->omitted_of($stop_to_import) };
        my ( @found_lines, @found_linedirs );

        my $kpointdir = substr( $stop_to_import, 0, 3 ) . 'xx';

        my $kpointfile = "kpoints/$kpointdir/$stop_to_import.txt";

        open my $kpoint, '<', $kpointfile
          or die "Can't open $kpointfile: $!";

        my (%bsn_columns);

        while (<$kpoint>) {

            chomp;
            my $column = Actium::O::Points::Column->new( $_, $column_stopid );

            my $linegroup = $column->linegroup;
            push @found_lines, $linegroup;
            my $dircode = $column->dircode;

            my $transitinfo_dir = $DIRCODES[ $HASTUS_DIRS[$dircode] ];

            my $linedir = "$linegroup-$transitinfo_dir";
            push @found_lines, $linedir;

            next if $do_omit_line{$linedir};
            next if $do_omit_line{$linegroup};

            # BSH handling

            if ( $special_type eq 'bsh' ) {
                if ( $linegroup eq 'BSD' or $linegroup eq 'BSH' ) {
                    $self->push_columns($column);
                }
                elsif ( $linegroup eq 'BSN' ) {
                    $bsn_columns{ $column->days } = $column;
                }
                next;
            }

            if ( $special_type eq 'db' ) {
                if ( $linegroup =~ /^DB/ ) {
                    $self->push_columns($column);
                }
                next;
            }

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

        my @notfound = get_unique( [ [ keys %do_omit_line ], \@found_lines ] );

        if (@notfound) {
            my $linetext = @notfound > 1 ? 'Lines' : 'Line';
            my $lines = joinseries(@notfound);
            emit_text
              "\x{1f4A5}  Warning! $linetext $lines found in omit list for "
              . "stop $stop_to_import, but not found in stop schedule data.";
        }

    } ## tidy end: foreach my $stop_to_import ...

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

sub sort_columns_by_route_etc {
    my $self = shift;

    my $columnsort = sub {
        my ( $aa, $bb ) = @_;
        return (
                 byline( $aa->head_line(0), $bb->head_line(0) )
              or $ewreplace->( $aa->dircode ) <=> $ewreplace->( $bb->dircode )
              or $aa->days cmp $bb->days
              or $aa->primary_destination cmp $bb->primary_destination
        );

    };

    $self->sort_columns($columnsort);
    return;
}

sub format_columns {

    my ( $self, $signtype ) = @_;

  COLUMN:
    foreach my $column ( $self->columns ) {

        # format header, and footnote of header

        $column->format_header;    # everything except footnote

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
                if ( $_ eq 'LASTSTOP' ) {
                    $notetext = "Last Stop";
                    next;
                }
                if ( $_ eq 'DROPOFF' ) {
                    $notetext = "Drop Off Only";
                    next;
                }
                if ( $_ eq '72R' ) {
                    $notetext
                      = 'Buses arrive about every 12 minutes '
                      . $IDT->emdash
                      . $IDT->softreturn
                      . 'See information elsewhere on this sign.';
                    next;
                }
                if ( $_ eq '1R-MIXED' ) {

                    $notetext
                      = 'Buses arrive about every 12 minutes weekdays, and 15 minutes weekends.'
                      . ' (Weekend service to downtown Oakland only.) '
                      . $IDT->softreturn
                      . 'See information elsewhere on this sign.';

                    next;
                }

                if ( $_ eq '1R' ) {

                    if ( $column->days eq '12345' ) {
                        $notetext
                          = 'Buses arrive about every 12 minutes '
                          . $IDT->emdash
                          . $IDT->softreturn
                          . 'See information elsewhere on this sign.';
                    }
                    else {

                        $notetext
                          = 'Buses arrive about every 12 minutes weekdays, 15 minutes weekends '
                          . $IDT->emdash
                          . $IDT->softreturn
                          . 'See information elsewhere on this sign.';
                    }

                    next;

                } ## tidy end: if ( $_ eq '1R' )

            } ## tidy end: for ( $column->note )

            $column->set_formatted_column( $column->formatted_header
                  . $IDT->boxbreak
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

        my $column_length
          = $Actium::Cmd::MakePoints::signtypes{$signtype}{TallColumnLines};
        my $formatted_columns;

        if ($column_length) {

            my $count = $column->formatted_time_count;
            my $width = POSIX::ceil( $count / $column_length );
            $column_length = POSIX::ceil( $count / $width );

            my @ft;
            my $iterator = natatime $column_length, $column->formatted_times;
            while ( my @formatted_times = $iterator->() ) {
                push @ft, join( "\r", @formatted_times );
            }

            $self->add_to_width( scalar @ft );

            $formatted_columns = join( ( $IDT->boxbreak() x 2 ), @ft );
        }
        else {    # no entry for TallColumnLines in Signtype table
            $formatted_columns = join( "\r", $column->formatted_times );
            $self->add_to_width(1);
        }

        $column->set_formatted_column(
            $column->formatted_header . $IDT->boxbreak . $formatted_columns );

    }    ## <perltidy> end foreach my $column ( $self->columns)

}    ## <perltidy> end sub format_columns

sub format_side {
    my $self    = shift;
    my $signid  = $self->signid;
    my $effdate = $self->effdate;
    my $is_bsh  = $self->is_bsh;

    my $formatted_side;
    open my $sidefh, '>:utf8', \$formatted_side;

    # EFFECTIVE DATE and colors
    my $color;

    if ($is_bsh) {
        $color = 'Black';
    }
    else {
        if ( $effdate =~ /Dec|Jan|Feb/ ) {
            $color = "H101-Purple";    # if it looks crummy change it to H3-Blue
        }
        elsif ( $effdate =~ /Mar|Apr|May/ ) {
            $color = "New AC Green";
        }
        elsif ( $effdate =~ /Jun|Jul/ ) {
            $color = "Black";
        }
        else {                         # Aug, Sept, Oct, Nov
            $color = "Rapid Red";
        }
    }

    my $nbsp = $IDT->nbsp;
    $effdate =~ s/\s+$//;
    $effdate =~ s/\s/$nbsp/g;

    print $sidefh $IDT->parastyle('sideeffective'),
      $IDT->color($color), "Effective: $effdate";
      
    print $sidefh "\r", $IDT->parastyle('sidenotes'),
      'Light Face = a.m.', $IDT->softreturn;
    print $sidefh $IDT->bold_word('Bold Face = p.m.'), "\r";

    if ( $self->has_ab ) {
        print $sidefh 
'Lines that have <0x201C>A Loop<0x201D> and <0x201C>B Loop<0x201D> travel in a circle, beginning ',
          'and ending at the same point. The A Loop operates in the clockwise ',
          'direction. The B Loop operates in the counterclockwise direction. ',
'Look for <0x201C>A<0x201D> or <0x201C>B<0x201D> at the right end of the headsign on the bus. ',
          "\r";
    }

    my $sidenote = $Actium::Cmd::MakePoints::signs{$signid}{Sidenote};
    
    if ( $sidenote and ( $sidenote !~ /^\s+$/ ) ) {
        $sidenote =~ s/\n/\r/g;
        $sidenote =~ s/\r+/\r/g;
        $sidenote =~ s/\r+$//;
        $sidenote =~ s/\0+$//;
        
        $sidenote = $IDT->encode_high_chars($sidenote);

        if ($is_bsh) {
            print $sidefh $IDT->parastyle('BSHsidenotes'), $sidenote,
              "\r", $IDT->parastyle('sidenotes');
        }
        else {

            print $sidefh $IDT->bold_word(
                $sidenote)
                #$Actium::Cmd::MakePoints::signs{$signid}{Sidenote} )
              . "\r";
        }
    }

    print $sidefh $self->format_sidenotes;

    if ( $self->note600 ) {
        my $stoporarea = $self->is_simple_stopid ? 'stop' : 'area';
        print $sidefh
"This $stoporarea may also be served by supplementary lines (Lines 600"
          . $IDT->endash
          . "699), which operate school days only, at times that may vary from day to day. Call 511 or visit actransit.org for more information. This service is available to everyone at regular fares.\r";
    }

# TODO - will have to make this work if exception processing is added
#if ($self->schooldayflag ) {
#   print $sidefh "Trips that run school days only may not operate every day and will occasionally operate at times other than those shown. Supplementary service is available to everyone at regular fares.\r";
#}

    print $sidefh
"See something wrong with this sign, or any other AC Transit sign? Let us know! Leave a comment at actransit.org/feedback or call 511 and say 'AC Transit'. Thanks!\r"
      if lc(
        $Actium::Cmd::MakePoints::signtypes{
            $Actium::Cmd::MakePoints::signs{$signid}{SignType}
        }{GenerateWrongText} ) eq "yes";

    ### new stop ID

    if ( not $self->is_bsh and $self->is_simple_stopid ) {
        print $sidefh $IDT->parastyle('depttimeside'), 'Call ',
          $IDT->bold_word('511'), ' and say ',
          $IDT->bold_word('"Departure Times"'),
          " for live bus predictions\r", $IDT->parastyle('stopid'),
          "STOP ID\r",                   $IDT->parastyle('stopidnumber'),
          $self->stopid();
    }
    ###

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

    my $self    = shift;
    my %foot_of = reverse $self->elements_marker_of_footnote;

    my $formatted_sidenotes = '';
    open my $sidefh, '>:utf8', \$formatted_sidenotes;

  NOTE:
    for my $i ( 1 .. $self->highest_footnote ) {

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
 #$dest = $Actium::Cmd::MakePoints::places{ $attr{destination} }{c_destination};
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

        print $sidefh "\r";

    }    ## <perltidy> end for my $i ( 1 .. $self->highest_footnote)

    close $sidefh;

    return $formatted_sidenotes;

}    ## <perltidy> end sub format_side

sub format_bottom {

    my $self   = shift;
    my $is_bsh = $self->is_bsh;

    my $signid = $self->signid;
    my $stopid = $self->stopid;

    my $formatted_bottom;
    open my $botfh, '>:utf8', \$formatted_bottom;

    no warnings('once');
    my $stop_r = $Actium::Cmd::MakePoints::stops{$stopid}; # this is a reference

    my $nonstoplocation = $self->nonstoplocation;

    my $description = $nonstoplocation || $stop_r->{c_description_full};

    $IDT->encode_high_chars($description);

    print $botfh $IDT->parastyle('bottomnotes'), $description;
    #$stop_r->{c_description_full} ;

    print $botfh ". Sign #$signid.";

    print $botfh " Stop $stopid." unless $nonstoplocation;

    print $botfh " Shelter site #"
      . $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum} . "."
      if $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum};

    if ( $is_bsh and not $nonstoplocation ) {
        print $botfh $IDT->boxbreak, $IDT->parastyle('BSHInfoStopID'), $stopid;
    }

    close $botfh;

    $self->set_formatted_bottom($formatted_bottom);

} ## tidy end: sub format_bottom

sub output {

    my $self = shift;

    my $signid = $self->signid;

    open my $fh, '>:encoding(ascii)', "indesign_points/$signid.txt"
      or die "Can't open $signid.txt for writing: $!";

    print $fh $IDT->start;

    # output blank columns at beginning

    my $maxcolumns
      = $Actium::Cmd::MakePoints::signtypes{
        $Actium::Cmd::MakePoints::signs{$signid}{SignType}
      }{TallColumnNum};
    my $break = $IDT->boxbreak;

    if ( $maxcolumns and $maxcolumns > $self->width )
    {    # if there's an entry in SignTypes
        my $columns = $maxcolumns - ( $self->width );
        #print "[[$maxcolumns:" , $self->width , ":$columns]]";
        print $fh ( $IDT->parastyle('amtimes'), $break x ( $columns * 2 ) );
    }

    # output real columns

    foreach my $column ( $self->columns ) {
        print $fh $column->formatted_column;
        print $fh $break;
    }

    print $fh $self->formatted_side;
    print $fh $break;
    print $fh $self->formatted_bottom;
    
    close $fh;

} ## tidy end: sub output

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

