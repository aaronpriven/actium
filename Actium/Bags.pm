# Actium/Flags.pm

# Routines for dealing with bag artwork

# Subversion: $Id$

# legacy stage 4

package Actium::Bags 0.004;

use Actium::Preamble;
use Actium::Term;
use Actium::Util(qw/joinseries/);

use Actium::Text::InDesignTags;
use Actium::EffectiveDate;

const my $CR => "\r";

const my %HEIGHT_OF = (
    numbers => 2.5,
    AL      => 7.6,
    AS      => 11.9,
    RL      => 7.6,
    CL      => 9.45,
    XL      => 7.6,
    margin  => 0.75,
    RS      => 12.75,
);

const my @COLUMNS => qw[
  h_stp_511_id         c_description_full
  p_added_lines        p_added_lines_count
  p_removed_lines      p_removed_lines_count
  p_unchanged_lines    p_unchanged_lines_count
  u_bagtext
];

const my %COLUMN_INDEX_OF => ( map { $COLUMNS[$_] => $_ } 0 .. $#COLUMNS );

const my $COLUMNS_SQL => join( ', ', @COLUMNS );

sub make_bags {

    my %params = validate(
        @_,
        {   signup    => { can => [qw (subfolder retrieve)] },
            oldsignup => { can => [qw (subfolder retrieve)] },
            actium_db => 1,
        }
    );
    
    my %signup;
    
    $signup{NEW} = $params{signup};
    $signup{OLD} = $params{oldsignup};
    my $actium_db = $params{actium_db};

    my $bagtextdir = $signup{NEW}->subfolder('bagtexts');

    my $effectivedate = Actium::EffectiveDate::effectivedate($signup{NEW});
    s/,? \s* \d{2,4} \s* \z//sx;    # trim year and trailing white space

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

        $bagtext = q{} if $bagtext eq q{-} or $bagtext eq q{.};

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
            Action    => $action,
            Added     => $added,
            Removed   => $removed,
            Unchanged => $unchanged,
            Desc      => $desc,
            Note      => $bagtext,
        );
        
        if ($action eq 'AS') {
            $compare{NEW}{$stopid} = \%this_stop;
        } 
        else {
            $compare{OLD}{$stopid} = \%this_stop;
        }

    } ## tidy end: while ( my $stop_r = $each_stop...)
    

} ## tidy end: sub make_bags

1;

__END__

my %output_dispatch = (
    AL => \&al_output,
    RL => \&rl_output,
    CL => \&cl_output,
    XL => \&xl_output,
    AS => \&as_output,
    RS => \&rs_output,
);

my $stopcount = 0;
my $filecount = 0;

my ( %texts_of, %texts_of_action, %paras );

my %seen_length;

my $date = 'December' . IDTags::nbsp() . '15';

foreach my $stopid ( 
   sort {$compare{$a}{Count} <=> $compare{$b}{Count}} keys %compare 
   ) {

    my $action = $compare{$stopid}{Action} || die "No action for $stopid";

    my $thistext = '';

    open my $bagtext, '>', \$thistext or die $!;

    $stopcount++;
    #my $desc   = $stops{$stopid}{DescriptionF}
    #  || die "No description for $stopid";
    my $desc  = $compare{$stopid}{Desc};
    my $group = $compare{$stopid}{Group};
    my $order = $compare{$stopid}{Order};

    if ( not( $desc and $group and $order ) ) {
        say '';
        require Data::Dumper;
        say Data::Dumper::Dumper( \%compare );
        #say Data::Dumper::Dumper($compare{$stopid});
        die "Not complete description for $stopid";
    }

    print $bagtext para('Teeny');

    print $bagtext "$group ($order)";
    print $bagtext IDTags::emspace, $desc;
    print $bagtext IDTags::emspace, "Stop $stopid" ;
    #print $bagtext IDTags::emspace,  $action;
    print $bagtext $CR;

    my $added     = $compare{$stopid}{Added}     || $EMPTY_STR;
    my $removed   = $compare{$stopid}{Removed}   || $EMPTY_STR;
    my $unchanged = $compare{$stopid}{Unchanged} || $EMPTY_STR;

    my ( @added, @removed, @unchanged );

    @added     = split( /,/, $added )     if $added;
    @removed   = split( /,/, $removed )   if $removed;
    @unchanged = split( /,/, $unchanged ) if $unchanged;
    my @allnew = ( @added, @unchanged );

    my %added     = prepary(@added);
    my %removed   = prepary(@removed);
    my %unchanged = prepary(@unchanged);
    my %allnew    = prepary(@allnew);

    next unless ( in($action , qw(AS RS AL RL CL XL) ));

    my ( $text, $length )
      = $output_dispatch{$action}->( \%added, \%removed, \%unchanged, \%allnew );

    print $bagtext $text;

    my $note = $compare{$stopid}{Note};

    if ($note) {
        print $bagtext para('Note') . $note . $CR;
    }

    # figure length of note
    $length += note_length($note);

    print $bagtext para( 'Questions',
'Want more info? Visit www.actransit.org or call 511 (and say, <0x201C>AC Transit.<0x201D>)'
    );

    close $bagtext;

    $length += $height_of{margin};

    my $outaction = $action;

    #if ( $action eq 'AL' or $action eq 'RL' or $action eq 'CL' or $action eq 'XL' ) {
    if ( $action ne 'RS' ) {
        $outaction = 'C';
    }

    # IGNORE HEIGHTS FOR PRINTING ON BAGS
    #$length = 36;

    $length = ceil ($length/2) * 2;

    # round

    $seen_length{"$length-$outaction"}++;

    push @{ $texts_of{$outaction}{$length} }, $thistext;

    push @{ $texts_of_action{$action} }, $thistext;

}    ## <perltidy> end foreach my $file (...)

