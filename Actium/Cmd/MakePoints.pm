# Actium/Cmd/MakePoints.pm

# legacy stage 4

package Actium::Cmd::MakePoints 0.010;

use warnings;
use strict;

use 5.014;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;

use Actium::Preamble;

use Actium::Term (':all');
use Actium::Union('ordered_union');

use Actium::Files::FileMaker_ODBC (qw[load_tables]);

use Actium::O::Folders::Signup;

use File::Slurp::Tiny('read_file'); ### DEP ###
use Text::Trim; ### DEP ###

use Actium::O::Points::Point;

const my $IDPOINTFOLDER => 'indesign_points';

sub HELP {

    my $helptext = <<'EOF';
MakePoints reads the data written by avl2points and turns it into 
output suitable for InDesign.
It is saved in the directory "points" in the directory for that signup.
EOF

    say $helptext;

    output_usage;

    return;

}

sub START {

    my $class = shift;

    my %params = @_;
    my $config = $params{config};

    my $signup = Actium::O::Folders::Signup->new();
    chdir $signup->path();

    my $pointdir = $signup->subfolder($IDPOINTFOLDER);

    my $effdate = read_file('effectivedate.txt');

    #our ( @signs, @stops, @lines, @signtypes );
    our ( %places, %signs, %stops, %lines, %signtypes );
    #our ( @places );
    our (@ssj);

    # retrieve data

    load_tables(
        requests => {
            Places_Neue => {
                #array       => \@places,
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
            SignTypes => {
                #array       => \@signtypes,
                hash        => \%signtypes,
                index_field => 'SignType'
            },
            Signs => {
                #array       => \@signs,
                hash        => \%signs,
                index_field => 'SignID',
                fields      => [
                    qw[
                      SignID Active stp_511_id Status SignType Sidenote
                      UseOldMakepoints ShelterNum NonStopLocation NonStopCity
                      ]
                ],
            },
            Signs_Stops_Join => { array => \@ssj },
            Lines =>
              { 
                  # array => \@lines, 
                  hash => \%lines, 
                  index_field => 'Line' },
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
           @ssj_omitted = split(' ' , $ssj->{OmitLines});
        }
        $stops_of_sign{$ssj_sign}{$ssj_stop} = \@ssj_omitted ;
    }

    my $effectivedate = trim( read_file('effectivedate.txt') );

    emit "Now processing point schedules for sign number:";

    my $displaycolumns = 0;
    my @signstodo;

    if (@ARGV) {
        @signstodo = @ARGV;
    }
    else {
        @signstodo = keys %signs;
    }

    my %skipped_stops;

  SIGN:
    foreach my $signid ( sort { $a <=> $b } @signstodo ) {

        my $stopid = $signs{$signid}{stp_511_id};

        my $nonstoplocation;
        if ( not($stopid) ) {
            $nonstoplocation = $signs{$signid}{NonStopLocation} . ', '
              . $signs{$signid}{NonStopCity};
        }

        my $omitted_of_stop_r;
        if ( exists $stops_of_sign{$signid} ) {
            
            $omitted_of_stop_r = $stops_of_sign{$signid};

            if (not $stopid) {
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
        
        if (not $stopid) {
            emit_text 'yowza';
        }

        my $old_makepoints = lc( $signs{$signid}{UseOldMakepoints} );
        #next SIGN if $old_makepoints eq 'yes';
        ## Old makepoints no longer used, but that field also specifies
        # BSH or DB

        #####################
        # Following steps

        foreach my $stoptotest (keys %{$omitted_of_stop_r} ) {

            # skip stop if file not found
            my $firstdigits = substr( $stoptotest, 0, 3 );
            my $kpointfile = "kpoints/${firstdigits}xx/$stoptotest.txt";

            unless ( -e $kpointfile ) {
                $skipped_stops{$signid} = $stoptotest;
                next SIGN;
            }

        }

        emit_over( "$signid ");

        # 1) Read kpoints from file

        my $point
          = Actium::O::Points::Point->new_from_kpoints( $stopid, $signid,
            $effdate, $old_makepoints, $omitted_of_stop_r, $nonstoplocation );

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

        $point->sort_columns_by_route_etc;

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
    
    emit_done;

    print "\n", scalar keys %skipped_stops,
      " skipped signs because stop file not found.\n";

    my $iterator = natatime( 3, sort { $a <=> $b } keys %skipped_stops );
    while ( my @s = $iterator->() ) {
        print "Sign $s[0]: $skipped_stops{$s[0]}";
        print "\tSign $s[1]: $skipped_stops{$s[1]}" if $s[1];
        print "\tSign $s[2]: $skipped_stops{$s[2]}" if $s[2];
        print "\n";
    }

} ## tidy end: sub START

1;
