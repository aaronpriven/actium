# Actium/Bags.pm

# Routines for dealing with bag artwork

# Subversion: $Id$

# legacy stage 4

package Actium::Bags 0.004;

use Actium::Preamble;
use Actium::Term;
#use Actium::Util(qw/joinseries/);

use Actium::Text::InDesignTags;
use Actium::EffectiveDate;

use Actium::Sorting::Travel ('travelsort');

const my $IDT => 'Actium::Text::InDesignTags';

const my $CR => "\r";

const my %HEIGHT_OF => (
    numbers => 2.5,
    AL      => 7.6,
    AS      => 11.9,
    RL      => 7.6,
    CL      => 9.45,
    XL      => 7.6,
    margin  => 0.75,
    RS      => 12.75,
);

const my %OUTPUT_DISPATCH => _output_dispatch();

const my $OLD     => 'change';
const my $NEW     => 'add';
const my $REMOVED => 'remove';

const my @COLUMNS => qw[
  h_stp_511_id         c_description_full
  p_added_lines        p_added_line_count
  p_removed_lines      p_removed_line_count
  p_unch_lines         p_unch_line_count
  u_bagtext
];

const my %COLUMN_INDEX_OF => ( map { $COLUMNS[$_] => $_ } 0 .. $#COLUMNS );

const my $COLUMNS_SQL => join( ', ', @COLUMNS );

sub make_bags {

    my %params = validate(
        @_,
        #        {   signup    => { can => [qw (subfolder retrieve)] },
        #            oldsignup => { can => [qw (subfolder retrieve)] },
        {   signup    => { isa => 'Actium::O::Folder' },
            oldsignup => { isa => 'Actium::O::Folder' },
            actium_db => 1,
        }
    );

    my $signup_of_r;
    $signup_of_r->{$NEW} = $params{signup};
    $signup_of_r->{$OLD} = $params{oldsignup};
    my $actium_db = $params{actium_db};

    my $effectivedate
      = Actium::EffectiveDate::effectivedate( $signup_of_r->{$NEW} );
    $effectivedate =~ s/,? \s* \d{2,4} \s* \z//sx;
    # trim year and trailing white space
    my $nbsp = $IDT->nbsp;    # non breaking space
    $effectivedate =~ s/ +/$nbsp/g;

    my $of_stop_r = _make_stop_info($actium_db);

    $of_stop_r = _sort_stops( $of_stop_r, $signup_of_r );

    my $baglist_r = _make_baglist($of_stop_r);

    my ( $bagtexts_r, $counts_r ) = _bagtexts( $of_stop_r, $effectivedate );

    my $para_r         = _para();
    my $final_height_r = _final_height();

    return $bagtexts_r, $baglist_r, $counts_r, $final_height_r;

} ## tidy end: sub make_bags

sub _make_baglist {

    my $of_stop_r = shift;
    my @baglist;

    for my $list ( $OLD, $NEW ) {

        my @thislist;

        for my $stop_r ( @{ $of_stop_r->{$list} } ) {

            my $outlist = $list eq $OLD ? $EMPTY_STR : "-add";

            push @thislist,
              [ $stop_r->{StopID}, $stop_r->{Group} . $outlist,
                @{$stop_r}{qw/Order Of Desc/}
              ];

        }

        push @baglist,
           sort { $a->[1] cmp $b->[1] || $a->[2] <=> $b->[2] } @thislist ;

    }

    unshift @baglist, [ (qw/h_stp_511_id Group Order Of c_description_full/) ];

    return \@baglist;

} ## tidy end: sub _make_baglist

sub _make_stop_info {
    my $actium_db = shift;

    my $each_stop = $actium_db->each_columns_in_row_where(
        table   => 'Stops_Neue',
        columns => \@COLUMNS,
        where   => 'WHERE u_bag_to_print_next_run = 1',
    );

    my %compare;

    while ( my $stop_r = $each_stop->() ) {
        my ($stopid,    $desc,          $added,
            $num_added, $removed,       $num_removed,
            $unchanged, $num_unchanged, $bagtext
        ) = @{$stop_r};

        $bagtext = q{}
          if not defined $bagtext
          or $bagtext eq q{-}
          or $bagtext eq q{.};

        # determine action

        #<<<
        my $action
          = $num_added   && $num_removed && $num_unchanged ? 'CL'
          : $num_added   && $num_removed                   ? 'XL'
          : $num_added   && $num_unchanged                 ? 'AL'
          : $num_removed && $num_unchanged                 ? 'RL'
          : $num_added                                     ? 'AS'
          :                                                  'RS';
        #>>>

        my %this_stop = (
            StopID    => $stopid,
            Action    => $action,
            Added     => $added,
            Removed   => $removed,
            Unchanged => $unchanged,
            Desc      => $desc,
            Note      => $bagtext,
        );

        if ( $action eq 'AS' ) {
            $compare{$NEW}{$stopid} = \%this_stop;
        }
        else {
            $compare{$OLD}{$stopid} = \%this_stop;
        }

    } ## tidy end: while ( my $stop_r = $each_stop...)

    return \%compare;

} ## tidy end: sub _make_stop_info

sub _sort_stops {
    my ( $of_stop_r, $signup_of_r ) = @_;

    my %stops_sorted;

    for my $list ( $OLD, $NEW ) {
        my $slistsdir  = $signup_of_r->{$list}->subfolder('slists');
        my $stops_of_r = $slistsdir->retrieve('line.storable');
        my @sorted
          = travelsort( [ keys %{ $of_stop_r->{$list} } ], $stops_of_r );

        while ( my $ref = shift @sorted ) {
            my ( $linedir, @stopids ) = @{$ref};
            my $num_stopids = scalar @stopids;
            foreach my $i ( 1 .. $num_stopids ) {
                my $stopid = $stopids[ $i - 1 ];
                $of_stop_r->{$list}{$stopid}{Group}   = $linedir;
                $of_stop_r->{$list}{$stopid}{Order}   = $i;
                $of_stop_r->{$list}{$stopid}{Of}      = $num_stopids;
                $of_stop_r->{$list}{$stopid}{OrderOf} = "$i of $num_stopids";

                push @{ $stops_sorted{$list} }, $of_stop_r->{$list}{$stopid};
            }

        }

    } ## tidy end: for my $list ( $OLD, $NEW)

    return \%stops_sorted;

} ## tidy end: sub _sort_stops

sub _bagtexts {
    my $of_stop_r     = shift;
    my $effectivedate = shift;

    my %bagtexts;

    for my $list ( $OLD, $NEW ) {
        for my $stop_r ( @{ $of_stop_r->{$list} } ) {
            my ( $text, $height ) = _bagtext_of_stop( $stop_r, $effectivedate );
            my $outlist = $stop_r->{Action} eq 'RS' ? $REMOVED : $list;

            my $outheight = sprintf( '%2d', _final_height($height) );

            my $filename = "$outheight-$outlist";
            $text =~ s/__file__/$outheight $outlist/g;
            push @{ $bagtexts{$filename} }, $text;
        }
    }

    my %counts;
    foreach ( keys %bagtexts ) {
        $counts{$_} = scalar @{ $bagtexts{$_} };
        $bagtexts{$_}
          = $IDT->start . join( $IDT->boxbreak, @{ $bagtexts{$_} } );

    }

    return \%bagtexts, \%counts;
} ## tidy end: sub _bagtexts

sub _bagtext_of_stop {
    my %of_stop       = %{ +shift };
    my $effectivedate = shift;

    my $thistext;
    open my $fh, '>', \$thistext or die $!;

    print $fh _para('Teeny'),
      "$of_stop{Group} ($of_stop{OrderOf})",
      $IDT->emspace,
      $of_stop{Desc}, $IDT->emspace, "Stop $of_stop{StopID}",
      $IDT->emspace() x 8, '__file__',
      $CR;

    my %list_of;

    $list_of{Added}     = _prepare_lines( $of_stop{Added} );
    $list_of{Removed}   = _prepare_lines( $of_stop{Removed} );
    $list_of{Unchanged} = _prepare_lines( $of_stop{Unchanged} );

    my ( $linestext, $height )
      = $OUTPUT_DISPATCH{ $of_stop{Action} }->( \%list_of, $effectivedate );

    print $fh $linestext;

    my $note = $of_stop{Note};
    if ($note) {
        print $fh _para('Note') . $note . $CR;
        $height += _note_height($note);
    }

    print $fh _para('Questions'),
      'Want more info? Visit www.actransit.org or call 511 ',
      '(and say, <0x201C>AC Transit.<0x201D>)';

    close $fh;

    $height += $HEIGHT_OF{margin};

    return $thistext, $height;

} ## tidy end: sub _bagtext_of_stop

const my $BIGSEP   => $IDT->enspace . $IDT->discretionary_lf;
const my $SMALLSEP => $IDT->thirdspace
  . ( $IDT->hairspace() x 2 )
  . $IDT->discretionary_lf;

sub _prepare_lines {

    my $unprepared = shift;
    return if ( not defined $unprepared or $unprepared eq $EMPTY_STR );

    my @lines = split( ' ', $unprepared );
    @lines = grep { $_ ne $EMPTY_STR } @lines;

    my %return;

    if ( @lines == 1 ) {
        $return{word}      = 'line';
        $return{these}     = 'this line';
        $return{thesestop} = 'this line stops';
    }
    else {
        $return{word}      = 'lines';
        $return{these}     = 'these lines';
        $return{thesestop} = 'these lines stop';
    }

    my @textlines;
    my $thisline = $EMPTY_STR;

    my $line_width = 11;

    foreach my $i ( 0 .. $#lines - 1 ) {

        my $chars = $lines[$i];

        if ( _charwidth( $thisline . $chars ) <= $line_width ) {
            # less than or equal to than line length
            $thisline .= $chars . $SPACE;
        }
        else {
            push @textlines, $thisline;
            $thisline = $chars . $SPACE;
        }

    }

    # last item

    my $chars = $lines[-1] || $EMPTY_STR;

    if ( _charwidth( $thisline . $chars ) <= ($line_width) ) {
        # less than or equal to than line length
        push @textlines, $thisline . $chars;
    }
    else {
        push @textlines, $thisline, $chars;
    }

    $return{'len'} = ( scalar @textlines ) * $HEIGHT_OF{numbers};

    my $sep = $BIGSEP;

    foreach (@textlines) {
        if ( _charwidth($_) >= $line_width - 1 ) {
            $sep = $SMALLSEP;
            last;
        }
    }

    my $lines = join( $EMPTY_STR, @textlines );
    $lines =~ s/$SPACE/$sep/g;
    $return{lines} = $lines;

    #$return{simplelines} = joinseries(@lines);

    return \%return;

} ## tidy end: sub _prepare_lines

sub _para {
    state %paras;
    if ( defined $_[0] ) {
        my $para = shift;
        $paras{$para}++;
        return $IDT->parastyle($para) . join( $EMPTY_STR, @_ );
    }

    return \%paras;

}

const my $HEIGHT_INTERVAL => 2;

sub _final_height {
    state %heights;
    my $height = shift;

    if ($height) {
        my $rounded = ceil( $height / $HEIGHT_INTERVAL ) * $HEIGHT_INTERVAL;
        $heights{$height}{count}++;
        $heights{$height}{rounded} = $rounded;
        return $rounded;
    }

    return \%heights;
}

sub _output_dispatch {

    my $al_output = sub {
        my $list_of_r = shift;
        my %added     = %{ $list_of_r->{Added} };
        my %unchanged = %{ $list_of_r->{Unchanged} };
        my $date      = shift;

        my $r
          = _para('FirstLineIntro')
          . ucfirst( $unchanged{thesestop} )
          . " here:$CR"
          . _para( 'CurrentLines', $unchanged{lines} )
          . $CR
          . _para('LineIntro')
          . "Effective $date, $added{these} will "
          . $IDT->underline_word('also')
          . " stop here:$CR"
          . _para( 'AddedLines', $added{lines} )
          . $CR;

        my $length = $added{len} + $unchanged{len} + $HEIGHT_OF{AL};

        return $r, $length;

    };    ## tidy end: sub al_output

    my $rl_output = sub {
        my $list_of_r = shift;
        my %removed   = %{ $list_of_r->{Removed} };
        my %unchanged = %{ $list_of_r->{Unchanged} };
        my $date      = shift;

        my $r
          = _para('FirstLineIntro')
          . ucfirst( $unchanged{thesestop} )
          . " here:"
          . $CR
          . _para( 'CurrentLines', $unchanged{lines} )
          . $CR
          . _para('LineIntro')
          . "Effective $date, $removed{these} will "
          . $IDT->underline_word('not')
          . " stop here:$CR"
          . _para( 'RemovedLines', $removed{lines} )
          . $CR;

        my $length = $removed{len} + $unchanged{len} + $HEIGHT_OF{RL};

        return $r, $length;

    };    ## tidy end: sub rl_output

    my $xl_output = sub {
        my $list_of_r = shift;
        my %added     = %{ $list_of_r->{Added} };
        my %removed   = %{ $list_of_r->{Removed} };
        my $date      = shift;

        my $length = $added{len} + $removed{len} + $HEIGHT_OF{XL};

        my $r = _para('FirstLineIntroSm');
        $r .=

          "Effective $date, $added{these} will "
          . $IDT->underline_word('begin')
          . " stopping here:$CR";

        $r
          .= _para( 'AddedLines', $added{lines} )
          . $CR
          . _para('LineIntroSm')
          . "\u$removed{these} will "
          . $IDT->underline_word('not')
          . " stop here:$CR"
          . _para( 'RemovedLines', $removed{lines} )
          . $CR;

        return $r, $length;

    };    ## tidy end: sub xl_output

    my $cl_output = sub {
        my $list_of_r = shift;
        my %added     = %{ $list_of_r->{Added} };
        my %removed   = %{ $list_of_r->{Removed} };
        my %unchanged = %{ $list_of_r->{Unchanged} };
        my $date      = shift;

        my $length = $added{len} + $removed{len} + $HEIGHT_OF{CL};

        my $r = _para('FirstLineIntro');
        if ( scalar keys %unchanged ) {
            $length += $unchanged{len};

            $r
              .= "\u$unchanged{thesestop} here:"
              . $CR
              . _para( 'CurrentLines', $unchanged{lines} )
              . $CR
              . _para('LineIntro')
              . "Effective $date, $added{these} will "
              . $IDT->underline_word('also')
              . " stop here:$CR"

        }
        else {
            $r .=

              "Effective $date, $added{these} will "
              . $IDT->underline_word('begin')
              . " stopping here:$CR"

        }

        $r
          .= _para( 'AddedLines', $added{lines} )
          . $CR
          . _para('LineIntro')
          . "\u$removed{these} will "
          . $IDT->underline_word('not')
          . " stop here:$CR"
          . _para( 'RemovedLines', $removed{lines} )
          . $CR;

        return $r, $length;

    };    ## tidy end: sub cl_output

    my $as_output = sub {
        my $list_of_r = shift;
        my %added     = %{ $list_of_r->{Added} };
        my $date      = shift;

        my $r
          = _para( 'NewBusStop', "NEW " . $IDT->softreturn . "BUS STOP$CR" );
        $r .= _para('FirstLineIntro');
        $r .= "Effective $date, $added{these} will stop here:$CR";
        $r .= _para( 'AddedLines', $added{lines} ) . $CR;
        my $length = $added{len} + $HEIGHT_OF{AS};
        return $r, $length;

    };

    my $rs_output = sub {
        my $list_of_r = shift;
        my %removed   = %{ $list_of_r->{Removed} };
        my $date      = shift;

        my $length = $removed{len} + $HEIGHT_OF{RS};

        my $r
          = _current(%removed)
          . _para( 'Removed',
            "Effective $date, this bus stop will be removed." )
          . $CR;

        return $r, $length;

    };

    return (
        AL => $al_output,
        RL => $rl_output,
        CL => $cl_output,
        XL => $xl_output,
        AS => $as_output,
        RS => $rs_output,
    );

} ## tidy end: sub _output_dispatch

sub _current {
    my %current = @_;
    my $r = _para( 'Current', "Current $current{word} at this stop:$CR" );
    $r .= _para( 'CurrentLines', $current{lines} ) . $CR;
    return $r;
}

sub _charwidth {
    my $chars = shift;
    return 0 unless $chars;

    my $letters = ( $chars =~ tr/A-Z// );

    my $nonletters = length($chars) - $letters;

    return ( $letters * 1.34 + $nonletters );

}

sub _note_height {
    my $note = shift;
    return 0 unless $note;
    my $width = _charwidth($note);
    return 1.2 * ceil( $width / 34 );
    # 1.2 is approx height of note line. 32 is approximate characters per line.
    # Just guesses...
}

1;

__END__
