#!/ActivePerl/bin/perl

# polelist

# legacy status: 2

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

@ARGV = qw(-s sp10) if $ENV{RUNNING_UNDER_AFFRUS};

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Actium::Constants;
use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils ('natatime');

use POSIX qw(ceil);

use IDTags;

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
bagtext makes the text for the bags.
EOF

my $intro = 'crewlist -- makes lists of crew actions';

my %height_of = (
    numbers => 3,
    AL      => 13.375,
    AS      => 15.175,
    RL      => 13.375,
    CL      => 17.875,
    margin  => 0.75,
    RS      => 16.375,
);

use Actium::Options;
use Actium::Folders::Signup;
my $signup = Actium::Folders::Signup->new();
chdir $signup->path();

# retrieve data
my ( @stops, %stops );
FPread_simple( 'Stops.csv', \@stops, \%stops, 'stop_id_1' );
my ( @signs, %signs );
FPread( 'Signs.csv', \@signs, \%signs, 'UNIQUEID' );

my %output_dispatch = (
    AL => \&al_output,
    RL => \&rl_output,
    CL => \&cl_output,
    AS => \&as_output,
    RS => \&rs_output,
);

my $stopcount = 0;
my $filecount = 0;

my ( %texts_of, %texts_of_type );

my %seen_length;

my $date = 'March' . IDTags::nbsp() . '28';

my %type_of = qw<polelist.txt C > ;#baglist-add.txt AS baglist-rm.txt RS>;

my %quantity_of;

foreach my $file (keys %type_of) {

    print "processing $file...\n";

    my $type = $type_of{$file};
    open my $crewlist, '>' , "polelist-$type.txt" or die $!;
    open my $baglist, '<', $file or die $!;

    print $crewlist "InstallRoute\tInstallNum\tInstallOrder\tStopID\tPhoneID\tDescription\tCity\tSignID\tSignType\n";

    while (<$baglist>) {

        chomp;
        my ( $routedir, @thesestopids ) = split(/\t/);
        my $numstops = scalar @thesestopids;

        foreach my $i ( 0 .. $#thesestopids ) {

            my $stopid = $thesestopids[$i];

            my $desc   = $stops{$stopid}{DescriptionF}
              || die "No description for $stopid";
            my $city = $stops{$stopid}{CityF} || die "No city for $stopid";
            my $phoneid = $stops{$stopid}{PhoneID}
              || die "No phone for $stopid";

            foreach my $sign (@{$signs{$stopid}}) {

               my $status = lc ($sign->{Status});

               next unless ( $status eq 'ok' or $status eq 'needs update');

               print $crewlist "$routedir\t", $i + 1, "\t" , $i + 1 , " of $numstops";
               print $crewlist "\t$stopid\t$phoneid\t$desc\t$city\t";

               print $crewlist $sign->{SignID} , "\t" , $sign->{SignType} , "\n";

            }

            my $outtype = $type;

            if ( $type eq 'AL' or $type eq 'RL' or $type eq 'CL' ) {
                $outtype = 'C';
                my $route = substr($routedir,0,index($routedir,'-'));

            }

        } ## <perltidy> end foreach my $i ( 0 .. $#thesestopids)

    } ## <perltidy> end while (<$baglist>)

    close $baglist;
    close $crewlist;

} ## <perltidy> end foreach my $file (...)