my $number_in_a_group = 1e6;

while ( my ( $outaction, $lengths_of_r ) = each %texts_of ) {

    while ( my ( $length, $texts_r ) = each %{$lengths_of_r} ) {

        my $texts_count = scalar @$texts_r;

        my $fname = "$outaction-$length";

        if ( $texts_count > $number_in_a_group ) {

            my $suffix = 'a';

            my $it = natatime $number_in_a_group, @$texts_r;
            while ( my @texts = $it->() ) {

                open my $bagtext, '>', "bagtexts/$fname-$suffix.txt" or die $!;
                print $bagtext start();
                #foreach (@texts) {
                #    print $bagtext $_, IDTags::boxbreak ;
                #}
                print $bagtext join( IDTags::boxbreak, @texts );
                close $bagtext;

                $suffix++;    # alphabetic auto-increment

            }

        } ## tidy end: if ( $texts_count > $number_in_a_group)
        else {

            open my $bagtext, '>', "bagtexts/$fname.txt" or die $!;

            print $bagtext start();
            print $bagtext join( IDTags::boxbreak, @{$texts_r} );
            #foreach ( @{$texts_r} ) {
            #    print $bagtext $_, IDTags::boxbreak;
            #}

            close $bagtext;
        }

    }    ## <perltidy> end while ( my ( $length, $texts_r...))

}    ## <perltidy> end while ( my ( $outaction, $lengths_of_r...))

# end of main

{
    no warnings 'numeric';

    foreach ( sort { $a <=> $b } keys %seen_length ) {
        say $_ , ": ", $seen_length{$_};
    }
    say '---';
    foreach ( sort keys %paras ) {
        say $_ , ": ", $paras{$_};
    }

}

sub al_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };
    my %allnew    = %{ +shift };

    my $r
      = para('FirstLineIntro')
      . ucfirst( $unchanged{thesestop} )
      . " here:$CR"
      . para( 'CurrentLines', $unchanged{lines} )
      . $CR
      . para('LineIntro')
      . "Effective $date, $added{these} will "
      . IDTags::underline('also')
      . " stop here:$CR"
      . para( 'AddedLines', $added{lines} )
      . $CR;

    my $length = $added{len} + $unchanged{len} + $height_of{AL};

    return $r, $length;

} ## tidy end: sub al_output

sub rl_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };
    my %allnew    = %{ +shift };

    my $r
      = para('FirstLineIntro')
      . ucfirst( $unchanged{thesestop} )
      . " here:" . $CR
      . para( 'CurrentLines', $unchanged{lines} ) . $CR
      . para('LineIntro')
      . "Effective $date, $removed{these} will "
      . IDTags::underline('not')
      . " stop here:$CR"
      . para( 'RemovedLines', $removed{lines} )
      . $CR;

    my $length = $removed{len} + $unchanged{len} + $height_of{RL};

    return $r, $length;

} ## tidy end: sub rl_output

sub xl_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };
    my %allnew    = %{ +shift };

    my $length = $added{len} + $removed{len} + $height_of{XL};

    my $r = para('FirstLineIntroSm');
        $r .=

          "Effective $date, $added{these} will "
          . IDTags::underline('begin')
          . " stopping here:$CR";


    $r
      .= para( 'AddedLines', $added{lines} )
      . $CR
      . para('LineIntroSm')
      . "\u$removed{these} will "
      . IDTags::underline('not')
      . " stop here:$CR"
      . para( 'RemovedLines', $removed{lines} )
      . $CR;

    return $r, $length;

} ## tidy end: sub cl_output



