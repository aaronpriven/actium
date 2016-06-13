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

const my $LISTFILE_BASE     => 'pointlist';
const my $ERRORFILE_BASE    => 'point_errors';
const my $SIGNIDS_IN_A_FILE => 250;

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
        Actium::Cmd::Config::Signup::options($env),
        [   'update',
            'Will only process signs that have the status "Needs Update."', 0
        ],
        [ 'type=s', 'Will only process signs that have a given signtype.', '' ],
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

    # retrieve data

    my $makepoints_cry = cry 'Making InDesign point schedule files';

    my $load_cry = cry 'Loading data from Actium database';

    %smoking = %{ $actiumdb->all_in_column_key(qw(Cities SmokingText)) };
    my $effdate = $actiumdb->agency_effective_date('ACTransit');

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

    my $ssj_cry = cry('Processing multistop entries');

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

    $ssj_cry->done;

    $load_cry->done;

    my $signtype_opt = $env->option('type');
    if ( $signtype_opt and not exists $signtypes{$signtype_opt} ) {
        $makepoints_cry->text(
            "Invalid signtype $signtype_opt specified on command line.");
        $makepoints_cry->d_error;
        exit 1;
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

    my ( %skipped_stops, %points_of_signtype, %errors );

  SIGN:
    foreach my $signid ( sort { $a <=> $b } @signstodo ) {

        my $stopid   = $signs{$signid}{stp_511_id};
        my $delivery = $signs{$signid}{Delivery} // $EMPTY;
        my $city     = $signs{$signid}{City} // $EMPTY;
        my $signtype = $signs{$signid}{SignType} // $EMPTY;
        my $status   = $signs{$signid}{Status};

        next SIGN
          if $signtype_opt and $signtype_opt ne $signtype;

        next SIGN
          if $env->option('update')
          and not( u::feq( $status, 'Needs update' ) );

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
                push @{ $errors{$signid} }, "Stop $stoptotest not found";
                $skipped_stops{$signid} = $stoptotest;
                next SIGN;
            }

        }

        $cry->over("$signid ");

        # 1) Read kpoints from file

        my $point = Actium::O::Points::Point->new_from_kpoints(
            $stopid,         $signid,            $effdate,
            $old_makepoints, $omitted_of_stop_r, $nonstoplocation,
            $smoking,        $delivery,          $signup
        );

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

        push @{ $errors{$signid} }, $point->errors;

    }    ## <perltidy> end foreach my $signid ( sort {...})

    $cry->done;

    my $run_name = _get_run_name($env);

    my $listfile = $LISTFILE_BASE . $run_name . '.txt';

    my $list_cry = cry "Writing list to $listfile";

    my $pointlist_folder = $signup->subfolder('pointlist');

    my $list_fh = $pointlist_folder->open_write($listfile);

    foreach my $signtype ( sort keys %points_of_signtype ) {
        my @points = @{ $points_of_signtype{$signtype} };
        @points = sort { $a->[0] <=> $b->[0] } @points;
        # sort numerically by signid

        my $end_signid = $SIGNIDS_IN_A_FILE;

        my $addition = "1-" . $SIGNIDS_IN_A_FILE;
        my $file_line_has_been_output;

        foreach my $point (@points) {

            my $signid         = $point->[0];
            my $subtype_letter = $point->[1];

            while ( $signid > $end_signid ) {
                $file_line_has_been_output = 0;
                $addition                  = ( $end_signid + 1 ) . "-"
                  . ( $end_signid + $SIGNIDS_IN_A_FILE );
                $end_signid += $SIGNIDS_IN_A_FILE;
            }
            # separating the addition and the print allows there to be large
            # gaps in the number of sign IDs

            if ( not $file_line_has_been_output ) {
                say $list_fh "FILE\t$signtype\t$addition";
                $file_line_has_been_output = 1;
            }

            say $list_fh "$signid\t$subtype_letter";
        } ## tidy end: foreach my $point (@points)
    } ## tidy end: foreach my $signtype ( sort...)

    close $list_fh;

    $list_cry->done;

    ### ERROR DISPLAY

    my $error_file = $ERRORFILE_BASE . $run_name . '.txt';

    my $error_cry = cry "Writing errors to $error_file";

    my $error_fh = $pointlist_folder->open_write($error_file);

    foreach my $signid ( sort { $a <=> $b } keys %errors ) {
        foreach my $error ( @{ $errors{$signid} } ) {
            say $error_fh "$signid\t$error";
        }
    }

    $error_fh->close;

    $cry->done;

   #    print "\n", scalar keys %skipped_stops,
   #      " skipped signs because stop file not found.\n";
   #
   #    my $iterator = u::natatime( 3, sort { $a <=> $b } keys %skipped_stops );
   #    while ( my @s = $iterator->() ) {
   #        printf ('%25s' ,  "Sign $s[0]: $skipped_stops{$s[0]}");
   #        printf '%25s' , "Sign $s[1]: $skipped_stops{$s[1]}" if $s[1];
   #        print  '%25s' ,  "Sign $s[2]: $skipped_stops{$s[2]}" if $s[2];
   #        print "\n";
   #    }

    $makepoints_cry->done;

} ## tidy end: sub START

sub _get_run_name {

    my $env      = shift;
    my @args     = $env->argv;
    my $signtype = $env->option('type');

    my $run = $EMPTY;

    $run .= "_" . join( '_', @args )
      if @args;

    $run .= "_$signtype" if $signtype;
    $run .= "_update" if $env->option('update');

    return $run;

}

1;
