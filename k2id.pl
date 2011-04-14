#!/ActivePerl/bin/perl

# k2id - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

use 5.010;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin qw($Bin);
use lib $Bin;

use Carp;
use POSIX ('ceil');

use Actium::Term (qw<printq sayq>);
use Actium::Constants;
use Actium::Union('ordered_union');

use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils('natatime');

use File::Slurp;
use Text::Trim;

use Actium::Kidpoint;

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
k2id reads the data written by avl2points and turns it into 
output suitable for InDesign.
It is saved in the directory "kidpoints" in the directory for that signup.
EOF

my $intro = 'k2id.pl -- makes kidpoints: point schedules from Hastus';

use Actium::Options(qw<option init_options>);;
use Actium::Signup;

init_options();

my $signup = Actium::Signup->new();
chdir $signup->get_dir();

my $kidpointdir = $signup->subdir('kidpoints');

my $effdate = read_file( 'effectivedate.txt' ) ;

our ( @signs, @stops, @lines, @signtypes, @projects, @timepoints );
our ( %signs, %stops, %lines, %signtypes, %projects, %timepoints );
our (%stops_by_oldstopid, @stops_by_oldstopid);

# retrieve data

FPread_simple( "SignTypes.csv", \@signtypes, \%signtypes, 'SignType' );
printq scalar(@signtypes), " records.\nProjects... " unless option('quiet');
FPread_simple( "Projects.csv", \@projects, \%projects, 'Project' );
printq scalar(@projects), " records.\nTimepoints... " unless option('quiet');
FPread_simple( "Timepoints.csv", \@timepoints, \%timepoints, 'Abbrev4' );
printq scalar(@timepoints), " records.\nSigns... " unless option('quiet');
FPread_simple( "Signs.csv", \@signs, \%signs, 'SignID' );
printq scalar(@signs), " records.\nSkedspec... " unless option('quiet');
FPread_simple( "Lines.csv", \@lines, \%lines, 'Line' );
printq scalar(@lines), " records.\nStops (be patient, please)... "
  unless option('quiet');
FPread_simple( "Stops.csv", \@stops, \%stops, 'PhoneID' );
FPread_simple( "Stops.csv", \@stops_by_oldstopid, \%stops_by_oldstopid, 'stop_id_1' );
printq scalar(@stops), " records.\nLoaded.\n\n" unless option('quiet');

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
    my $stopid = $stops_by_oldstopid{$ostopid}{PhoneID};

    next SIGN
      unless $stopid
          and lc( $signs{$signid}{Active} ) eq "yes"
          and $signs{$signid}{Status} !~ /no service/i;
    # skip inactive signs and those without stop IDs

    next SIGN
       if lc( $signs{$signid}{UseOldMakepoints} ) eq "yes";

    #####################
    # Following steps

    # skip stop if file not found
    my $citycode = substr( $stopid, 0, 2 );
    my $kpointfile = "kpoints/$citycode/$stopid.txt";

    unless (-e $kpointfile) {
       $skipped_stops{$signid} = "$ostopid:$stopid";
       #print "\nSkipped sign ID $signid: no file found for stop $stopid.\n";
       next SIGN;
    }

    print "$signid ";

    # 1) Read kpoints from file

    my $kidpoint = Actium::Kidpoint->new_from_kpoints( $stopid, $signid, $effdate );

    # 2) Change kpoints to the kind of data that's output in
    #    each column (that is, separate what's in the header
    #    from the times and what's in the footnotes)

    $kidpoint->make_headers_and_footnotes;

    # 3) Adjust times to make sure it estimates on the side of

    $kidpoint->adjust_times;

    # 4) Combine footnotes across columns, if necessary - may not need
    #    to do this

    # $kidpoint->combine_footnotes;

    # 5) Sort columns into order

    $kidpoint->sort_columns_by_route_etc;

    # 6) Format with text and indesign tags. Includes
    #    expanding places into full place descriptions
    #    and dividing columns into ones that are
    #    the proper length (length comes from SignType),
    #    and adding footnote markers

    $kidpoint->format_columns( $signs{$signid}{SignType} );

    # 7) Format and expand the footnotes (the actual
    #    footnotes, not the footnote markers)

    $kidpoint->format_side;

    # 8) Add stop description

    $kidpoint->format_bottom;

    # 9) add blank columns in front (if needed) and
    #    output to kidpoints

    $kidpoint->output;

} ## <perltidy> end foreach my $signid ( sort {...})

print "\n\n" , scalar keys %skipped_stops , " skipped signs because stop file not found.\n";

my $iterator = natatime ( 3, sort { $a <=> $b } keys %skipped_stops )  ;
while ( my @s = $iterator->() ) {
   print "Sign $s[0]: $skipped_stops{$s[0]}";
   print "\tSign $s[1]: $skipped_stops{$s[1]}" if $s[1];
   print "\tSign $s[2]: $skipped_stops{$s[2]}" if $s[2];
   print "\n";
}

## END OF MAIN PROGRAM. BEGINNING OF OBJECTS

