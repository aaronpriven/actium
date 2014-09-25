# Actium/Points/Point.pm

# legacy stages 2 and 3

# This object is used for *display*, and should probably be called something
# that relates to that.

# The object Actium::O::Points is used to hold unformatted data.

use warnings;
use strict;

use 5.010;

package Actium::O::Points::Point;

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

use IDTags;
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

sub is_simple_stopid {
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

    foreach my $stop_to_import ( $self->allstopids ) {

        my %do_omit_line
          = map { $_, 1 } @{ $self->omitted_of($stop_to_import) };
        my ( @found_lines, @found_linedirs );
        
        my $citycode = substr( $stop_to_import, 0, 2 );

        my $kpointfile = "kpoints/$citycode/$stop_to_import.txt";

        open my $kpoint, '<', $kpointfile
          or die "Can't open $kpointfile: $!";

        while (<$kpoint>) {
            chomp;
            my $column = Actium::O::Points::Column->new($_);

            my $linegroup = $column->linegroup;
            push @found_lines, $linegroup;
            my $dircode = $column->dircode;

            my $transitinfo_dir = $DIRCODES[ $HASTUS_DIRS[$dircode] ];

            my $linedir = "$linegroup-$transitinfo_dir";
            push @found_lines, $linedir;

            next if $do_omit_line{$linedir};
            next if $do_omit_line{$linegroup};
            
            if ( $linegroup =~ /^BS[DNH]$/ ) {
                $self->push_columns($column) if $special_type eq 'bsh';
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
                $SPACE . IDTags::combifootnote($marker) );

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
                      . IDTags::emdash
                      . IDTags::softreturn
                      . 'See information elsewhere on this sign.';
                    next;
                }
                if ( $_ eq '1R-MIXED' ) {

                    $notetext
                      = 'Buses arrive about every 12 minutes weekdays, and 15 minutes weekends.'
                      . ' (Weekend service to downtown Oakland only.) '
                      . IDTags::softreturn
                      . 'See information elsewhere on this sign.';

                    next;
                }

                if ( $_ eq '1R' ) {

                    if ( $column->days eq '12345' ) {
                        $notetext
                          = 'Buses arrive about every 12 minutes '
                          . IDTags::emdash
                          . IDTags::softreturn
                          . 'See information elsewhere on this sign.';
                    }
                    else {

                        $notetext
                          = 'Buses arrive about every 12 minutes weekdays, 15 minutes weekends '
                          . IDTags::emdash
                          . IDTags::softreturn
                          . 'See information elsewhere on this sign.';
                    }

                    next;

                } ## tidy end: if ( $_ eq '1R' )

            } ## tidy end: for ( $column->note )

            $column->set_formatted_column( $column->formatted_header
                  . IDTags::boxbreak
                  . IDTags::parastyle( 'noteonly', $notetext ) );

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
                $time = IDTags::parastyle( $pstyle, $time );
            }

            if ($foot) {
                my $marker = $self->get_marker_of_footnote($foot);
                unless ($marker) {
                    $self->inc_highest_footnote;
                    $marker = $self->highest_footnote;
                    $self->set_marker_of_footnote( $foot, $marker );
                }

                $time .= IDTags::hairspace . IDTags::combifootnote($marker);
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

            $formatted_columns = join( ( IDTags::boxbreak() x 2 ), @ft );
        }
        else {    # no entry for TallColumnLines in Signtype table
            $formatted_columns = join( "\r", $column->formatted_times );
            $self->add_to_width(1);
        }

        $column->set_formatted_column(
            $column->formatted_header . IDTags::boxbreak . $formatted_columns );

    }    ## <perltidy> end foreach my $column ( $self->columns)

}    ## <perltidy> end sub format_columns

