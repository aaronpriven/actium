#!/ActivePerl/bin/perl
# tabskeds

# This is the program that creates the "tab files" that are used in the
# Designtek-era web schedules

# legacy stage 1

# Makes tab-delimited but public versions of the skeds in /skeds

use 5.014;

use strict;
use warnings;
no warnings 'uninitialized';

####################################################################
#  load libraries
####################################################################

use FindBin('$Bin');
# so $Bin is the location of the very file we're in now

use lib $Bin;
# there are few enough files that it makes sense to keep
# main program and library in the same directory

# libraries dependent on $Bin

use Storable;

use Actium::Sorting::Line ('sortbyline');
use Skedfile qw(Skedread Skedwrite GETFILES_PUBLIC
  getfiles GETFILES_PUBLIC_AND_DB trim_sked copy_sked);

use Skedvars qw(%longerdaynames %longdaynames %longdirnames
  %dayhash        %dirhash      %daydirhash
  %adjectivedaynames %bound %specdaynames
  %onechar_directions
);

my @specdaynames;
foreach ( keys %specdaynames ) {
    push @specdaynames, $_ . "\035" . $specdaynames{$_};
}

use Skedtps qw(tphash tpxref destination TPXREF_FULL);
use Actium::Files::FileMaker_ODBC (qw[load_tables]);

use Actium::Options (qw<option add_option init_options>);
add_option( 'upcoming=s', 'Upcoming signup' );
add_option( 'current!',   'Current signup' );
use Actium::Term (qw<printq sayq>);
use Actium::O::Folders::Signup;

init_options;

my $signupfolder = Actium::O::Folders::Signup->new();
chdir $signupfolder->path();
my $signup = $signupfolder->signup;

use Actium::Constants;

our %second = %LINES_TO_COMBINE;

#( "40L" => '40' , "59A" => '59' , "72M" => '72' ,
#  386  => '86' , LC => 'L' , NXC => 'NX4' ,
# ); # , '51S' => '51' );

our %first
  = reverse %second; # create a reverse hash, with values of %second as keys and
# keys of %second as values

our (%maplines);

$| = 1;              # don't buffer terminal output

printq "tab - create a set of public tab-delimited files\n\n";

printq "Using signup $signup\n";

open DATE, "<effectivedate.txt"
  or die "Can't open effectivedate.txt for input: $!";
our $effdate = scalar <DATE>;
close DATE;
chomp $effdate;

my $prepdate;

{
    my ( $mday, $mon, $year ) = ( localtime(time) )[ 3 .. 5 ];
    $mon = qw(Jan. Feb. March April May June July Aug. Sept. Oct. Nov. Dec.)
      [$mon];
    $year += 1900;    # Y2K compliant
    $prepdate = "$mon $mday, $year";
}

our ( @lines, %lines, @skedadds, %skedadds,
    %colors, @colors, %timepoints, @timepoints );

load_tables(
    requests => {
        Timepoints => {
            array       => \@timepoints,
            hash        => \%timepoints,
            index_field => 'Abbrev9'
        },
        SkedAdds => {
            array       => \@skedadds,
            hash        => \%skedadds,
            index_field => 'SkedID'
        },
        Lines => { array => \@lines, hash => \%lines, index_field => 'Line' },
        Colors =>
          { array => \@colors, hash => \%colors, index_field => 'ColorID' },
    }
);

Skedtps::initialize( \@timepoints, \%timepoints, TPXREF_FULL );

mkdir "tabxchange"
  or die "Can't make directory 'tabxchange': $!"
  unless -d "tabxchange";

my @files = getfiles(GETFILES_PUBLIC_AND_DB);

my %skednamesbyroute = ();
my %skeds;
my %index;

#use Data::Dumper;
#open my $dump , '>' , "/tmp/timepoints.dump";
#print $dump Data::Dumper::Dumper(\%Skedtps::timepoints);
#close $dump;