sub cl_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };
    my %allnew    = %{ +shift };

    my $length = $added{len} + $removed{len} + $height_of{CL};

    my $r = para('FirstLineIntro');
    if ( scalar keys %unchanged ) {
        $length += $unchanged{len};

        $r
          .= "\u$unchanged{thesestop} here:"
          . $CR
          . para( 'CurrentLines', $unchanged{lines} )
          . $CR
          . para('LineIntro')
          . "Effective $date, $added{these} will "
          . IDTags::underline('also')
          . " stop here:$CR"

    }
    else {
        $r .=

          "Effective $date, $added{these} will "
          . IDTags::underline('begin')
          . " stopping here:$CR"

    }

    $r
      .= para( 'AddedLines', $added{lines} )
      . $CR
      . para('LineIntro')
      . "\u$removed{these} will "
      . IDTags::underline('not')
      . " stop here:$CR"
      . para( 'RemovedLines', $removed{lines} )
      . $CR;

    return $r, $length;

} ## tidy end: sub cl_output

sub as_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };

    my $r = para( 'NewBusStop', "NEW " . IDTags::softreturn . "BUS STOP$CR" );
    $r .= para('FirstLineIntro');
    $r .= "Effective $date, $added{these} will stop here:$CR";
    $r .= para( 'AddedLines', $added{lines} ) . $CR;
    my $length = $added{len} + $height_of{AS};
    return $r, $length;

}

sub rs_output {
    my %added     = %{ +shift };
    my %removed   = %{ +shift };
    my %unchanged = %{ +shift };
    my $length    = $removed{len} + $height_of{RS};

    my $r
      = current(%removed)
      . para( 'Removed', "Effective $date, this bus stop will be removed." )
      . $CR;

    return $r, $length;

}

sub para {
    $paras{ $_[0] }++;
    return IDTags::parastyle(@_);
}

sub current {
    my %current = @_;
    my $r = para( 'Current', "Current $current{word} at this stop:$CR" );
    $r .= para( 'CurrentLines', $current{lines} ) . $CR;
    return $r;
}

sub allnew {
    my %allnew = @_;
    my $r = para( 'Current', ucfirst("$allnew{these} will stop here:$CR") );
    $r .= para( 'CurrentLines', $allnew{lines} ) . $CR;
    return $r;
}

sub prepary {

    return if @_ == 0;

    my %return;

    if ( scalar(@_) == 1 ) {
        $return{word}      = 'line';
        $return{these}     = 'this line';
        $return{thesestop} = 'this line stops';
    }
    else {
        $return{word}      = 'lines';
        $return{these}     = 'these lines';
        $return{thesestop} = 'these lines stop';
    }

    #my $chars = join( $EMPTY_STR, @_ );
    #my $numbers = ( $chars =~ tr/0-9// );
    #my $letters = ( $chars =~ tr/A-Z// );
    #my $charwidth = $numbers + $letters * 1.33 + $#_;
    #my $textlines = ceil( $charwidth / 10 ) - 1;    # starts with 0

    #my $sum       = 0;
    #my $textlines = 0;    # one line of numbers is assumed in
    #                      # $height{AL}, $height{RL}, etc.

    my $bigsep = IDTags::enspace . IDTags::discretionary_lf;
    #my $smallsep = $bigsep;
    my $smallsep
      = IDTags::thirdspace
      . ( IDTags::hairspace() x 2 )
      . IDTags::discretionary_lf;

    my @textlines;
    my $thisline = $EMPTY_STR;

    my $line_width = 11;

    foreach my $i ( 0 .. $#_ - 1 ) {

        my $chars = $_[$i];

        if ( charwidth( $thisline . $chars ) <= $line_width ) {
            # less than or equal to than line length
            $thisline .= $chars . $SPACE;
        }
        else {
            push @textlines, $thisline;
            $thisline = $chars . $SPACE;
        }

    }

    # last item

    my $chars = $_[-1] || $EMPTY_STR;

    if ( charwidth( $thisline . $chars ) <= ($line_width) ) {
        # less than or equal to than line length
        push @textlines, $thisline . $chars;
    }
    else {
        push @textlines, $thisline, $chars;
    }

    $return{'len'} = (scalar @textlines) * $height_of{numbers};

    my $sep = $bigsep;

    foreach (@textlines) {
        if ( charwidth($_) >= $line_width - 1 ) {
            $sep = $smallsep;
            last;
        }
    }

    my $lines = join( $EMPTY_STR, @textlines );
    $lines =~ s/$SPACE/$sep/g;
    $return{lines} = $lines;

    $return{simplelines} = joinseries(@_);

    return (%return);

}    ## <perltidy> end sub prepary

sub start {
    return "<ASCII-MAC>$CR<Version:6><FeatureSet:InDesign-Roman>";
}

sub charwidth {
    my $chars = shift;
    return 0 unless $chars;

    my $letters = ( $chars =~ tr/A-Z// );

    my $nonletters = length($chars) - $letters;

    return ( $letters * 1.34 + $nonletters );

}

sub note_length {
    my $note = shift;
    return 0 unless $note;
    my $width = charwidth($note);
    return 1.2 * ceil( $width / 34 );
    # 1.2 is approx height of note line. 32 is approximate characters per line. 
    # Just guesses...
}