sub format_side {
    my $self    = shift;
    my $signid  = $self->signid;
    my $effdate = $self->effdate;
    my $is_bsh  = $self->is_bsh;

    my $formatted_side;
    open my $sidefh, '>', \$formatted_side;

    # EFFECTIVE DATE and colors
    my $color;
    if ( $effdate =~ /Dec|Jan|Feb/ ) {
        if ($is_bsh) {
            $color = "BSH";
        }
        else {
            $color = "H101-Purple";    # if it looks crummy change it to H3-Blue
        }
    }
    elsif ( $effdate =~ /Mar|Apr|May/ ) {
        if ($is_bsh) {
            $color = "BSH";
        }
        else {
            $color = "New AC Green";
        }
    }
    elsif ( $effdate =~ /Jun|Jul/ ) {
        $color = "Black";
    }
    else {    # Aug, Sept, Oct, Nov
        if ($is_bsh) {
            $color = "Black";
        }
        else {
            $color = "Rapid Red";
        }
    }

    my $nbsp = IDTags::nbsp;
    $effdate =~ s/\s+$//;
    $effdate =~ s/\s/$nbsp/g;

    print $sidefh IDTags::parastyle( 'sideeffective',
        IDTags::color( $color, "Effective: $effdate" ) );

    print $sidefh "\r",                IDTags::parastyle('sidenotes');
    print $sidefh 'Light Face = a.m.', IDTags::softreturn;
    print $sidefh IDTags::bold('Bold Face = p.m.'), "\r";

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
        print $sidefh IDTags::bold(
            $Actium::Cmd::MakePoints::signs{$signid}{Sidenote} )
          . "\r";
    }

    print $sidefh $self->format_sidenotes;

    #my $thisproject = $Actium::Cmd::MakePoints::signs{$signid}{Project};
    #if ( $Actium::Cmd::MakePoints::projects{$thisproject}{'ProjectNote'} ) {
    #    print $sidefh $Actium::Cmd::MakePoints::projects{$thisproject}
    #      {'ProjectNote'}, "\r";
    #}

    if ( $self->note600 ) {
        my $stoporarea = $self->is_simple_stopid ? 'stop' : 'area';
        print $sidefh
"This $stoporarea may also be served by supplementary lines (Lines 600"
          . IDTags::endash
          . "699), which operate school days only, at times that may vary from day to day. Call 511 or visit www.actransit.org for more information. This service is available to everyone at regular fares.\r";
    }

# TODO - will have to make this work if exception processing is added
#if ($self->schooldayflag ) {
#   print $sidefh "Trips that run school days only may not operate every day and will occasionally operate at times other than those shown. Supplementary service is available to everyone at regular fares.\r";
#}

    print $sidefh
"See something wrong with this sign, or any other AC Transit sign? Let us know! Leave a comment at www.actransit.org/feedback or call 511 and say 'AC Transit'. Thanks!\r"
      if lc(
        $Actium::Cmd::MakePoints::signtypes{
            $Actium::Cmd::MakePoints::signs{$signid}{SignType}
        }{GenerateWrongText} ) eq "yes";

    ### new stop ID

    if ( not $self->is_bsh and $self->is_simple_stopid ) {
        print $sidefh IDTags::parastyle('depttimeside'), 'Call ',
          IDTags::bold('511'), ' and say ', IDTags::bold('"Departure Times"'),
          " for live bus predictions\r", IDTags::parastyle('stopid'),
          "STOP ID\r",                   IDTags::parastyle('stopidnumber'),
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
);

sub format_sidenotes {

    my $self    = shift;
    my %foot_of = reverse $self->elements_marker_of_footnote;

    my $formatted_sidenotes = '';
    open my $sidefh, '>', \$formatted_sidenotes;

  NOTE:
    for my $i ( 1 .. $self->highest_footnote ) {

        print $sidefh IDTags::combiside($i), $SPACE;

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
            if ( $_ eq 'dl' ) { print $sidefh "Line $line, to $dest"; next; }
            if ( $_ eq 'e' )  { print $sidefh "Operates $exc.";       next; }
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

    my $self = shift;

    my $signid = $self->signid;
    my $stopid = $self->stopid;

    my $formatted_bottom;
    open my $botfh, '>', \$formatted_bottom;

    no warnings('once');
    my $stop_r = $Actium::Cmd::MakePoints::stops{$stopid}; # this is a reference

    my $nonstoplocation = $self->nonstoplocation;

    my $description = $nonstoplocation || $stop_r->{c_description_full};

    $IDT->encode_high_chars($description);

    print $botfh IDTags::parastyle('bottomnotes'), $description;
    #$stop_r->{c_description_full} ;

    print $botfh ". Sign #$signid.";

    print $botfh " Stop $stopid." unless $nonstoplocation;

    print $botfh " Shelter site #"
      . $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum} . "."
      if $Actium::Cmd::MakePoints::signs{$signid}{ShelterNum};

    close $botfh;

    $self->set_formatted_bottom($formatted_bottom);

} ## tidy end: sub format_bottom

sub output {

    my $self = shift;

    my $signid = $self->signid;

    open my $fh, '>', "indesign_points/$signid.txt"
      or die "Can't open $signid.txt for writing: $!";

    print $fh IDTags::start;

    # output blank columns at beginning

    my $maxcolumns
      = $Actium::Cmd::MakePoints::signtypes{
        $Actium::Cmd::MakePoints::signs{$signid}{SignType}
      }{TallColumnNum};
    my $break = IDTags::boxbreak;

    if ( $maxcolumns and $maxcolumns > $self->width )
    {    # if there's an entry in SignTypes
        my $columns = $maxcolumns - ( $self->width );
        #print "[[$maxcolumns:" , $self->width , ":$columns]]";
        print $fh ( IDTags::parastyle('amtimes'), $break x ( $columns * 2 ) );
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

