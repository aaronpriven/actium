# Actium/Cmd/Tabskeds.pm

# This is the program that creates the "tab files" that are used in the
# Designtek-era web schedules

# Makes tab-delimited but public versions of the skeds in /skeds

package Actium::Cmd::Tabskeds 0.010;

use Actium::Preamble;
use Actium::Sorting::Line ('sortbyline');
use Actium::Util(qw/joinseries/);
use Actium::Files::FileMaker_ODBC (qw[load_tables]);
use Actium::Term                  (qw<printq sayq>);
use Actium::O::Folders::Signup;

use strict;      ### DEP ###
use warnings;    ### DEP ###
no warnings 'uninitialized';

sub OPTIONS {
    return ( [ 'upcoming=s', 'Upcoming signup' ],
        [ 'current!', 'Current signup' ] );
}

my $out;
# filehandle, declared here so it can be shared between START() and outtab()

####################################################################
#  Old Skedfile.pm is loaded here, ahead of main program.
#  Included because this is the only program that now uses it.
####################################################################

# Skedfile.pm

# This is Skedfile.pm, a module to read and write
# the tab-separated-value text files which store the bus schedules.

# Also performs operations on bus schedule data structures that
# are shared between various programs.

# legacy stage 1
# (and it shows... irrelevant subroutine prototypes... C-style for loops...
# etc., etc.)

use constant GETFILES_PUBLIC_AND_DB => 3;

use constant GETFILES_ALL => 2;

use constant GETFILES_PUBLIC => 1;

sub Skedread {

    local ($_);

    my $skedref = {};

    my ($file) = shift;

    open IN, $file
      or die "Can't open $file for input";

    $_ = <IN>;
    chomp;
    s/\s+$//;
    $skedref->{SKEDNAME} = $_;

    ( $skedref->{LINEGROUP}, $skedref->{DIR}, $skedref->{DAY} ) = split(/_/);

    $_ = <IN>;
    s/\s+$//;
    chomp;
    ( undef, @{ $skedref->{NOTEDEFS} } ) = split(/\t/);

    # first column is always "Note Definitions"

    $_ = <IN>;
    chomp;
    s/\s+$//;
    ( undef, undef, undef, undef, @{ $skedref->{TP} } ) = split(/\t/);

  # the first four columns are always "SPEC DAYS", "NOTE" , "VT" , and "RTE NUM"

    while (<IN>) {
        chomp;
        s/\s+$//;
        next unless $_;    # skips blank lines
        my ( $specdays, $note, $vt, $route, @times ) = split(/\t/);

        push @{ $skedref->{SPECDAYS} }, $specdays;
        push @{ $skedref->{NOTES} },    $note;
        push @{ $skedref->{VT} },       $vt;
        push @{ $skedref->{ROUTES} },   $route;

        $#times = $#{ $skedref->{TP} };

        # this means that the number of time columns will be the same as
        # the number timepoint columns -- discarding any extras and
        # padding out empty ones with undef values

        for ( my $col = 0 ; $col < scalar(@times) ; $col++ ) {
            push @{ $skedref->{TIMES}[$col] }, $times[$col];
        }
    } ## tidy end: while (<IN>)
    close IN;
    return $skedref;
} ## tidy end: sub Skedread

sub getfiles {

    my $status = shift;

    return
      grep ( ( !/=/ and !m@^skeds/I@ and !m@^skeds/DB@ and !m@^skeds/BS[DNH]@ ),
        glob('skeds/*.txt') );

}

############################################################
# End of Skedfile
###########################################################

############################################################
# Including old Skedvars.pm, again this is the only file that
# still uses it
###########################################################

our %specdaynames = (
    "SD" => "School days only",
    "SH" => "School holidays only",
    "TT" => "Tuesdays and Thursdays only",
    "TF" => "Tuesdays and Fridays only",
    "WF" => "Wednesdays and Fridays only",
    "MZ" => "Mondays, Wednesdays, and Fridays only",
    "MT" => "Mondays through Thursdays",
    'F'  => 'Fridays only',
    'SA' => 'Saturdays only',
);

our %bound = (
    EB => 'Eastbound',
    SB => 'Southbound',
    WB => 'Westbound',
    NB => 'Northbound',
    CW => 'Clockwise',
    CC => 'Counterclockwise',
    A  => 'A Loop',
    B  => 'B Loop',
);

