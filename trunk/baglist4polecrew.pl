#!/Activeperl/bin/perl

# bagtext

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use 5.010;

use warnings;
use strict;

@ARGV = qw(-s f10) if $ENV{RUNNING_UNDER_AFFRUS};

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Actium::Constants;
use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils ('natatime');

use POSIX qw(ceil);

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
baglist4polecrew makes a list of bags in order, for the pole crew
EOF

my $intro = 'baglist4polecrew -- makes bag list in route order for pole crew';

use Actium::Options;
use Actium::Signup;
my $signup = Actium::Signup->new();
chdir $signup->get_dir();

# retrieve data
my ( @stops, %stops );
FPread_simple( 'Stops.csv', \@stops, \%stops, 'PhoneID' );

my %compare;
open my $comp, '<', 'comparestops-x.txt';
while (<$comp>) {
    chomp;
    my ($type,       $stopid,  $desc,         $numadded, $added,
        $numremoved, $removed, $numunchanged, $unchanged
    ) = split(/\t/);

    $compare{$stopid} = {
        Type      => $type,
        Added     => $added,
        Removed   => $removed,
        Unchanged => $unchanged,
    };

}

close $comp;

my $stopcount = 0;
my $filecount = 0;

my ( %stops_of_type );

open my $crewlist, '>', 'baglist4polecrew.txt' or die $!;

say $crewlist "Route\tStop #\tStop Description\tAdded\tRemoved\tUnchanged";

foreach my $file (qw(baglist.txt baglist-add.txt baglist-rm.txt)) {

    open my $baglist, '<', $file;

    while (<$baglist>) {

        chomp;
        my ( $routedir, @thesestopids ) = split(/\t/);
        my $numstops = scalar @thesestopids;

        foreach my $i ( 0 .. $#thesestopids ) {

            my $thistext = '';

            $stopcount++;
            my $stopid = $thesestopids[$i];
            my $desc   = $stops{$stopid}{DescriptionF}
              || die "No description for $stopid";
            my $city = $stops{$stopid}{CityF} || die "No city for $stopid";

            print $crewlist "$routedir (", $i + 1, " of $numstops)";
            print $crewlist "\t$stopid";
            print $crewlist "\t$desc, $city";

            my $type  = $compare{$stopid}{Type}  || die "No type for $stopid";
            my $added = $compare{$stopid}{Added} || $EMPTY_STR;
            my $removed   = $compare{$stopid}{Removed}   || $EMPTY_STR;
            my $unchanged = $compare{$stopid}{Unchanged} || $EMPTY_STR;

            s/,/ /g foreach ($added,$removed,$unchanged);

            say $crewlist "\t" , join("\t" , $added, $removed, $unchanged);
 
        } ## <perltidy> end foreach my $i ( 0 .. $#thesestopids)

    } ## <perltidy> end while (<$baglist>)

    close $baglist;

} ## <perltidy> end foreach my $file (...)