# slurp all the files into memory and build hashes
foreach my $file (@files) {
    my $sked     = Skedread($file);
    my $skedname = $sked->{SKEDNAME};
    $skeds{$skedname} = $sked;

    my %routes = ();
    $routes{$_} = 1
      foreach @{ $sked->{ROUTES} };    # remember "ROUTES" is one for each trip
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
    %destination_code_of = %{ $commonfolder->json_retrieve($destcode_file) };
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

        open OUT, ">", "tabxchange/" . $skedname . ".tab"
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

        my $destination = destination( $tp[-1] );

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

       #outtab($dir, $longdirnames{$dir},$skedadds{$skedname}{"DirectionText"});

        outtab( $onechar_directions{$dir} . $destination_code_of{$destination},
            $bound{$dir}, $destination );

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
        Skedtps::delete_punctuation(@tp_lookup);
        push @tp4, $Skedtps::timepoints{$_}{Abbrev4} foreach @tp_lookup;

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

            warn "Not 4 characters: [$tp4/$tp_lookup/$tp]" if length($tp4) != 4;

            outtab(
                $tp4,
                tphash($tp),
                $Skedtps::timepoints{$tp_lookup}{City},
                $Skedtps::timepoints{$tp_lookup}{UseCity},
                "",    # $Skedtps::timepoints{$tp_lookup}{Neighborhood},
                $Skedtps::timepoints{$tp_lookup}{TPNote},
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
                @notedefs = ( "F Serves Bulk Mail Center.",
                    "G Serves Bulk Mail Center." );
            }
            elsif (/^51/) {
                @notedefs
                  = (
"B On school days, except Fridays, operates three minutes earlier between Broadway & Blanding Ave. and Atlantic Ave. & Webster St. Stops at College of Alameda administration building."
                  );
            }
            elsif (/^I81/) {   # never a line I81  -- serves to comment out code
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

        my $fullnote;

        if ( $skedadds{$skedname}{FullNote} ) {
            $fullnote = "<p>$skedadds{$skedname}{FullNote}</p>";
        }

        foreach my $route (@allroutes) {
            my $govtopic = $lines{$route}{GovDeliveryTopic};
            next unless $govtopic;
            $fullnote
              .= '<p>'
              . q{<a href="https://public.govdelivery.com/}
              . q{accounts/ACTRANSIT/subscriber/new?topic_id=}
              . $govtopic . q{">}
              . 'Get timely, specific updates about '
              . "Line $route from AC Transit eNews."
              . '</a></p>';
        }

        outtab( $fullnote, $lines{$linegroup}{LineGroupNote} );
   #outtab ($skedadds{$skedname}{FullNote} , $lines{$linegroup}{LineGroupNote});

        outtab( $skedadds{$skedname}{UpcomingOrCurrentSkedID} );
# Right now the line group fields are specified in the first line of each line group. This isn't ideal but
# might be OK

        outtab(@specdaynames);

        outtab( @{ $skedref->{SPECDAYS} } );
        outtab( @{ $skedref->{NOTES} } );
        outtab( @{ $skedref->{ROUTES} } );

        for $tpcol ( 0 .. $#tp ) {
            outtab( @{ $skedref->{TIMES}[$tpcol] } );
        }

        close OUT;

    } ## tidy end: foreach my $skedname ( sort...)

} ## tidy end: foreach my $route ( sortbyline...)

print "\n";

$commonfolder->json_store_pretty( \%destination_code_of, $destcode_file );

sub outtab {
    my @fields = @_;
    foreach (@fields) {
        s/\n/ /g;
    }
    print OUT join( "\t", @fields, "\n" );
}

sub uniq {
    my %seen;
    return sortbyline grep { !$seen{$_}++ } @_;
}

sub bydaydirhash {
    ( my $aa = $a ) =~ s/.*?_//;    # minimal: it matches first _
    ( my $bb = $b ) =~ s/.*?_//;    # minimal: it matches first _
    $daydirhash{$aa} cmp $daydirhash{$bb};
}
