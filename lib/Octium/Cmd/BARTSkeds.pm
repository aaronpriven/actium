package Octium::Cmd::BARTSkeds 0.015;

# gets schedules from BART API and creates reports

use Actium;
use Octium;
use HTTP::Request;                   ### DEP ###
use LWP::UserAgent;                  ### DEP ###
use XML::Twig;                       ### DEP ###
use Date::Simple(qw/date today/);    ### DEP ###
use Array::2D;
use JSON;
use Actium::Time;

use DDP;

use Octium::Text::InDesignTags;
const my $BART_MIDNIGHT_TIMENUM => 146;

const my $DEFAULT_KEY => 'MW9S-E7SL-26DU-VV8V';

const my @DAYS        => qw/12345 6 7/;
const my %DAY_DESC_OF => qw/12345 Weekday 6 Saturday 7 Sunday/;
# weekday, saturday, sunday; matches Octium::O::Days
#

use constant DO_FARES => 0;

sub HELP {
    my ( $class, $env ) = @_;
    my $command = $env->command;
    say "Gets schedules from BART API and creates reports..";
    return;
}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        {   spec        => 'date=s',
            description => 'Effective date of the new BART schedules. '
              . 'Must be in YYYY-MM-DD format (e.g., 2015-12-25) '
              . 'If not provided, defaults to today.',
        },

        {   spec            => 'folder=s',
            description     => 'Location where to save the files.',
            default         => '.',
            display_default => 1,
        },
        {   spec            => 'key=s',
            description     => 'Location where to save the files.',
            default         => $DEFAULT_KEY,
            envvar          => 'BART_KEY',
            config_section  => 'BART',
            config_key      => 'key',
            display_default => 1,
        },
    );

}

my ( %name_of_station, %not_main_station, %abbr_of_station );
$not_main_station{$_} = 1 foreach qw/24TH NCON MONT PHIL BAYF PITT CONC/;

my ( $api_key, $foldername );
my ( %first_of, %last_of, %dest_is_used );

sub START {

    my $start_cry = env->cry('Building BART frequency tables');

    my ( $class,  $env )       = @_;
    my ( $oldest, $date_of_r ) = get_dates( $env->option('date') );
    \my %date_of = $date_of_r;

    $api_key = $env->option('key');

    $foldername = $env->option('folder') . '/BARTfreq_' . $oldest;
    unless ( -d $foldername ) {
        mkdir $foldername or die $!;
    }

    get_stations( $date_of{ $DAYS[0] } );
    %abbr_of_station = reverse %name_of_station;
    my @station_abbrs = sort { $name_of_station{$a} cmp $name_of_station{$b} }
      keys %name_of_station;
    $not_main_station{$_} //= 0 foreach @station_abbrs;

    get_firstlast( \%date_of );

    output_excel();

}

sub output_excel {

    foreach my $station ( keys %first_of ) {

        my @results;

        push @results,
          [ "Departing from " . $name_of_station{$station} . " Station" ];
        push @results,
          [ 'Train', 'Weekday', $EMPTY, 'Saturday', $EMPTY, 'Sunday' ];
        push @results, [ $EMPTY, qw/First Last First Last First Last/ ];

        foreach my $dest (
            sort {
                     $not_main_station{$a} <=> $not_main_station{$b}
                  || $a cmp $b
            }
            keys %{ $dest_is_used{$station} }
          )
        {
            my @train;
            push @train, $name_of_station{$dest};

            foreach my $day (@DAYS) {
                my $first = $first_of{$station}{$day}{$dest};
                if ( defined $first ) {
                    $first = Actium::Time->from_num($first)->ap;
                }
                else { $first = '-'; }

                my $last = $last_of{$station}{$day}{$dest};
                if ( defined $last ) {
                    $last = Actium::Time->from_num($last)->ap;
                }
                else { $last = '-'; }

                push @train, $first, $last;
            }

            push @results, \@train;

        }

        my $aoa  = Array::2D->bless( \@results );
        my $file = "$foldername/$station.xlsx";
        $aoa->xlsx( output_file => $file );

    }

}

