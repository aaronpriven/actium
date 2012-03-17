# /Actium/Cmd/TheaImport.pm

# Takes the THEA files and imports them so Actium can use them.

# Subversion: $Id$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Cmd::TheaImport 0.001;

use Actium::Term ':all';
use Actium::Folders::Signup;
use Text::Trim;
use Actium::Files::TabDelimited 'read_tab_files';
use Actium::Sked::Days;

use Actium::Union('ordered_union_columns');

use Actium::Constants;

use English '-no_match_vars';

use constant { P_DIRECTION => 0, P_STOPS   => 1, P_PLACES => 2 };
use constant { T_DAYS      => 0, T_VEHICLE => 1, T_TIMES  => 2 , T_ROUTEID   => 3 };

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium theaimport -- read THEA files from Scheduling, creating
long-format Sked files for use by the rest of the Actium system,
as well as processing stops and places files for import.
HELP

    Actium::Term::output_usage();

}

my %dircode_of_thea = (
    Northbound       => 'NB',
    Southbound       => 'SB',
    Eastbound        => 'EB',
    Westbound        => 'WB',
    Counterclockwise => 'CC',
    Clockwise        => 'CW',
    '1'              => 'D1',
);

my %required_headers = (
    trippatterns => [
        qw<tpat_route tpat_id tpat_direction
          tpat_in_serv tpat_via tpat_trips_match>
    ],
    trippatternstops => [
        qw<stp_511_id tpat_stp_rank tpat_stp_plc tpat_stp_tp_sequence>,
        'item tpat_id', 'item tpat_route',
    ],
    trips => [
        qw<trp_int_number trp_route trp_pattern trp_is_in_service
          trp_blkng_day_digits trp_event>
    ],
    tripstops => [qw<trp_int_number tstp_position tstp_passing_time>],
);

sub START {

    my $signup     = Actium::Folders::Signup->new;
    my $theafolder = $signup->subfolder('thea');

    my ( $patterns_r, $pat_routeids_of_routedir_r, $upattern_of_r,
        $uindex_of_r ) = get_patterns($theafolder);

    #my $trips_of_routeid_r = get_trips($theafolder);
    my $trips_r = get_trips($theafolder);

#    output_debugging_patterns( $signup, $patterns_r,
#        $pat_routeids_of_routedir_r, $upattern_of_r, $uindex_of_r,
#        $trips_of_routeid_r ); # modify for $trips_r

    my $trips_of_routedir_r = assemble_trips( $patterns_r, $trips_r , $uindex_of_r );

} ## tidy end: sub START

sub assemble_trips {
    my $patterns_r         = shift;
    my $trips_r = shift;
    my $uindex_of_r        = shift;

    my %trips_of_routedir;
    
    foreach my $trip_r (@$trips_r) {
        my $newtrip_r = [];
        foreach my $field ( 0 .. $#{$trip_r} ) {
           next if $field == T_TIMES;
           my $newtrip_r->[$field] = $trip_r->[$field];
        }
        
        # adjust T_TIMES for columns
        
        my @times = @{$trip_r->[T_TIMES]};
        my $routeid = @{$trip_r->[T_ROUTEID]};
        my @newtimes;
        
        foreach my $oldcolumn ( 0 .. $#times ) {
            my $newcolumn = $uindex_of_r->{$routeid}[$oldcolumn];
            $newtimes[$newcolumn] = $times[$oldcolumn];
        }
        
        my $routedir = 'something';
        ... ; # figure out how to get routedir!
        
        push @{$trips_of_routedir{$routedir}} , $newtrip_r;
     
    }

    # so the idea here is to go through each trip, and create a new
    # trip struct in trips_of_routedir that has the various information,
    # putting the times in the correct column as in uindex_of_r
    
    ...;

    return \%trips_of_routedir;

}