our %onechar_directions = qw(
  EB  E
  SB  S
  WB  W
  NB  N
  CW  8
  CC  9
  A   A
  B   B
);

our %adjectivedaynames = (
    WD => "Weekday",
    WE => "Weekend",
    DA => "Daily",
    SA => "Saturdays",
    SU => "Sundays and Holidays",
);

our %longerdaynames = (
    WD => "Monday through Friday",
    WE => "Sat., Sun. and Holidays",
    DA => "Every day",
    SA => "Saturdays",
    SU => "Sundays and Holidays",
    WU => "Weekdays and Sundays",
);

our %longdaynames = (
    WD => "Mon thru Fri",
    WE => "Sat, Sun and Holidays",
    DA => "Every day",
    SA => "Saturdays",
    SU => "Sundays and Holidays",
);

our %shortdaynames = (
    WD => "Mon thru Fri",
    WE => "Sat, Sun, Hol",
    DA => "Every day",
    SA => "Saturdays",
    SU => "Sun & Hol",
);

our %longdirnames = (
    E  => "east",
    N  => "north",
    S  => "south",
    W  => "west",
    SW => "southwest",
    SE => "southeast",
    NE => "northeast",
    NW => "northwest",
    CC => 'counterclockwise',
    CW => 'clockwise',
    A  => 'A loop',
    B  => 'B loop',
);

our %dayhash = (
    DA => 50,
    WD => 40,
    WE => 30,
    SA => 20,
    SU => 10,
);

our %dirhash = (
    WB => 60,
    SB => 50,
    EB => 40,
    NB => 30,
    CC => 20,
    CW => 10,
);

our %daydirhash = (
    CW_DA => 110,
    CC_DA => 120,
    NB_DA => 130,
    EB_DA => 140,
    SB_DA => 150,
    WB_DA => 160,
    CW_WD => 210,
    CC_WD => 220,
    NB_WD => 230,
    EB_WD => 240,
    SB_WD => 250,
    WB_WD => 260,
    CW_WE => 310,
    CC_WE => 320,
    NB_WE => 330,
    EB_WE => 340,
    SB_WE => 350,
    WB_WE => 360,

    CW_WU => 361,
    CC_WU => 362,
    NB_WU => 363,
    EB_WU => 364,
    SB_WU => 365,
    WB_WU => 366,

    CW_SA => 410,
    CC_SA => 420,
    NB_SA => 430,
    EB_SA => 440,
    SB_SA => 450,
    WB_SA => 460,
    CW_SU => 510,
    CC_SU => 520,
    NB_SU => 530,
    EB_SU => 540,
    SB_SU => 550,
    WB_SU => 560,
);

############################################################
# End of Skedvars
###########################################################

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my @specdaynames;
    foreach ( keys %specdaynames ) {
        push @specdaynames, $_ . "\035" . $specdaynames{$_};
    }
    @specdaynames = sort @specdaynames;

    #use Skedtps qw(tphash tpxref destination TPXREF_FULL);

    my $signupfolder = Actium::O::Folders::Signup->new();
    chdir $signupfolder->path();
    my $signup = $signupfolder->signup;

    our %second = %LINES_TO_COMBINE;

    #( "40L" => '40' , "59A" => '59' , "72M" => '72' ,
    #  386  => '86' , LC => 'L' , NXC => 'NX4' ,
    # ); # , '51S' => '51' );

    our %first = reverse
      %second;    # create a reverse hash, with values of %second as keys and

    # keys of %second as values

    our (%maplines);

    $| = 1;       # don't buffer terminal output

    printq "tab - create a set of public tab-delimited files\n\n";

    printq "Using signup $signup\n";

    open my $date, "<effectivedate.txt"
      or die "Can't open effectivedate.txt for input: $!";
    our $effdate = scalar <$date>;
    close $date;
    chomp $effdate;

    my $prepdate;

    {
        my ( $mday, $mon, $year ) = ( localtime(time) )[ 3 .. 5 ];
        $mon = qw(Jan. Feb. March April May June July Aug. Sept. Oct. Nov. Dec.)
          [$mon];
        $year += 1900;    # Y2K compliant
        $prepdate = "$mon $mday, $year";
    }

    our ( @lines, %lines, %places, %colors, @colors, @places );

    load_tables(
        requests => {
            Places_Neue => {
                array       => \@places,
                hash        => \%places,
                index_field => 'c_abbrev9',
            },
            Lines =>
              { array => \@lines, hash => \%lines, index_field => 'Line' },
            Colors =>
              { array => \@colors, hash => \%colors, index_field => 'ColorID' },
        }
    );

    mkdir "tabxchange"
      or die "Can't make directory 'tabxchange': $!"
      unless -d "tabxchange";

    my @files = getfiles(GETFILES_PUBLIC_AND_DB);

    my %skednamesbyroute = ();
    my %skeds;
    my %index;

    # slurp all the files into memory and build hashes
    foreach my $file (@files) {
        my $sked     = Skedread($file);
        my $skedname = $sked->{SKEDNAME};
        $skeds{$skedname} = $sked;

        my %routes = ();
        $routes{$_} = 1
          foreach @{ $sked->{ROUTES} }; # remember "ROUTES" is one for each trip
        @{ $sked->{ALLROUTES} } = keys %routes;

        foreach my $route ( @{ $sked->{ALLROUTES} } ) {
            push @{ $skednamesbyroute{$route} }, $skedname;
        }
    }

    print "\n";

    # write files

