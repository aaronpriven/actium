package Actium::Cmd::BARTSkeds 0.011;

# gets schedules from BART API and creates reports

use Actium::Preamble;
use HTTP::Request;                   ### DEP ###
use LWP::UserAgent;                  ### DEP ###
use XML::Twig;                       ### DEP ###
use Date::Simple(qw/date today/);    ### DEP ###

const my $API_KEY => 'MW9S-E7SL-26DU-VV8V';
const my $ROUTE_URL =>
  "http://api.bart.gov/api/route.aspx?cmd=routes&key=$API_KEY";

const my $STATIONS_URL =>
  "http://api.bart.gov/api/stn.aspx?cmd=stns&key=$API_KEY";

sub HELP {
    my ( $class, $env ) = @_;
    my $command = $env->command;
    say "Gets schedules from BART API and creates reports..";
    return;
}

sub START {

    my ( $class, $env ) = @_;

    my @stations = get_stations();
    
    my %fl_of;

    foreach my $station (@stations) {
       
       foreach my $day (qw/12345 6 7/) {
           $fl_of{$station}{$day} = get_firstlast($station, get_date($day));
       }
        
    }
    
    say u::dumpstr(\%fl_of);
    
    exit;

    #\my %routename_of = get_routes();
    #
    #foreach my $routenum ( sort { $a <=> $b } keys %routename_of ) {
    #    say "$routenum => $routename_of{$routenum}";
    #}

    my %first_of;
    my %last_of;

    for my $routenum (1) {    # ( keys %routename_of )
        for my $days ('1') {    # ( qw/1 6 7/)

            my $date = get_date($days);
            get_firstlast( $routenum, $date );

        }
    }

} ## tidy end: sub START

{
    my %date_of;

    my $date = today();
    while ( scalar keys %date_of < 3 ) {

        my $day = $date->day_of_week;
        if ( $day == 0 ) {
            $day = 7;
        }
        elsif ( $day != 6 ) {
            $day = '12345';
        }

        if ( not exists $date_of{$day} ) {
            $date_of{$day} = $date->as_str('%m/%d/%Y');
        }

        $date = $date->next;
    }

    sub get_date {

        my $thisday = shift;
        die 'Invalid day' unless $thisday =~ /^[1-7]$/ or $thisday eq '12345';
        $thisday = '12345' if $thisday =~ /^[1-5]$/;

        return $date_of{$thisday};

    }

    sub dates {
        return @date_of{qw/12345 6 7/};
    }

}

sub get_firstlast {
    my ( $station, $date ) = @_;
    my $stnsked_xml = get_url( stnsked_url( $station, $date ) );
    
   my $twig = XML::Twig->new();
    $twig->parse($stnsked_xml);

    my @items = $twig->root->first_child('station')->children('item');
    
    my %items_of_dest;
    foreach my $item (@items) {
        my $line = $item->att('line');
        my $time = $item->att('origTime');
        my $dest = $item->att('trainHeadStation');
        push @{$items_of_dest{$dest}} , { line => $line, time => $time };
    }
    
    my %fl_of;
    
    foreach my $dest (keys %items_of_dest) {
        my $first = $items_of_dest{$dest}[0]{time};
        my $last = $items_of_dest{$dest}[-1]{time};
        $fl_of{$dest} = [$first, $last];
    }
    
    return \%fl_of;
    
}
    
    

#sub get_firstlast {
#
#    my ( $routenum, $date ) = @_;
#    my $sked_xml = get_url( sked_url( $routenum, $date ) );
#
#    my $twig = XML::Twig->new();
#    $twig->parse($sked_xml);
#
#    my @trains = $twig->root->first_child('route')->children;
#
#    foreach my $train (@trains) {
#        my @stops = $train->children('stop');
#        foreach my $stop (@stops) {
#            next if not defined $stop->att('origTime');
#            my $station = $stop->att('station');
#            my $time    = $stop->att('origTime');
#            say "$station:$time";
#        }
#    }
#
#} ## tidy end: sub get_firstlast

sub sked_url {

    my $routenum = shift;
    my $date     = shift;
    my $url
      = "http://api.bart.gov/api/sched.aspx?cmd=routesched&route=$routenum&date=$date&key=$API_KEY";
    return $url;

}

sub stnsked_url {

    my $station = shift;
    my $date     = shift;
    my $url
      = "http://api.bart.gov/api/sched.aspx?cmd=stnsched&orig=$station&key=$API_KEY&l=1&date=$date";

    return $url;

}

sub get_routes {

    my $routes_xml = get_url($ROUTE_URL);

    my $twig = XML::Twig->new();
    $twig->parse($routes_xml);
    my @routes = $twig->root->first_child('routes')->children('route');
    my %routename_of;

    foreach (@routes) {
        my $name   = $_->first_child('name')->text;
        my $number = $_->first_child('number')->text;
        $routename_of{$number} = $name;
    }

    return \%routename_of;

}

sub get_url {

    my $url     = shift;
    my $request = HTTP::Request->new( GET => $url );
    my $ua      = LWP::UserAgent->new;
    my $body    = $ua->request($request)->content;

    return $body;

}

{

    my %name_of;

    sub get_stations {

        if ( not scalar keys %name_of ) {
            my $stations_xml = get_url($STATIONS_URL);

            my $twig = XML::Twig->new();
            $twig->parse($stations_xml);
            my @station_elts
              = $twig->root->first_child('stations')->children('station');

            foreach my $station_elt (@station_elts) {
                my $abbr = $station_elt->first_child('abbr')->text;
                my $name = $station_elt->first_child('name')->text;
                $name_of{$abbr} = $name;
            }

        }

        return sort keys %name_of;

    } ## tidy end: sub get_stations

}

1;
