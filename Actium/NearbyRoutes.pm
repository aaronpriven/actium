#!/ActivePerl/bin/perl 

use 5.012;

package Actium::NearbyRoutes 0.001;

use Geo::Coder::US;

use strict;
use warnings;

use Actium::Folders::Signup;
use Actium::Sorting::Line ('sortbyline');
use Actium::Term;
use Math::Trig qw(deg2rad pi great_circle_distance asin acos);

use List::MoreUtils('uniq');

#my $dbname = shift
#    or die "Usage: $0 <path_to.db>\n";

my $dbname      = 'geocoder.db';
my $addressname = 'addresses.txt';

my $threshold = 5280 / 3;    # 1/3 mile

sub START {

    my $signup     = Actium::Folders::Signup->new();
    my $dbfilespec = $signup->make_filespec($dbname);

    Geo::Coder::US->set_db($dbfilespec);

    my $stops_r = load_stops($signup);

    open my $in, '<', $signup->make_filespec($addressname);

    while (<$in>) {

        chomp;

        if (/Billing Address/i or (not /\w/)) {
           say $_;
           next;
        }
        
        my $name = '' ;
        my $address;
        
        if (/\t/) {

            my @portions = split( /\t/, $_ );
            s/\A"// foreach @portions;
            s/"\z// foreach @portions;
            $name     = shift @portions;
            $address        = join( ", ", @portions );
        }
        else { $address = $_ }

        chomp;
        my @res = Geo::Coder::US->geocode($address);
        warn( ( scalar @res ) . " results for $address" ) if @res != 1;
        foreach my $this_res (@res) {
            my $lat  = $this_res->{'lat'};
            my $long = $this_res->{'long'};
            
            print "$_\t";
            
            my $nearby = find_nearby( $stops_r, $lat, $long );
            
            $nearby = "No stop found" unless defined $nearby;

            say $nearby;

        }

    } ## tidy end: while (<$in>)

} ## tidy end: sub START

sub load_stops {

    my $signup = shift;

    my $xml_db = $signup->load_xml;
    $xml_db->ensure_loaded('Stops');

    emit 'Getting stop descriptions from FileMaker export';
    my $dbh = $xml_db->dbh;

    my $stops_rows_r
      = $dbh->selectall_arrayref(
"SELECT PhoneID, ud_stop_Lat, ud_stop_Long, ud_stp_Flagroute FROM Stops WHERE In_last_update IS 'Yes'"
      );

    emit_done;

    return $stops_rows_r;

} ## tidy end: sub load_stops

sub find_nearby {

    my $stops_r = shift;
    my $lat     = shift;
    my $long    = shift;

    my @nearby_stops;

    foreach my $stop_r ( @{$stops_r} ) {
        my ( $phoneid, $stoplat, $stoplong, $flagroute ) = @{$stop_r};
        my $distance = distance( $lat, $long, $stoplat, $stoplong );
        next if $distance > $threshold;
        push @nearby_stops, [ $distance, @{$stop_r} ] ;

    }
    
    if (not @nearby_stops) {
       return undef ;
    } 

    @nearby_stops = sort { $a->[0] <=> $b->[0] } @nearby_stops;

    my @lines;

    while ( @lines < 6 and @nearby_stops ) {

        my $stop = shift @nearby_stops;
        my @theselines = split( /\s/, $stop->[4] );
        @theselines = grep ( !/[68]\d\d|BS[DH]/, @theselines );
        @lines = uniq( @lines, @theselines );

    }

    return join( " ", sortbyline @lines );

} ## tidy end: sub find_nearby

my $radius = 3956.6 * 5280;    # feet

sub distance {

    # Haversine, from http://www.perlmonks.org/?node_id=150054
    my ( $lat1, $long1, $lat2, $long2 ) = @_;

    my $dlong = deg2rad($long1) - deg2rad($long2);
    my $dlat  = deg2rad($lat1) - deg2rad($lat2);

    my $a = sin( $dlat / 2 )**2
      + cos( deg2rad($lat1) ) * cos( deg2rad($lat2) ) * sin( $dlong / 2 )**2;
    my $c = 2 * ( asin( sqrt($a) ) );
    my $dist = $radius * $c;

    return $dist;    # returns in meters

}