sub get_firstlast {
    \my %date_of = shift;

    foreach my $days ( sort keys %date_of ) {
        my $day_desc = $DAY_DESC_OF{$days};
        my $date     = $date_of{$days};

        my $routes_cry = env->cry(
            [ "Getting $day_desc routes", "Done getting $day_desc routes" ] );
        \my %routes = get_routes($date);
        my @routes = sort { $a <=> $b } keys %routes;

        $routes_cry->wail( join( " ", @routes ) );

        foreach my $route (@routes) {
            my $route_cry
              = env->cry( "Getting ", $routes{$route}{name}, " schedule" );

            \my @trains = get_sked( $date, $route );
            if ( not @trains ) {
                $route_cry->d_info( 'SKIP',
                    { closetext => "Skipping this route" } );
            }
            else {
                foreach my $train_r (@trains) {
                    \my @stops     = $train_r->{stop};
                    \my %finalstop = pop(@stops);

                    my $dest = $finalstop{'@station'};

                    foreach my $stop_r (@stops) {
                        my $station = $stop_r->{'@station'};
                        $dest_is_used{$station}{$dest} = 1;
                        my $time
                          = Actium::Time->from_str( $stop_r->{'@origTime'} );
                        my $timenum = $time->timenum;
                        $timenum += 1440 if $timenum < $BART_MIDNIGHT_TIMENUM;
                        if ( not exists $first_of{$station}{$days}{$dest}
                            or $first_of{$station}{$days}{$dest} > $timenum )
                        {
                            $first_of{$station}{$days}{$dest} = $timenum;
                        }
                        if ( not exists $last_of{$station}{$days}{$dest}
                            or $last_of{$station}{$days}{$dest} < $timenum )
                        {
                            $last_of{$station}{$days}{$dest} = $timenum;
                        }

                    }

                }
            }
        }

    }

}

sub get_sked {

    my ( $date, $route ) = @_;
    my $sked_url = sked_url( $date, $route );
    my ($sked_r) = get_from_url($sked_url);

    return [] if ( not exists $sked_r->{route}{train} );

    \my @trains = $sked_r->{route}{train};
    return \@trains;

}

sub routesked_url {
    my ( $date, $route ) = @_;
    my $url
      = "http://api.bart.gov/api/sched.aspx?cmd=routesched&route=$route&key=$api_key&json=y&date=$date";
    return $url;
}

sub get_routes {

    my $date = shift;
    my %name_of;
    my %routes;

    my $routes_url = routes_url($date);
    my ($root_r) = get_from_url($routes_url);

    my @route_structs = $root_r->{routes}{route}->@*;
    foreach \my %route_struct (@route_structs) {
        my $route_num = $route_struct{number};
        $routes{$route_num} = \%route_struct;
    }

    return \%routes;

}

sub routes_url {
    my $date = shift;
    my $url
      = "http://api.bart.gov/api/route.aspx?cmd=routes&date=$date&key=$api_key&json=y";
    return $url;
}

sub get_from_url {

    my $url     = shift;
    my $request = HTTP::Request->new( GET => $url );
    my $ua      = LWP::UserAgent->new;
    my $body    = $ua->request($request)->content;
    my $body_r  = decode_json($body);

    my $root_r = $body_r->{root};

    my $message = $root_r->{message};

    if ( defined Actium::reftype($message) ) {
        require Data::Dumper;
        local $Data::Dumper::Terse     = 1;
        local $Data::Dumper::Indent    = 0;
        local $Data::Dumper::Quotekeys = 0;
        local $Data::Dumper::Pair      = ' : ';
        $message = Data::Dumper::Dumper($message);
        Actium::wail("*** Message from BART: $message");
    }

    return $root_r;

}

sub sked_url {
    my $date  = shift;
    my $route = shift;
    my $url
      = 'http://api.bart.gov/api/sched.aspx?cmd=routesched'
      . "&date=$date&route=$route&key=$api_key&json=y";
    return $url;
}

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

        if ( not Actium::blessed($effective_date) ) {
            $date_obj = date($effective_date);
            die "Unrecognized date '$effective_date'"
              unless defined $date_obj;
        }

        if ( $date_obj < $today ) {
            my $cry = env->last_cry;
            $cry->wail(
                "Can't ask for BART schedules for past date $effective_date.");
            $cry->d_error;
            die;
        }

    }

    my $oldest = $date_obj;

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

    return $oldest, \%date_of;
}

