package Actium::Cmd::BARTSkeds 0.011;

# gets schedules from BART API and creates reports

use Actium;
use HTTP::Request;                   ### DEP ###
use LWP::UserAgent;                  ### DEP ###
use XML::Twig;                       ### DEP ###
use Date::Simple(qw/date today/);    ### DEP ###
use Actium::O::2DArray;

use DDP;

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

const my $API_KEY => 'MW9S-E7SL-26DU-VV8V';

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
    );

}

my ( %stations, %not_main_station, %abbr_of_station );
$not_main_station{$_} = 1 foreach qw/24TH NCON MONT PHIL BAYF /;

sub START {

    my $start_cry = cry('Building BART frequency tables');

    my ( $class,  $env )   = @_;
    my ( $oldest, @dates ) = get_dates( $env->option('date') );

    my $foldername = $env->option('folder') . '/BARTfreq_' . $oldest;
    unless ( -d $foldername ) {
        mkdir $foldername or die $!;
    }

    %stations        = get_stations( $dates[0] );
    %abbr_of_station = reverse %stations;

    my @station_abbrs = sort { $stations{$a} cmp $stations{$b} } keys %stations;

    my %fl_of;

    my $skeds_cry = cry('Getting station schedules and fares from BART');

    foreach my $station (@station_abbrs) {

        my %dest_is_used;

        $skeds_cry->text( "[$station:" . $stations{$station} . "]" );

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

        my @results;

        push @results, ["Departing from  $stations{$station} Station"];
        push @results,
          [ 'Train', 'Weekday', $EMPTY, 'Saturday', $EMPTY, 'Sunday' ];
        push @results, [ $EMPTY, qw/First Last First Last First Last/ ];

        foreach my $dest (
            sort {
                     $not_main_station{$a} <=> $not_main_station{$b}
                  || $stations{$a} cmp $stations{$b}
            }
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

        my $aoa  = Actium::O::2DArray->bless( \@results );
        my $file = "$foldername/$station.xlsx";
        $aoa->xlsx( output_file => $file );

        ### FARES

        \my %fare_to = get_fares( $station, $dates[0], \@station_abbrs );

        my $farefile = "$foldername/$station-fares.txt";

        my @farelines;
        foreach my $dest (@station_abbrs) {

            if ( $dest eq $station ) {
                push @farelines, [ $stations{$dest}, 'YAH', 'YAH' ];
            }
            else {
                push @farelines,
                  [ $stations{$dest}, $fare_to{$dest}, $fare_to{$dest} * 2 ];
            }

        }

        write_id_table( $farefile, $stations{$station}, \@farelines );

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

    my $twig = XML::Twig->new();
    #$twig->parse($stnsked_xml);
    my $result = $twig->safe_parse($stnsked_xml);
    unless ($result) {
        say "$stnsked_url\n\n$stnsked_xml\n\n";
        lastcry()->set_position(0);
        exit;

    }

    my @items = $twig->root->first_child('station')->children('item');

    my %items_of_dest;
    foreach my $item (@items) {
        my $line = $item->att('line');
        my $time = $item->att('origTime');
        $time =~ s/ ([AP])M/\l$1/;
        my $destname = $item->att('trainHeadStation');
        my $dest     = $abbr_of_station{$destname};
        push @{ $items_of_dest{$dest} },
          { dest => $dest, line => $line, time => $time };

        if ( $dest eq 'MLBR' and $line eq 'ROUTE 1' ) {
            push @{ $items_of_dest{'SFIA'} },
              { dest => 'SFIA', line => $line, time => $time };
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

sub stations_url {
    my $date = shift;
    my $url
      = "http://api.bart.gov/api/stn.aspx?cmd=stns&date=$date&key=$API_KEY";
    return $url;
}

sub get_url {

    my $url     = shift;
    my $request = HTTP::Request->new( GET => $url );
    my $ua      = LWP::UserAgent->new;
    my $body    = $ua->request($request)->content;

    return $body;

}

sub get_stations {

    my $date = shift;

    my %name_of;

    my $cry = cry('Getting station list from BART');

    my $stations_url = stations_url($date);

    my $stations_xml = get_url($stations_url);
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

    return %name_of;

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

        if ( not u::blessed($effective_date) ) {
            $date_obj = date($effective_date);
            die "Unrecognized date '$effective_date'" unless defined $date_obj;
        }

        if ( $date_obj < $today ) {
            my $cry = last_cry;
            $cry->text(
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

    return $oldest, @date_of{@DAYS};
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

