# Actium/Cmd/MakePoints.pm

# legacy stage 4

package Actium::Cmd::MakePoints 0.010;

use warnings;    ### DEP ###
use strict;      ### DEP ###

use 5.014;

use sort ('stable');    ### DEP ###

# add the current program directory to list of files to include

use Actium::Preamble;

use Actium::Union('ordered_union');

use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   ('signup');

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

use File::Slurper('read_text');    ### DEP ###
use Text::Trim;                    ### DEP ###

use Actium::O::Points::Point;

const my $IDPOINTFOLDER => 'indesign_points';

sub HELP {

    my $helptext = <<'EOF';
MakePoints reads the data written by avl2points and turns it into 
output suitable for InDesign.
It is saved in the directory "points" in the directory for that signup.
EOF

    say $helptext;

    return;

}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env)
    );
}

sub START {

    my ( $class, $env ) = @_;

    our ( $actiumdb, %places, %signs, %stops, %lines, %signtypes, %smoking,
        @ssj );
    # this use of global variables should be refactored...

    $actiumdb = actiumdb($env);
    my @argv = $env->argv;

    my $signup = signup($env);
    chdir $signup->path();

    my $pointdir = $signup->subfolder($IDPOINTFOLDER);

    my $effdate = read_text('effectivedate.txt');

    # retrieve data

    %smoking = %{ $actiumdb->all_in_column_key(qw(Cities SmokingText)) };

    $actiumdb->load_tables(
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
            SignTypes => {
                hash        => \%signtypes,
                index_field => 'SignType'
            },
            Signs => {
                hash        => \%signs,
                index_field => 'SignID',
                fields      => [
                    qw[
                      SignID Active stp_511_id Status SignType Sidenote
                      UseOldMakepoints ShelterNum NonStopLocation NonStopCity
                      Delivery City
                      ]
                ],
            },
            Signs_Stops_Join => { array => \@ssj },
            Lines            => {
                hash        => \%lines,
                index_field => 'Line'
            },
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    my (%stops_of_sign);
    foreach my $ssj (@ssj) {
        my $ssj_stop = $ssj->{h_stp_511_id};
        my $ssj_sign = $ssj->{SignID};

        my $ssj_omit_lines = $ssj->{OmitLines};
        my @ssj_omitted;
        if ($ssj_omit_lines) {
            @ssj_omitted = split( ' ', $ssj->{OmitLines} );
        }
        $stops_of_sign{$ssj_sign}{$ssj_stop} = \@ssj_omitted;
    }

    my $cry = cry("Now processing point schedules for sign number:");

    my $displaycolumns = 0;
    my @signstodo;

    if (@argv) {
        @signstodo = @argv;
    }
    else {
        @signstodo = keys %signs;
    }

    my ( %skipped_stops, %points_of_signtype );

  SIGN:
    foreach my $signid ( sort { $a <=> $b } @signstodo ) {

        my $stopid   = $signs{$signid}{stp_511_id};
        my $delivery = $signs{$signid}{Delivery} // $EMPTY;
        my $city     = $signs{$signid}{City} // $EMPTY;

        my ( $nonstoplocation, $nonstopcity );
        if ( not($stopid) ) {
            $nonstopcity = $signs{$signid}{NonStopCity};
            $nonstoplocation
              = $signs{$signid}{NonStopLocation} . ', ' . $nonstopcity;
        }

        my $smoking = $smoking{$city} // $IDT->emdash;

        my $omitted_of_stop_r;
        if ( exists $stops_of_sign{$signid} ) {

            $omitted_of_stop_r = $stops_of_sign{$signid};

            if ( not $stopid ) {
                my @allstopids = sort keys %{$omitted_of_stop_r};
                $stopid = $allstopids[0];
            }

        }
        elsif ($stopid) {
            $omitted_of_stop_r = { $stopid => [] };
        }

        my $sign_is_active = lc( $signs{$signid}{Active} );

        next SIGN
          unless $stopid
          and $sign_is_active eq 'yes'
          and $signs{$signid}{Status} !~ /no service/i;
        # skip inactive signs and those without stop IDs

        my $old_makepoints = lc( $signs{$signid}{UseOldMakepoints} );
        #next SIGN if $old_makepoints eq 'yes';
        ## Old makepoints no longer used, but that field also specifies
        # BSH or DB

        #####################
        # Following steps

        foreach my $stoptotest ( keys %{$omitted_of_stop_r} ) {

            # skip stop if file not found
            my $firstdigits = substr( $stoptotest, 0, 3 );
            my $kpointfile = "kpoints/${firstdigits}xx/$stoptotest.txt";

            unless ( -e $kpointfile ) {
                $skipped_stops{$signid} = $stoptotest;
                next SIGN;
            }

        }

        $cry->over("$signid ");

        # 1) Read kpoints from file

        my $point
          = Actium::O::Points::Point->new_from_kpoints( $stopid, $signid,
            $effdate, $old_makepoints, $omitted_of_stop_r, $nonstoplocation,
            $smoking, $delivery );

        # 2) Change kpoints to the kind of data that's output in
        #    each column (that is, separate what's in the header
        #    from the times and what's in the footnotes)

        $point->make_headers_and_footnotes;

        # 3) Adjust times to make sure it estimates on the side of

        $point->adjust_times;

        # 4) Combine footnotes across columns, if necessary - may not need
        #    to do this

        # $point->combine_footnotes;

        # 5) Sort columns into order

        #$point->sort_columns_by_route_etc;
        my $subtype = $point->sort_columns_and_determine_heights(
            $signs{$signid}{SignType} );

        if ( $subtype and $subtype ne '!' ) {
            my ( $signtype, $master ) = split( /=/, $subtype );
            push @{ $points_of_signtype{$signtype} }, [ $signid, $master ];

        }

        # 6) Format with text and indesign tags. Includes
        #    expanding places into full place descriptions
        #    and dividing columns into ones that are
        #    the proper length (length comes from SignType),
        #    and adding footnote markers

        $point->format_columns( $signs{$signid}{SignType} );

        # 7) Format and expand the footnotes (the actual
        #    footnotes, not the footnote markers)

        $point->format_side;

        # 8) Add stop description

        $point->format_bottom;

        # 9) add blank columns in front (if needed) and
        #    output to points

        $point->output;

    }    ## <perltidy> end foreach my $signid ( sort {...})

    $cry->done;

    my $list_fh = $signup->open_write('pointlist.txt');
    #open my $list_fh, '>:utf8' , 'pointlist.txt';

    foreach my $signtype ( sort keys %points_of_signtype ) {
        say $list_fh "FILE\t$signtype";
        my @points = @{ $points_of_signtype{$signtype} };
        @points = sort { $a->[0] <=> $b->[0] } @points;
        # sort numerically by signid
        foreach my $point (@points) {
            my $pointline = $point->[0] . "\t" . $point->[1];
            say $list_fh $pointline;
        }
    }

    close $list_fh;

    print "\n", scalar keys %skipped_stops,
      " skipped signs because stop file not found.\n";

    my $iterator = u::natatime( 3, sort { $a <=> $b } keys %skipped_stops );
    while ( my @s = $iterator->() ) {
        print "Sign $s[0]: $skipped_stops{$s[0]}";
        print "\tSign $s[1]: $skipped_stops{$s[1]}" if $s[1];
        print "\tSign $s[2]: $skipped_stops{$s[2]}" if $s[2];
        print "\n";
    }
    
} ## tidy end: sub START

1;