sub output_debugging_patterns {
    my $signup                     = shift;
    my $patterns_r                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $upattern_of_r              = shift;
    my $uindex_of_r                = shift;
    my $trips_of_routeid_r         = shift;

    my $subfolder = $signup->subfolder('thea_debug');
    
    ...; # modify for array $trips_ar instead of hash $trips_of_routeid_r

    my $tfh = $subfolder->open_write('thea_trips.txt');

    foreach my $routeid ( keys $trips_of_routeid_r ) {
        say $tfh "\n$routeid";
        foreach my $trip ( @{ $trips_of_routeid_r->{$routeid} } ) {
            say $tfh join( "\t",
                $trip->[T_DAYS]->as_sortable,
                $trip->[T_VEHICLE], join( " ", @{ $trip->[T_TIMES] } ) );
        }
    }

    close $tfh or die "Can't close thea_trips.txt: $OS_ERROR";

    my $ufh = $subfolder->open_write('thea_upatterns.txt');

    foreach my $routedir ( keys $pat_routeids_of_routedir_r ) {
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };
        say $ufh "\n$routedir";
        say $ufh join( "\t", @{ $upattern_of_r->{$routedir} } );
        foreach my $routeid (@routeids) {
            say $ufh $routeid;
            say $ufh join( "\t", @{ $uindex_of_r->{$routeid} } );
        }
    }

    close $ufh or die "Can't close thea_upatterns.txt: $OS_ERROR";

    my $fh = $subfolder->open_write('thea_patterns.txt');

    foreach my $routeid ( sort keys $patterns_r ) {

        my $direction = $patterns_r->{$routeid}[P_DIRECTION];

        my @stopinfos = @{ $patterns_r->{$routeid}[P_STOPS] };
        my @stops;
        foreach my $stopinfo (@stopinfos) {
            my $text = shift $stopinfo;
            if ( scalar @$stopinfo ) {
                my $plc = shift $stopinfo;
                my $seq = shift $stopinfo;
                $text .= ":$plc:$seq";
            }
            push @stops, $text;

        }
        my $stops = join( " ", @stops );

        my %places = %{ $patterns_r->{$routeid}[ P_PLACES() ] };
        my @places;

        foreach my $seq ( sort { $a <=> $b } keys %places ) {
            push @places, "$seq:$places{$seq}";
        }
        my $places = join( " ", @places );

        say $fh "$routeid\t$direction\n$stops\n$places\n";

    } ## tidy end: foreach my $routeid ( sort ...)

    close $fh or die "Can't close thea_patterns.txt: $OS_ERROR";

} ## tidy end: sub output_debugging_patterns

#my %is_a_valid_trip_type = { Regular => 1, Opportunity => 1 };

