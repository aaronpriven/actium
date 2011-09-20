# Actium/MakePoints.pm

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::MakePoints 0.001;

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

use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils('natatime');
use Actium::Signup;

use File::Slurp;
use Text::Trim;

use Actium::Signup;
use Actium::Options;

use Actium::Points::Point;

use Readonly;

Readonly my $IDPOINTFOLDER => 'indesign_points';

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

    my $signup = Actium::Signup->new();
    chdir $signup->path();

    my $pointdir = $signup->subdir($IDPOINTFOLDER);

    my $effdate = read_file('effectivedate.txt');

    our ( @signs, @stops, @lines, @signtypes, @projects, @timepoints );
    our ( %signs, %stops, %lines, %signtypes, %projects, %timepoints );
    our ( %stops_by_oldstopid, @stops_by_oldstopid );

    # retrieve data

    FPread_simple( "SignTypes.csv", \@signtypes, \%signtypes, 'SignType' );
    printq scalar(@signtypes), " records.\nProjects... ";
    FPread_simple( "Projects.csv", \@projects, \%projects, 'Project' );
    printq scalar(@projects), " records.\nTimepoints... ";
    FPread_simple( "Timepoints.csv", \@timepoints, \%timepoints, 'Abbrev4' );
    printq scalar(@timepoints), " records.\nSigns... ";
    FPread_simple( "Signs.csv", \@signs, \%signs, 'SignID' );
    printq scalar(@signs), " records.\nSkedspec... ";
    FPread_simple( "Lines.csv", \@lines, \%lines, 'Line' );
    printq scalar(@lines), " records.\nStops (be patient, please)... ";

    FPread_simple( "Stops.csv", \@stops, \%stops, 'PhoneID' );
    FPread_simple( "Stops.csv", \@stops_by_oldstopid, \%stops_by_oldstopid,
        'stop_id_1' );
    printq scalar(@stops), " records.\nLoaded.\n\n";

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
        my $stopid  = $stops_by_oldstopid{$ostopid}{PhoneID};

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
          = Actium::Points::Point->new_from_kpoints( $stopid, $signid,
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