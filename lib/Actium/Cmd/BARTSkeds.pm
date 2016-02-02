package Actium::Cmd::BARTSkeds 0.011;

# gets schedules from BART API and creates reports

use Actium::Preamble;
use HTTP::Request;                   ### DEP ###
use LWP::UserAgent;                  ### DEP ###
use XML::Twig;                       ### DEP ###
use Date::Simple(qw/date today/);    ### DEP ###
use Actium::O::2DArray;

const my $API_KEY => 'MW9S-E7SL-26DU-VV8V';
const my $ROUTE_URL =>
  "http://api.bart.gov/api/route.aspx?cmd=routes&key=$API_KEY";

const my $STATIONS_URL =>
  "http://api.bart.gov/api/stn.aspx?cmd=stns&key=$API_KEY";

const my @DAYS => qw/12345 6 7/;
# weekday, saturday, sunday; matches Actium::O::Days

sub HELP {
    my ( $class, $env ) = @_;
    my $command = $env->command;
    say "Gets schedules from BART API and creates reports..";
    return;
}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        [   'date=s',
            'Effective date of the new BART schedules. '
              . 'Must be in YYYY-MM-DD format (2015-12-25)'
              . 'If not provided, defaults to today.',
        ],
    );

}

sub START {

    my $start_cry = cry('Building BART frequency tables');

    my ( $class, $env ) = @_;
    my @dates = get_dates( $env->option('date') );

    \my %stations = get_stations();
    my @station_abbrs = sort keys %stations;

    my %fl_of;

    my $skeds_cry = cry('Getting station schedules from BART');

    foreach my $station (@station_abbrs) {

        my %dest_is_used;

        $skeds_cry->over($station);

        foreach my $idx ( 0 .. $#DAYS ) {
            my $date        = $dates[$idx];
            my $day         = $DAYS[$idx];
            my $firstlast_r = $fl_of{$station}{$day}
              = get_firstlast( $station, $date );
            $dest_is_used{$_} = 1 foreach keys %$firstlast_r;
        }
        $skeds_cry->over($EMPTY);

        my @results;

        push @results, ["Departing from  $stations{$station} Station"];
        push @results,
          [ 'Train', 'Weekday', $EMPTY, 'Saturday', $EMPTY, 'Sunday' ];
        push @results, [ $EMPTY, qw/First Last First Last First Last/ ];

        foreach my $dest (
            sort { $stations{$a} cmp $stations{$b} }
            keys %dest_is_used
          )
        {
            my @train;
            push @train, $stations{$dest};

            foreach my $day (@DAYS) {
                push @train, $fl_of{$station}{$day}{$dest}[0] // '—';
                push @train, $fl_of{$station}{$day}{$dest}[1] // '—';
            }

            push @results, \@train;

        }

        my $aoa = Actium::O::2DArray->bless( \@results );
        my $file
          = "/Volumes/Bireme/Connectivity-TIDs/bart_sked_output/$station.xlsx";
        $aoa->xlsx( output_file => $file );

    } ## tidy end: foreach my $station (@station_abbrs)

    $skeds_cry->done;
    $start_cry->done;

} ## tidy end: sub START

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
        $time =~ s/ ([AP])M/\l$1/;
        my $dest = $item->att('trainHeadStation');
        push @{ $items_of_dest{$dest} },
          { dest => $dest, line => $line, time => $time };

        if ( $dest eq 'MLBR' and $line eq 'ROUTE 1' ) {
            push @{ $items_of_dest{'SFIA'} },
              { dest => 'SFIA', line => $line, time => $time . '*' };
        }

    }

    my %fl_of;

    foreach my $dest ( keys %items_of_dest ) {
        my $first = $items_of_dest{$dest}[0]{time};
        my $last  = $items_of_dest{$dest}[-1]{time};

        #my $first = process_dest( %{ $items_of_dest{$dest}[0] } );
        #my $last  = process_dest( %{ $items_of_dest{$dest}[-1] } );

        $fl_of{$dest} = [ $first, $last ];
    }

    return \%fl_of;

} ## tidy end: sub get_firstlast

sub process_dest {

    my %train_info = @_;

    my $time = $train_info{time};
    if ( $train_info{dest} eq 'MLBR' and $train_info{line} eq 'ROUTE 1' ) {
        $time .= '*';
    }

    return $time;
}

sub sked_url {

    my $routenum = shift;
    my $date     = shift;
    my $url
      = "http://api.bart.gov/api/sched.aspx?cmd=routesched&route=$routenum&date=$date&key=$API_KEY";
    return $url;

}

sub stnsked_url {

    my $station = shift;
    my $date    = shift;
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

sub get_stations {

    my %name_of;

    my $cry          = cry('Getting station list from BART');
    my $stations_xml = get_url($STATIONS_URL);
    $cry->done;

    my $process_cry = cry('Processing XML data from BART');

    my $twig = XML::Twig->new();
    $twig->parse($stations_xml);
    my @station_elts
      = $twig->root->first_child('stations')->children('station');

    foreach my $station_elt (@station_elts) {
        my $abbr = $station_elt->first_child('abbr')->text;
        my $name = $station_elt->first_child('name')->text;
        $name_of{$abbr} = $name;
    }

    $process_cry->done;

    return \%name_of;

} ## tidy end: sub get_stations
####################
#### DATES
#### This gets the first weekday, Saturday, and Sunday, starting
#### with the specified date (or today)

sub get_dates {

    my $effective_date = shift;
    my $date_obj;
    my $today = today();

    if ( not $effective_date ) {
        $date_obj = $today;
    }
    else {

        if ( not u::blessed($effective_date) ) {
            $date_obj = date($effective_date);
            die "Unrecognized date '$effective_date'" unless defined $date_obj;
        }
        
        if ($date_obj < $today) {
            my $cry = last_cry;
            $cry->text(
             "Can't ask for BART schedules for past date $effective_date."
             );
             $cry->d_error;
             die;
        }

    }
    
    my %date_of;

    while ( scalar keys %date_of < 3 ) {

        my $day = $date_obj->day_of_week;
        if ( $day == 0 ) {
            $day = 7;
        }
        elsif ( $day != 6 ) {
            $day = '12345';
        }

        if ( not exists $date_of{$day} ) {
            $date_of{$day} = $date_obj->as_str('%m/%d/%Y');
        }

        $date_obj = $date_obj->next;
    }

    return @date_of{@DAYS};
} ## tidy end: sub get_dates

1;

__END__

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
