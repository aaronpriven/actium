package Actium::Cmd::Scratch 0.011;

use Actium::Preamble;
use Actium::O::2DArray;
use Actium::O::Folder;

# a place to test out small programs, in the Actium environment

sub START {

    my $aoa = Actium::O::2DArray->new_from_file(
        '/Users/apriven/Dropbox/flags_clusters.xlsx');

    my %cluster_of;
    my %stops_of;

    foreach \my @row(@$aoa) {
        my $stopid = $row[0];
        next if $stopid =~ /id/i;
        my $cluster = $row[5];

        push $stops_of{$cluster}->@*, $stopid;

    }

    foreach my $cluster ( keys %stops_of ) {
        my @stops = sort $stops_of{$cluster}->@*;
        if ( scalar(@stops) <= 20 ) {
            foreach my $stop (@stops) {
                $cluster_of{$stop} = $cluster;
            }
        }
        else {
            my $subcluster = 0;
            while (@stops) {
                $subcluster++;
                my @these20 = splice( @stops, 0, 20 );
                foreach my $stop (@these20) {
                    $cluster_of{$stop} = $cluster . $subcluster;
                }
            }

        }

    } ## tidy end: foreach my $cluster ( keys ...)

    my $fname  = '/Users/apriven/Desktop/SaveAsEPS/PrintSet5';
    my $folder = Actium::O::Folder->new($fname);

    my @files = $folder->glob_files('*.eps');

    my %new_of;

    foreach my $file (@files) {
        my $oname = u::filename($file);
        $oname =~ m/(\d{5})(Fr|Bk)/;
        my $stopid = $1;
        my $side   = $2;
        my $nname  = "$cluster_of{$stopid}-$stopid$side.eps";
        say "$fname/$oname, $fname/$nname";
        rename "$fname/$oname", "$fname/$nname";

    }

} ## tidy end: sub START

1;

__END__