#### STUPIDITY TO DEAL WITH WRONG CODE ON THE PHP SIDE
    #
    my %destination_code_of;
    my $highest_destcode;

    my $basefolder = $signupfolder->base_obj;

    my $commonfolder = $basefolder->subfolder('common');

    my $destcode_file = 'destcodes.json';

    if ( -e $commonfolder->make_filespec($destcode_file) ) {
        %destination_code_of
          = %{ $commonfolder->json_retrieve($destcode_file) };
        {    # scoping
            my @sorted_codes = sort { length($b) <=> length($a) || $b cmp $a }
              values %destination_code_of;
            $highest_destcode = $sorted_codes[0];
        }
    }
    else {
        say 'No destination code file found.';
    }

    # write files

    foreach my $route ( sortbyline keys %skednamesbyroute ) {

        next if $second{$route};

        printf "%-4s", $route;

        foreach
          my $skedname ( sort bydaydirhash ( @{ $skednamesbyroute{$route} } ) )
        {

            my $skedref = $skeds{$skedname};

            undef $out;    # clear any previous out file handles
            open $out, ">", "tabxchange/" . $skedname . ".tab"
              or die "can't open $skedname.tab for output";

            my @allroutes = sortbyline( uniq( @{ $skedref->{ROUTES} } ) );
            my $linegroup = $allroutes[0];

            # GENERAL SCHEDULE INFORMATION

            outtab($skedname);
            my $day = $skedref->{DAY};
            outtab( $day, $adjectivedaynames{$day},
                $longdaynames{$day}, $longerdaynames{$day} );
            my $dir = $skedref->{DIR};

            my @tp = ( @{ $skedref->{TP} } );

            my $final_tp    = $tp[-1] =~ s/=\d\z//r;
            my $destination = $places{$final_tp}{c_destination};

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

            # they want a different direction code for each destination. Sigh.

            if ( not exists $destination_code_of{$destination} ) {
                if ($highest_destcode) {
                    $highest_destcode++;
                }
                else {
                    $highest_destcode
                      = 'GA';    # higher than any in use when system reset
                }
                $destination_code_of{$destination} = $highest_destcode;
            }

            outtab(
                $onechar_directions{$dir} . $destination_code_of{$destination},
                $bound{$dir}, $destination
            );

            #my $code_destination = uc($destination);
            #$code_destination =~ s/[^A-Z0-9]//g;

            #$code_destination = scalar reverse $code_destination;
            #outtab ($code_destination, $bound{$dir} , $destination);

            # LINEGROUP FIELDS

            outtab(
                "U",
                $linegroup,
                $lines{$linegroup}{LineGroupWebNote},
                $lines{$linegroup}{LineGroupType},
                $lines{$linegroup}{UpcomingOrCurrentLineGroup}
            );
            outtab(@allroutes);

            my @skednames;
            foreach (@allroutes) {
                push @skednames, ( @{ $skednamesbyroute{$linegroup} } );
            }
            outtab( sort +( uniq(@skednames) ) );

            # LINE FIELDS

            foreach (@allroutes) {
                my $colorref = $colors{ $lines{$linegroup}{Color} };
                outtab(
                    $_,                        $lines{$_}{Description},
                    $lines{$_}{DirectionFile}, $lines{$_}{StopListFile},
                    $lines{$_}{MapFileName},   '',
                    ,                          $lines{$_}{TimetableDate},
                    $colorref->{"Cyan"},       $colorref->{"Magenta"},
                    $colorref->{"Yellow"},     $colorref->{"Black"},
                    $colorref->{"RGB"}
                  )

            }

            # TIMEPOINT FIELDS

            #my @tp = (@{$skedref->{TP}});  # moved earlier

            #outtab (@tp);
            my ( @tp4, @tp_lookup );
            @tp_lookup = @tp;
            s/=\d+\z// foreach @tp_lookup;

            push @tp4, $places{$_}{h_plc_identifier} foreach @tp_lookup;

            outtab(@tp4);

            my $tpcol;
            for $tpcol ( 0 .. $#tp ) {

                my $tp        = $tp[$tpcol];
                my $tp_lookup = $tp_lookup[$tpcol];
                my $tp4       = $tp4[$tpcol];

                #my $tp = tpxref($tp[$tpcol]);
                my $faketimepointnote;

     #$faketimepointnote = "Waits six minutes for transferring BART passengers."
     #    if $tp eq "SHAY BART" and $skedname eq "91_SB_WD";

                warn "Not 4 characters: [$tp4/$tp_lookup/$tp]"
                  if length($tp4) != 4;
                warn "Blank tp [$tp4/$tp_lookup/$tp]"
                  if $tp_lookup eq '' or $tp eq '';

                outtab(
                    $tp4,
                    $places{$tp_lookup}{c_description},
                    $places{$tp_lookup}{c_city},
                    $places{$tp_lookup}{ux_usecity_description} ? 'Yes' : 'No',
                    "",    # $Skedtps::timepoints{$tp_lookup}{Neighborhood},
                    "",    # $Skedtps::timepoints{$tp_lookup}{TPNote},
                    $faketimepointnote
                );

# When you add a way to have "Notes associated with a timepoint (column) in this schedule alone",
# replace $faketimepointnote with that.

            } ## tidy end: for $tpcol ( 0 .. $#tp )

            # SCHEDULE FIELDS

            #outtab (@{$skedref->{NOTEDEFS}});
            # Fake some NOTEDEFS

            my @notedefs;

            for ($skedname) {
                if (/^43/) {
                    @notedefs = (
                        "F Serves Bulk Mail Center.",
                        "G Serves Bulk Mail Center."
                    );
                }
                elsif (/^51/) {
                    @notedefs
                      = (
"B On school days, except Fridays, operates three minutes earlier between Broadway & Blanding Ave. and Atlantic Ave. & Webster St. Stops at College of Alameda administration building."
                      );
                }
                elsif (/^I81/)
                {    # never a line I81  -- serves to comment out code
                    @notedefs = (
"D Serves Griffith St, Burroughs Ave., and Farallon Dr.",
"E Serves Griffith St, Burroughs Ave., and Farallon Dr.",
"K Serves Griffith St, Burroughs Ave., and Farallon Dr.",
                        "L Serves Hayward Amtrak.",
                        "M Serves Hayward Amtrak.",
"Q Serves Griffith St, Burroughs Ave., and Farallon Dr., and also Hayward Amtrak.",
                        "R Serves Hayward Amtrak.",
                    );

                }
                elsif (/^I84/) {
                    @notedefs = (
"A Does not serve Fargo Ave.; operates via Lewelling Blvd. and Washington Ave.",
"B Does not serve Fargo Ave.; operates via Washington Ave. and Lewelling Blvd."
                    );
                }
                elsif (/^LA?/) {
                    @notedefs
                      = (
'LC This "L & LA" trip operates as Line L as far as El Portal Dr. & I-80, then continues and serves Line LA between Hilltop Park & Ride and Richmond Parkway Transit Center.'
                      );
                }
                elsif ( /^NX2/ or /^NX3/ ) {
                    @notedefs
                      = (
'NC This trip is an "NX2 and NX3" trip or "NX2 and NX3 and NX4" trip and serves all areas on Line NX2 before continuing on Line NX3 and Line NX4.'
                      );
                }
                elsif (/^NX4/) {
                    @notedefs
                      = (
'NC This trip is an "NX2 and NX3 and NX4" trip and serves all areas on ines NX2 and NX3 before continuing on Line NX4.'
                      );
                }
            } ## tidy end: for ($skedname)

            for (@notedefs) {
                s/ /$KEY_SEPARATOR/ unless /$KEY_SEPARATOR/;
            }

            outtab(@notedefs);

            my $fullnote = q{};

            if ( $lines{$linegroup}{schedule_note} ) {
                $fullnote = "<p>$lines{$linegroup}{schedule_note}</p>";
            }

            my $govtopic = $lines{$route}{GovDeliveryTopic};
            if ($govtopic) {
                $fullnote
                  .= '<p>'
                  . q{<a href="https://public.govdelivery.com/}
                  . q{accounts/ACTRANSIT/subscriber/new?topic_id=}
                  . $govtopic . q{">}
                  . 'Get timely, specific updates about '
                  . "Line $route from AC Transit eNews."
                  . '</a></p>';
            }

            $fullnote .= '<p>The times provided are for '
              . 'important landmarks along the route.';

            my %stoplist_url_of;
            foreach my $route ( sortbyline @allroutes ) {

                my $linegrouptype = lc( $lines{$route}{LineGroupType} );
                $linegrouptype =~ s/ /-/g;    # converted to dashes by wordpress
                if ($linegrouptype) {
                    if ( $linegrouptype eq 'local' ) {
                        no warnings 'numeric';
                        if ( $route <= 70 ) {
                            $linegrouptype = 'local1';
                        }
                        else {
                            $linegrouptype = 'local2';
                        }
                    }

                    $stoplist_url_of{$route}
                      = qq{http://www.actransit.org/riderinfo/stops/$linegrouptype/#$route};
                }
                else {
                    warn "No linegroup type for line $route";
                }

            } ## tidy end: foreach my $route ( sortbyline...)

            my @linkroutes = sortbyline keys %stoplist_url_of;
            my $numlinks   = scalar @linkroutes;

            if ( $numlinks == 1 ) {
                my $linkroute = $linkroutes[0];

                $fullnote
                  .= $SPACE
                  . qq{<a href="$stoplist_url_of{$linkroute}">}
                  . qq{A complete list of stops for Line $linkroute is also available.</a>};
            }
            elsif ( $numlinks != 0 ) {

                my @stoplist_links
                  = map {qq{<a href="$stoplist_url_of{$_}">$_</a>}} @linkroutes;

                $fullnote
                  .= qq{ Complete lists of stops for lines }
                  . joinseries(@stoplist_links)
                  . ' are also available.';
            }

            $fullnote .= '</p>';

            outtab( $fullnote, $lines{$linegroup}{LineGroupNote} );

   #outtab ($skedadds{$skedname}{FullNote} , $lines{$linegroup}{LineGroupNote});

            outtab(q{});

            # outtab( $skedadds{$skedname}{UpcomingOrCurrentSkedID} );
            # Right now the line group fields are specified in the
            # first line of each line group. This isn't ideal but
            # might be OK

            outtab(@specdaynames);

            outtab( @{ $skedref->{SPECDAYS} } );
            outtab( @{ $skedref->{NOTES} } );
            outtab( @{ $skedref->{ROUTES} } );

            for $tpcol ( 0 .. $#tp ) {
                outtab( @{ $skedref->{TIMES}[$tpcol] } );
            }

            close $out;

        } ## tidy end: foreach my $skedname ( sort...)

    } ## tidy end: foreach my $route ( sortbyline...)

    print "\n";

    $commonfolder->json_store_pretty( \%destination_code_of, $destcode_file );

} ## tidy end: sub START

sub outtab {
    my @fields = @_;
    foreach (@fields) {
        s/\n/ /g;
    }
    print $out join( "\t", @fields, "\n" );
}

#sub uniq {
#    my %seen;
#    return sortbyline grep { !$seen{$_}++ } @_;
#}

sub bydaydirhash {
    ( my $aa = $a ) =~ s/.*?_//;    # minimal: it matches first _
    ( my $bb = $b ) =~ s/.*?_//;    # minimal: it matches first _
    $daydirhash{$aa} cmp $daydirhash{$bb};
}

1;
