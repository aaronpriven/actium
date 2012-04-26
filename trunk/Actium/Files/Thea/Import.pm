# /Actium/Files/Thea/Import.pm

# Takes the THEA files and imports them so Actium can use them.

# Subversion: $Id:$

# Legacy status: 4 (still in progress...)

use 5.014;
use warnings;

package Actium::Files::Thea::Import 0.002;

use Actium::Term ':all';
use Actium::Folders::Signup;
use Text::Trim;
use Actium::Files::TabDelimited 'read_tab_files';
use Actium::Time ('timenum');
use Actium::Sked::Days;
use Actium::Sked::Dir;
use Actium::Sked;
use Actium::Sorting::Line 'sortbyline';

use Actium::Files::Thea::Trips('thea_trips');

use Actium::Util (qw<jk jt doe>);

use Actium::Union('ordered_union_columns');

use Actium::Constants;

use English '-no_match_vars';
use List::Util (qw<min sum>);
use List::MoreUtils (qw<each_arrayref uniq>);

## no critic (ProhibitConstantPragma)
use constant { P_DIRECTION => 0, P_STOPS => 1, P_PLACES => 2 };
use constant {
    PL_DESCRIP   => 0,
    PL_REFERENCE => 1,
    PL_CITYCODE  => 2,
    PL_PLACE8    => 3,
};
## use critic

use Sub::Exporter -setup => { exports => ['thea_import'] };

my %dircode_of_thea = (
    Northbound       => 'NB',
    Southbound       => 'SB',
    Eastbound        => 'EB',
    Westbound        => 'WB',
    Counterclockwise => 'CC',
    Clockwise        => 'CW',
    A                => 'A',    # sigh
    B                => 'B',
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
    places => [
        qw[plc_identifier      plc_description
          plc_reference_place plc_district plc_number],
    ],
);

sub thea_import {

    my $signup     = shift;
    my $theafolder = shift;
    my ( $patterns_r, $pat_routeids_of_routedir_r, $upattern_of_r,
        $uindex_of_r ) = _get_patterns($theafolder);

    my $trips_of_skedid_r
      = thea_trips( $theafolder, $pat_routeids_of_routedir_r, $uindex_of_r );

    my $places_info_of_r = _load_places($theafolder);

    my @skeds
      = _make_skeds( $trips_of_skedid_r, $upattern_of_r, $places_info_of_r );

    _output_debugging_patterns( $signup, $patterns_r,
        $pat_routeids_of_routedir_r, $upattern_of_r, $uindex_of_r, \@skeds );

    return @skeds;

} ## tidy end: sub thea_import

sub _output_debugging_patterns {

    use autodie;
    ## no critic (RequireCheckedSyscalls)

    my $signup                     = shift;
    my $patterns_r                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $upattern_of_r              = shift;
    my $uindex_of_r                = shift;
    my $skeds_r                    = shift;

    my $debugfolder = $signup->subfolder('thea_debug');

    my $dumpfolder = $debugfolder->subfolder('dump');
    $dumpfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'dump',
        EXTENSION => 'dump',
    );
    
    Actium::Sked->write_prehistorics($skeds_r , $debugfolder);

    my $ufh = $debugfolder->open_write('thea_upatterns.txt');

    foreach my $routedir ( sortbyline keys $pat_routeids_of_routedir_r ) {
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };
        say $ufh "\n$routedir\t",
          join( "\t", @{ $upattern_of_r->{$routedir} } );
        foreach my $routeid (@routeids) {
            say $ufh '"', $routeid, '"';
            say $ufh join( "\t", @{ $uindex_of_r->{$routeid} } );
        }
    }

    close $ufh or die "Can't close thea_upatterns.txt: $OS_ERROR";

    my $fh = $debugfolder->open_write('thea_patterns.txt');

    foreach my $routeid ( sortbyline keys $patterns_r ) {

        my $direction = $patterns_r->{$routeid}[P_DIRECTION];

        my @stopinfos = @{ $patterns_r->{$routeid}[P_STOPS] };
        my @stops;
        foreach my $stopinfo (@stopinfos) {
            my $text = shift $stopinfo;
            if ( scalar @{$stopinfo} ) {
                my $plc = shift $stopinfo;
                my $seq = shift $stopinfo;
                $text .= ":$plc:$seq";
            }
            push @stops, $text;

        }
        my $stops = join( $SPACE, @stops );

        my %places = %{ $patterns_r->{$routeid}[ P_PLACES() ] };
        my @places;

        foreach my $seq ( sort { $a <=> $b } keys %places ) {
            push @places, "$seq:$places{$seq}";
        }
        my $places = join( $SPACE, @places );

        say $fh "$routeid\t$direction\n$stops\n$places\n";

    } ## tidy end: foreach my $routeid ( sort ...)

    close $fh or die "Can't close thea_patterns.txt: $OS_ERROR";

    return;

    ##use critic

} ## tidy end: sub _output_debugging_patterns

#my %is_a_valid_trip_type = { Regular => 1, Opportunity => 1 };