sub stations_url {
    my $date = shift;
    my $url
      = "http://api.bart.gov/api/stn.aspx?cmd=stns&date=$date&key=$api_key&json=y";
    return $url;
}

sub get_stations {

    my $date = shift;

    my $cry = env->cry('Getting station list from BART');

    my $stations_url = stations_url($date);

    my $root_r = get_from_url($stations_url);

    my @station_structs = $root_r->{stations}{station}->@*;
    foreach \my %station_struct (@station_structs) {
        my $abbr = $station_struct{abbr};
        $name_of_station{$abbr} = $station_struct{name};
    }

    return \%name_of_station;

}

1;

__END__






    #%abbr_of_station = reverse %stations;

    #my @station_abbrs = sort { $stations{$a} cmp $stations{$b} } keys %stations;

    my %fl_of;

    my $skeds_cry = env->cry('Getting station schedules and fares from BART');

    foreach my $station (@station_abbrs) {

        my %dest_is_used;

        $skeds_cry->wail( "[$station:" . $stations{$station} . "]" );

        foreach my $idx ( 0 .. $#DAYS ) {
            my $date        = $dates[$idx];
            my $day         = $DAYS[$idx];
            my $firstlast_r = $fl_of{$station}{$day}
              = get_firstlast( $station, $date );

            foreach ( keys %$firstlast_r ) {
                $dest_is_used{$_} = 1;
                $not_main_station{$_} //= 0;
            }
        }
        #$skeds_cry->over($EMPTY);

           ### FARES

        if (DO_FARES) {

            \my %fare_to = get_fares( $station, $dates[0], \@station_abbrs );

            my $farefile = "$foldername/$station-fares.txt";

            my @farelines;
            foreach my $dest (@station_abbrs) {

                if ( $dest eq $station ) {
                    push @farelines, [ $stations{$dest}, 'YAH', 'YAH' ];
                }
                else {
                    push @farelines,
                      [ $stations{$dest}, $fare_to{$dest},
                        $fare_to{$dest} * 2 ];
                }

            }

            write_id_table( $farefile, $stations{$station}, \@farelines );

        }

    }

    $skeds_cry->done;
    $start_cry->done;

}

sub get_fares {

    my $origin = shift;
    my $date   = shift;
    \my @station_abbrs = shift;

    my %fare_to;

    foreach my $dest (@station_abbrs) {
        if ( $origin eq $dest ) {
            $fare_to{$dest} = 'YAH';
        }
        else {
            my $url = fare_url( $origin, $dest, $date );
            my $fare_xml = get_url($url);

            my $twig = XML::Twig->new();
            $twig->parse($fare_xml);

            my @fares = $twig->root->first_child('fares')->children('fare');
            #my $cash_elt = Actium::first { $_->att('class') eq 'cash' } @fares;
            #my $cash     = $cash_elt->att('amount');

            my $clipper_elt
              = Actium::first { $_->att('class') eq 'clipper' } @fares;
            my $clipper = $clipper_elt->att('amount');

            $fare_to{$dest} = $clipper;
        }

    }

    return \%fare_to;

}

