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

use Actium::Files::Thea::Trips('thea_trips');

use Actium::Util (qw<jk jt>);

use Actium::Union('ordered_union_columns');

use Actium::Constants;

use English '-no_match_vars';
use List::Util ('min');
use List::MoreUtils (qw<each_arrayref>);

use constant { P_DIRECTION => 0, P_STOPS   => 1, P_PLACES => 2 };

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
);

sub thea_import {

    my $signup     = shift;
    my $theafolder = shift;
    my ( $patterns_r, $pat_routeids_of_routedir_r, $upattern_of_r,
        $uindex_of_r ) = _get_patterns($theafolder);
        
    my @trip_objs = thea_trips ( $theafolder, $pat_routeids_of_routedir_r, $uindex_of_r );

#    _output_debugging_patterns( $signup, $patterns_r,
#        $pat_routeids_of_routedir_r, $upattern_of_r, $uindex_of_r,
#        $trips_of_routeid_r, $trips_of_routedir_r );

} ## tidy end: sub thea_import

sub _output_debugging_patterns {
    my $signup                     = shift;
    my $patterns_r                 = shift;
    my $pat_routeids_of_routedir_r = shift;
    my $upattern_of_r              = shift;
    my $uindex_of_r                = shift;
    my $trips_of_routeid_r         = shift;
    my $trips_of_routedir_r        = shift;

    my $subfolder = $signup->subfolder('thea_debug');

#    my $rdfh = $subfolder->open_write('thea_unifiedtrips.txt');
#
#    foreach my $routedir ( sort keys $trips_of_routedir_r ) {
#
#        say $rdfh "\n$routedir";
#        foreach my $trip ( @{ $trips_of_routedir_r->{$routedir} } ) {
#
#            unless ( $trip->[T_TIMES] ) {
#                say $rdfh "INVALID TRIP";
#
#                next;
#            }
#
#            my @times = @{ $trip->[T_TIMES] };
#            foreach (@times) {
#                $_ = '--' unless defined;
#                $_ = sprintf( "%-5s", $_ );
#            }
#
#            say $rdfh join( "\t",
#                $trip->[T_DAYS]->as_sortable,
#                $trip->[T_VEHICLE], join( " ", @times ) );
#        }
#
#    } ## tidy end: foreach my $routedir ( sort...)
#
#    close $rdfh or die "Can't close thea_unifiedtrips.txt: $OS_ERROR";

#    my $tfh = $subfolder->open_write('thea_trips.txt');
#
#    foreach my $routeid ( keys $trips_of_routeid_r ) {
#        say $tfh "\n$routeid";
#        foreach my $trip ( @{ $trips_of_routeid_r->{$routeid} } ) {
#            say $tfh join( "\t",
#                $trip->[T_DAYS]->as_sortable,
#                $trip->[T_VEHICLE], join( " ", @{ $trip->[T_TIMES] } ) );
#        }
#    }
#
#    close $tfh or die "Can't close thea_trips.txt: $OS_ERROR";

    my $ufh = $subfolder->open_write('thea_upatterns.txt');

    foreach my $routedir ( keys $pat_routeids_of_routedir_r ) {
        my @routeids = @{ $pat_routeids_of_routedir_r->{$routedir} };
        say $ufh "\n$routedir\t",
          join( "\t", @{ $upattern_of_r->{$routedir} } );
        foreach my $routeid (@routeids) {
            say $ufh '"', $routeid, '"';
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

} ## tidy end: sub _output_debugging_patterns

#my %is_a_valid_trip_type = { Regular => 1, Opportunity => 1 };


sub _get_patterns {
    my $theafolder = shift;
    my %patterns;
    my %pat_routeids_of_routedir;

    emit 'Reading THEA trippattern files';

    my $patfile_callback = sub {

        my $value_of_r = shift;

        return unless $value_of_r->{tpat_in_serv};
        return unless $value_of_r->{tpat_trips_match};
        # skip if this trip isn't in service, or if it has no active trips

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

        my @stop = $value_of_r->{stp_511_id};

        my $tpat_stp_plc         = $value_of_r->{tpat_stp_plc};
        my $tpat_stp_tp_sequence = $value_of_r->{tpat_stp_tp_sequence};

        if ( $tpat_stp_plc or $tpat_stp_tp_sequence ) {
            push @stop, $tpat_stp_plc, $tpat_stp_tp_sequence;
        }

        my $tpat_stp_rank = $value_of_r->{tpat_stp_rank};

        $patterns{$routeid}[ P_STOPS() ][$tpat_stp_rank] = \@stop;

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

        my %stop_set_of_routeid;
        foreach my $routeid (@routeids) {
            my @set;
            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
                push @set, join( ':', @{$stop} );
            }
            $stop_set_of_routeid{$routeid} = \@set;
        }

        #        my @stop_sets;
        #        foreach my $routeid (@routeids) {
        #            my @set;
        #            foreach my $stop ( @{ $patterns{$routeid}[P_STOPS] } ) {
        #                push @set, join( ':', @{$stop} );
        #            }
        #            push @stop_sets, \@set;
        #        }

        my %returned = ordered_union_columns(
            sethash => \%stop_set_of_routeid,
            #            sets => \@stop_sets,
            #            ids  => \@routeids,
        );

        $upattern_of{$routedir} = $returned{union};

        foreach my $routeid (@routeids) {
            $uindex_of{$routeid} = $returned{columns_of}{$routeid};
        }

    } ## tidy end: foreach my $routedir ( keys...)

    emit_done;

    return \%patterns, \%pat_routeids_of_routedir, \%upattern_of, \%uindex_of;

} ## tidy end: sub _get_patterns

1;

__END__
