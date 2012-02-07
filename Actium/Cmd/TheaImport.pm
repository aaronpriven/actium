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
use constant { T_DAYS      => 0, T_VEHICLE => 1, T_TIMES  => 2 };

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

    my ($patterns_r, $patkeys_of_routedir_r) = get_patterns($theafolder);
    
    my ( $trip_of_tnum_r, $trips_of_patkey_r ) = get_trips($theafolder);
    
    my $union_patterns_r = make_union_patterns ($patterns_r);
    

}

sub make_union_patterns {
   my $patterns_r = shift;
   
 
}

sub output_debugging_patterns {
   my $signup = shift;
   my $patterns_r = shift;
 
   my $fh = $signup->open_write('thea_patterns.txt');
    
    foreach my $patkey (sort keys $patterns_r) {
     
        my $direction = $patterns_r->{$patkey}[P_DIRECTION];
        
        my @stopinfos = @{$patterns_r->{$patkey}[P_STOPS]};
        my @stops;
        foreach my $stopinfo (@stopinfos) {
             my $text = shift $stopinfo;
             if (scalar @$stopinfo) {
                 my $plc = shift $stopinfo;
                 my $seq = shift $stopinfo;
                 $text .= ":$plc:$seq";
             }
             push @stops, $text;
         
        }
        my $stops = join(" " , @stops);
        
        my %places = %{$patterns_r->{$patkey}[ P_PLACES() ]};
        my @places;
        
        foreach my $seq (sort { $a <=> $b } keys %places) {
            push @places, "$seq:$places{$seq}";
        }
        my $places = join(" " , @places);
         
        say $fh "$patkey\t$direction\n$stops\n$places\n";
        
    }
    
    close $fh or die "Can't close thea_patterns.txt: $OS_ERROR"; 
}

#my %is_a_valid_trip_type = { Regular => 1, Opportunity => 1 };

sub get_trips {
    my $theafolder = shift;
    emit 'Reading THEA trip files';

    my %trip_of_tnum;
    my %trips_of_patkey;

    my $trip_callback = sub {
        my $value_of_r = shift;

        return unless $value_of_r->{trp_is_in_service};
        #        return unless $is_a_valid_trip_type{ $value_of_r->{trp_type} };
        my $tnum = $value_of_r->{trp_int_number};

        my $patkey
          = $value_of_r->{trp_route} . ':' . $value_of_r->{trp_pattern};

        push @{ $trips_of_patkey{$patkey} }, $tnum;

        my $vehicle = $value_of_r->{trp_veh_groups};
        $trip_of_tnum{$tnum}[T_VEHICLE] = $vehicle if $vehicle;

        my $days_obj = make_days_obj( $value_of_r->{trp_blkng_day_digits},
            $value_of_r->{trp_event} );

        $trip_of_tnum{$tnum}[T_DAYS] = $days_obj;

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

    return \%trip_of_tnum, \%trips_of_patkey;

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
    my %patkeys_of_routedir;

    emit 'Reading THEA trippattern files';

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};
        my $tpat_route     = $value_of_r->{tpat_route};
        my $tpat_id        = $value_of_r->{tpat_id};
        my $tpat_direction = $value_of_r->{tpat_direction};
        my $routedir = "$tpat_route:$tpat_direction";

        my $key       = "$tpat_route:$tpat_id";
        
        push @{$patkeys_of_routedir{$routedir}} , $key;
        my $direction = $dircode_of_thea{$tpat_direction}
          or emit_text("Unknown direction: $tpat_direction");

        $patterns{$key}[ P_DIRECTION() ] = $direction;
        
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

        my $key = "$tpat_route:$tpat_id";

        return unless exists $patterns{$key};

        my @patinfo = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @patinfo, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$key}[ P_STOPS() ][$tpat_stp_rank] = \@patinfo;

        $patterns{$key}[ P_PLACES() ]{$tpat_stp_tp_sequence} = $tpat_stp_plc
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
    
    return \%patterns, \%patkeys_of_routedir;

} ## tidy end: sub get_patterns

__END__
