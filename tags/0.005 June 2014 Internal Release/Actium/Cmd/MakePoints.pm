# Actium/Cmd/MakePoints.pm

# Subversion: $Id$

# legacy stage 4

package Actium::Cmd::MakePoints 0.001;

use warnings;
use strict;

use 5.014;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;

use Carp;
use POSIX ('ceil');

use Actium::Term (qw<output_usage printq sayq>);
use Actium::Constants;
use Actium::Union('ordered_union');

use Actium::Files::FileMaker_ODBC (qw[load_tables]);

use List::MoreUtils('natatime');
use Actium::O::Folders::Signup;

use File::Slurp;
use Text::Trim;

use Actium::Options;

use Actium::O::Points::Point;

use Const::Fast;

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

    our ( @signs, @stops, @lines, @signtypes, @timepoints );
    our ( %signs, %stops, %lines, %signtypes, %timepoints );

    # retrieve data

    load_tables(
    requests => {
        Timepoints => {
            array       => \@timepoints,
            hash        => \%timepoints,
            index_field => 'Abbrev4'
        },
        SignTypes => {
            array       => \@signtypes,
            hash        => \%signtypes,
            index_field => 'SignType'
        },
        Signs => { array => \@signs, hash => \%signs, index_field => 'SignID',
           fields => [qw[
           SignID Active stp_511_id Status SignType Sidenote UseOldMakepoints 
           ShelterNum UNIQUEID
           ]], 
            
             },
        Lines => { array => \@lines, hash => \%lines, index_field => 'Line' },
        Stops_Neue => {
            hash        => \%stops,
            index_field => 'h_stp_511_id',
            fields => [qw[h_stp_511_id c_description_full ]],
        },
    }
);

    my $effectivedate = trim( read_file('effectivedate.txt') );

    sayq "Now processing point schedules for sign number:\n";

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

        my $ostopid = $signs{$signid}{UNIQUEID};
        my $stopid  = $signs{$signid}{stp_511_id};

        my $sign_is_active = lc( $signs{$signid}{Active} ) ;

        next SIGN
          unless $stopid
              and $sign_is_active eq 'yes'
              and $signs{$signid}{Status} !~ /no service/i;
        # skip inactive signs and those without stop IDs
        
        my $old_makepoints = lc( $signs{$signid}{UseOldMakepoints});

        next SIGN if $old_makepoints eq 'yes';

        #####################
        # Following steps

        # skip stop if file not found
        my $citycode = substr( $stopid, 0, 2 );
        my $kpointfile = "kpoints/$citycode/$stopid.txt";

        unless ( -e $kpointfile ) {
            $skipped_stops{$signid} = "$ostopid:$stopid";
          #print "\nSkipped sign ID $signid: no file found for stop $stopid.\n";
            next SIGN;
        }

        print "$signid ";

        # 1) Read kpoints from file

        my $point
          = Actium::O::Points::Point->new_from_kpoints( $stopid, $signid,
            $effdate , $old_makepoints);

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

    print "\n\n", scalar keys %skipped_stops,
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