my $stop_tiebreaker = sub {
 
    # tiebreaks by using the average rank of the timepoints involved.

    my @lists = @_;
    my @avg_ranks;

    foreach my $i ( 0, 1 ) {
     
        my @ranks;
        foreach my $stop ( @{ $lists[$i] } ) {
            my ( $stopid, $placeid, $placerank ) = split( /:/s, $stop );
            if ( defined $placerank ) {
                push @ranks , $placerank;
            }
        }
        return 0 unless @ranks; 
        # if either list has no timepoints, return 0 indicating we can't break
        # the tie
        
        $avg_ranks[$i] = sum(@ranks) / @ranks;

    }

    return $avg_ranks[0] <=> $avg_ranks[1];

};

sub _get_patterns {
    my $theafolder = shift;
    my %patterns;
    my %pat_routeids_of_routedir;
    
    emit 'Loading and assembling THEA patterns';

    emit 'Reading THEA trippattern files';

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};
        # skip if this trip isn't in service, or if it has no active trips

        my $tpat_route = $value_of_r->{tpat_route};
        my $tpat_id    = $value_of_r->{tpat_id};

        my $routeid = $tpat_route . "_$tpat_id";
        return if exists $patterns{$routeid};    # duplicate

        my $tpat_direction = $value_of_r->{tpat_direction};
        my $direction      = $dircode_of_thea{$tpat_direction};
        if ( not defined $direction ) {
            $direction = $tpat_direction;
            emit_text("Unknown direction: $tpat_direction");
        }
        my $routedir = ${tpat_route} . "_$direction";

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

        my $routeid = $tpat_route . "_$tpat_id";

        return unless exists $patterns{$routeid};

        my @stop = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @stop, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$routeid}[P_STOPS][$tpat_stp_rank] = \@stop;

        $patterns{$routeid}[P_PLACES]{$tpat_stp_tp_sequence} = $tpat_stp_plc
          if $tpat_stp_tp_sequence;

        return;

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
        
        my %stop_set_of_routeid;
        foreach my $routeid (@routeids) {
            my @stop_set;
            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
                push @stop_set, join( ':', @{$stop} );
            }
            $stop_set_of_routeid{$routeid} = \@stop_set;
        }

        my %returned = ordered_union_columns(
            sethash    => \%stop_set_of_routeid,
            tiebreaker => $stop_tiebreaker,
        );

        $upattern_of{$routedir} = $returned{union};

        foreach my $routeid (@routeids) {
            $uindex_of{$routeid} = $returned{columns_of}{$routeid};
        }

    } ## tidy end: foreach my $routedir ( keys...)

    emit_done;
    
    emit_done;

    return \%patterns, \%pat_routeids_of_routedir, \%upattern_of, \%uindex_of;

} ## tidy end: sub _get_patterns

sub _load_places {
    my $theafolder = shift;
    my %place_info_of;

    emit 'Reading THEA place files';

    my $place_callback = sub {
        my $value_of_r   = shift;
        my $this_place_r = [];

        $this_place_r->[PL_DESCRIP]   = $value_of_r->{plc_description};
        $this_place_r->[PL_REFERENCE] = $value_of_r->{plc_reference_place};
        $this_place_r->[PL_CITYCODE]  = $value_of_r->{plc_district};
        $this_place_r->[PL_PLACE8]    = $value_of_r->{plc_number};
        $place_info_of{ $value_of_r->{plc_identifier} } = $this_place_r;

        return;
    };

    read_tab_files(
        {   globpatterns     => ['*places.txt'],
            folder           => $theafolder,
            required_headers => $required_headers{'places'},
            callback         => $place_callback,
        }
    );

    emit_done;

    return \%place_info_of;

} ## tidy end: sub _load_places

sub _make_skeds {
    my $trips_of_skedid_r = shift;
    my $upattern_of_r     = shift;
    my $places_r          = shift;

    my @skeds;
    
    emit "Making Actium::Sked objects";

    foreach my $skedid ( sortbyline keys $trips_of_skedid_r ) {
     
        emit_over $skedid;
        
        my ( $route, $dir, $days ) = split( /_/s, $skedid );
        my $routedir = "${route}_$dir";
        my $upattern = $upattern_of_r->{$routedir};
        my ( @stops, @place4s, @stopplaces );

        foreach my $stop ( @{$upattern} ) {
            my ( $stopid, $placeid, $placerank )
              = split( /:/s, $stop );
            push @stops, $stopid;
            push @stopplaces, doe($placeid);
            push @place4s, $placeid if $placeid;
        }

        my @place8s = map { $places_r->{$_}[PL_PLACE8] } @place4s;
        
        my $sked_attributes_r = {
            linegroup   => $route,         # TODO - real linegroup combinations
            place4_r    => \@place4s,
            place8_r    => \@place8s,
            stopid_r    => \@stops,
            stopplace_r => \@stopplaces,
            direction  => Actium::Sked::Dir->new($dir),
            days => Actium::Sked::Days->new($days),
            trip_r   => $trips_of_skedid_r->{$skedid},
        };

        my $sked = Actium::Sked->new($sked_attributes_r);
        $sked->build_placetimes_from_stoptimes;
        $sked->delete_blank_columns;
        push @skeds, $sked;

    } ## tidy end: foreach my $skedid ( keys $trips_of_skedid_r)
    
    emit_done;

    return @skeds;

} ## tidy end: sub _make_skeds

1;

__END__

BUGS AND LIMITATIONS

Still to do: linegroup combining