sub get_firstlast {
    my ( $station, $date ) = @_;
    my $stnsked_url = stnsked_url( $station, $date );
    my $stnsked_xml = get_url($stnsked_url);

    say $stnsked_url;
    say $stnsked_xml;
    exit;

    my $twig = XML::Twig->new();
    #$twig->parse($stnsked_xml);
    my $result = $twig->safe_parse($stnsked_xml);
    unless ($result) {
        say "$stnsked_url\n\n$stnsked_xml\n\n";
        lastcry()->set_position(0);
        exit;

    }

    my @items = $twig->root->first_child('station')->children('item');

    #my %undefined_dests;

    my %items_of_dest;
    foreach my $item (@items) {
        my $line = $item->att('line');
        my $time = $item->att('origTime');
        $time =~ s/ ([AP])M/\l$1/;
        $time =~ s/^0//;
        my $destname = $item->att('trainHeadStation');

        #if ($destname eq 'SFO/Millbrae') {
        #   $destname = 'Millbrae';
        #}
        #my $dest = $abbr_of_station{$destname};
        #if (not defined $dest) {
        #   $undefined_dests{$destname} = 1;
        #   last;
        #   }
        push @{ $items_of_dest{$destname} }, { line => $line, time => $time };

        #if ( $dest eq 'MLBR' and $line eq 'ROUTE 1' ) {
        #    push @{ $items_of_dest{'SFIA'} },
        #      { dest => 'SFIA', line => $line, time => $time };
        #}

    }

    #if (%undefined_dests) {
    #    say (join "\n" , sort keys %undefined_dests);
    #    exit;
    #}

    my %fl_of;

    foreach my $dest ( keys %items_of_dest ) {
        my $first = $items_of_dest{$dest}[0]{time};
        my $last  = $items_of_dest{$dest}[-1]{time};

        #my $first = process_dest( %{ $items_of_dest{$dest}[0] } );
        #my $last  = process_dest( %{ $items_of_dest{$dest}[-1] } );

        $fl_of{$dest} = [ $first, $last ];
    }

    return \%fl_of;

}

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

sub fare_url {
    my $origin = shift;
    my $dest   = shift;
    my $date   = shift;
    my $url
      = "http://api.bart.gov/api/sched.aspx?cmd=fare&orig=$origin&dest=$dest&date=$date&key=$API_KEY";

}



sub write_id_table {

    my $filename     = shift;
    my $station_name = shift;
    \my @stationfares = shift;
    my $stationcount = scalar @stationfares;

    open my $fh, '>', $filename or die $!;

    print $fh $IDT->start;
    #print $fh $IDT->start, $IDT->hardreturn;

    print $fh '<ParaStyle:NormalParagraphStyle><TableStyle:FareTable>';
    print $fh "<TableStart:$stationcount,3:2:0<tCellDefaultCellType:Text>>";
    print $fh
'<ColStart:<tColAttrWidth:161.25>><ColStart:<tColAttrWidth:41.5>><ColStart:<tColAttrWidth:48.755>>';
    print $fh
'<RowStart:<tRowAttrHeight:35.75><tRowAttrMinRowSize:31>><CellStyle:\[None\]><StylePriority:0><CellStart:1,3>';
    print $fh "<ParaStyle:Faretable-Head>From $station_name to:",
      $IDT->hardreturn;

    print $fh
'<ParaStyle:Faretable-Head>(stations listed in alphabetical order)<CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><CellEnd:><RowEnd:><RowStart:<tRowAttrHeight:15><tRowAttrMinRowSize:3>><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-Head>Destination Station<CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-Head>One Way<CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-Head>Round Trip<CellEnd:><RowEnd:>';

    foreach \my @stationfare(@stationfares) {
        my ( $destname, $oneway, $round ) = @stationfare;

        $destname =~ s/International/Int\'l/;

        print $fh
'<RowStart:<tRowAttrHeight:17.2398681640625>><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-LeftCol>';
        print $fh $destname;

        if ( $oneway eq 'YAH' ) {
            print $fh
'<CellEnd:><CellStyle:Fare-YAH><StylePriority:1><CellStart:1,2><ParaStyle:Faretable-YAH>YOU ARE HERE<CellEnd:><CellStyle:Fare-YAH><StylePriority:1><CellStart:1,1><CellEnd:><RowEnd:>';

        }
        else {

            for ( $oneway, $round ) {
                $_ = sprintf( "%.2f", $_ );
            }

            print $fh
'<CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-Body>';
            print $fh $oneway;
            print $fh
'<CellEnd:><CellStyle:\[None\]><StylePriority:0><CellStart:1,1><ParaStyle:Faretable-Body>';
            print $fh $round;
            print $fh '<CellEnd:><RowEnd:>';

        }

    }

    print $fh '<TableEnd:>';

    close $fh or die $!;

}

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