sub get_trips {
    my $theafolder = shift;
    emit 'Reading THEA trip files';

    my %trip_of_tnum;
    my %tnums_of_routeid;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $routeid
          = $value_of_r->{trp_route} . ':' . $value_of_r->{trp_pattern};

        push @{ $tnums_of_routeid{$routeid} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $days_obj = make_days_obj( $value_of_r->{trp_blkng_day_digits},
            $value_of_r->{trp_event} );

        $trip_of_tnum{$tnum}[T_DAYS] = $days_obj;
        
        $trip_of_tnum{$tnum}[T_ROUTEID] = $routeid;

    };

    read_tab_files(
        {   globpatterns     => ['*trips.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trips'},
            callback         => $trip_callback,
        }
    );

    emit_done;

    emit 'Reading THEA trip stop (time) files';

    my $tripstops_callback = sub {
        my $value_of_r = shift;
        my $tnum       = $value_of_r->{trp_int_number};

        return unless exists $trip_of_tnum{$tnum};

        $trip_of_tnum{$tnum}[T_TIMES][ $value_of_r->{tstp_position} - 1 ]
          = $value_of_r->{tstp_passing_time};

    };

    read_tab_files(
        {   globpatterns     => ['*tripstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'tripstops'},
            callback         => $tripstops_callback,
        }
    );

    emit_done;
    
    my @trips;
    
        foreach my $tnum ( keys %trip_of_tnum ) {
            push @trips, $trip_of_tnum{$tnum};
        }
        
        return \@trips;

#    my %trips_of_routeid;
#    foreach my $routeid ( keys %tnums_of_routeid ) {
#        foreach my $tnum ( @{ $tnums_of_routeid{$routeid} } ) {
#            push @{ $trips_of_routeid{$routeid} }, $trip_of_tnum{$tnum};
#        }
#    }

#    return \%trips_of_routeid;

} ## tidy end: sub get_trips

sub make_days_obj {

    my $day_digits = shift;
    my $trp_event  = shift;

    $day_digits =~ s/0/7H/;
    # Thea uses 0 instead of 7 for Sunday, as Hastus Standard AVL did.
    $day_digits = join( '', sort ( split( //, $day_digits ) ) );
    # sort $theaday by characters - putting 7 at end

    my $schooldaycode
      = $trp_event eq 'SD' ? 'D'
      : $trp_event eq 'SH' ? 'H'
      :                      'B';

    return Actium::Sked::Days->new( $day_digits, $schooldaycode );
}

sub get_patterns {
    my $theafolder = shift;
    my %patterns;
    my %pat_routeids_of_routedir;

    emit 'Reading THEA trippattern files';

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};

        my $tpat_route = $value_of_r->{tpat_route};
        my $tpat_id    = $value_of_r->{tpat_id};

        my $routeid = "$tpat_route:$tpat_id";
        return if exists $patterns{$routeid};    # duplicate

        my $tpat_direction = $value_of_r->{tpat_direction};
        my $direction      = $dircode_of_thea{$tpat_direction};
        if ( not defined $direction ) {
            $direction = $tpat_direction;
            emit_text("Unknown direction: $tpat_direction");
        }
        my $routedir = "$tpat_route:$direction";

        push @{ $pat_routeids_of_routedir{$routedir} }, $routeid;

        $patterns{$routeid}[ P_DIRECTION() ] = $direction;

        return;

    };

    read_tab_files(
        {   globpatterns     => ['*trippatterns.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatterns'},
            callback         => $patfile_callback,
        }
    );

    emit_done;

    emit 'Reading THEA trippatternstops files';

    my $patstopfile_callback = sub {
        my $value_of_r = shift;

        my $tpat_route = $value_of_r->{'item tpat_route'};
        my $tpat_id    = $value_of_r->{'item tpat_id'};

        my $routeid = "$tpat_route:$tpat_id";

        return unless exists $patterns{$routeid};

        my @patinfo = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @patinfo, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$routeid}[ P_STOPS() ][$tpat_stp_rank] = \@patinfo;

        $patterns{$routeid}[ P_PLACES() ]{$tpat_stp_tp_sequence} = $tpat_stp_plc
          if $tpat_stp_tp_sequence;

    };

    read_tab_files(
        {   globpatterns     => ['*trippatternstops.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'trippatternstops'},
            callback         => $patstopfile_callback,
        }
    );

    emit_done;

    emit 'Making unified patterns for each direction';

    my ( %upattern_of, %uindex_of );

    foreach my $routedir ( keys %pat_routeids_of_routedir ) {

        my @routeids = @{ $pat_routeids_of_routedir{$routedir} };

        my @stop_sets;
        foreach my $routeid (@routeids) {
            my @set;
            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
                push @set, join( ':', @{$stop} );
            }
            push @stop_sets, \@set;
        }

        my %returned = ordered_union_columns(
            sets => \@stop_sets,
            ids  => \@routeids
        );

        $upattern_of{$routedir} = $returned{union};
        #$uindexes_of{$routedir} = $returned{columns_of};

        foreach my $routeid (@routeids) {
            $uindex_of{$routeid} = $returned{columns_of}{$routeid};
        }

    } ## tidy end: foreach my $routedir ( keys...)

    emit_done;

    return \%patterns, \%pat_routeids_of_routedir, \%upattern_of, \%uindex_of;

} ## tidy end: sub get_patterns

__END__
