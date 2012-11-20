# Actium/Sked/Prehistoric.pm

# Role to allow reading and writing prehistoric Skedfile files to/from
# Sked objects

# This could just as easily be in the main Actium/Sked.pm file, but I decided
# it would be better to separate it out this way

# Subversion: $Id$

# legacy status 4

use warnings;
use 5.012;    # turns on features

package Actium::Sked::Prehistoric 0.001;

use Actium::Constants;
use Actium::Term;
use List::MoreUtils qw<uniq none>;

use Text::Trim;
use English '-no_match_vars';
use Actium::Util ('jt');
use Actium::Time ('timestr_sub');

use Moose::Role;

# comes from prehistorics
has 'place9_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { place9s => 'elements', },
);

sub prehistoric_id {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->dircode, $self->prehistoric_days ) );
}

sub prehistoric_days {
    my $self     = shift;
    my $days_obj = $self->days_obj;
    return $days_obj->for_prehistoric;
}

sub prehistoric_skedsfile {

    my $self = shift;

    my $outdata;
    open( my $out, '>', \$outdata );

    say $out $self->prehistoric_id;

    say $out "Note Definitions:\t";

    my @place9s;
    my %place9s_seen;

    foreach ( $self->place8s ) {
        my $place9 = $_;
        substr( $place9, 4, 0, $SPACE );
        $place9 =~ s/  / /g;

        if ( $place9s_seen{$place9} ) {

            $place9s_seen{$place9}++;
            $place9 .= '=' . $place9s_seen{$place9};
        }
        else {
            $place9s_seen{$place9} = 1;
        }

        push @place9s, $place9;
    }

    say $out jt( 'SPEC DAYS', 'NOTE', 'VT', 'RTE NUM', @place9s );

    my $timesub = timestr_sub( SEPARATOR => $EMPTY_STR );

    foreach my $trip ( $self->trips ) {
        my $times = $timesub->( $trip->placetimes );
        
        $times =~ s/\s+\z//;

        say $out jt( $trip->daysexceptions, $EMPTY_STR, $EMPTY_STR,
            $trip->line, $times );
    }

    close $out;

    return $outdata;

}    ## <perltidy> end sub prehistoric_skedsfile

sub load_prehistorics {

    my $class     = shift;
    my $folder    = shift;
    my $xml_db = shift;
    my @filespecs = @_;

    if (not defined $xml_db) {
       my $signup = $folder->signup_obj;
       $xml_db = $signup->load_xml;
    }
    
    $xml_db->ensure_loaded('Timepoints');
    
    my $xml_dbh = $xml_db->dbh;
    
    emit "Loading prehistoric schedules";

    my %tp4_of_tp8;

    {
        my $rows_r = $xml_dbh->selectall_arrayref(
            'SELECT Abbrev9 , Abbrev4 FROM Timepoints');
        foreach my $row_r ( @{$rows_r} ) {
            my ( $tp9, $tp4 ) = @{$row_r};
            my $tp8 = _tp9_to_tp8($tp9);
            $tp4_of_tp8{$tp8} = $tp4;
        }
    }

    my @files;
    if (@filespecs) {
        @files = map { $folder->glob_plain_files($_) } @filespecs;
    }
    else {
        @files = $folder->glob_plain_files;
    }

    my @skeds = map { $class->_new_from_prehistoric( $_, \%tp4_of_tp8 ) } @files;
    
    emit_over $EMPTY_STR;
    emit_done;
    
    return @skeds;

} ## tidy end: sub load_prehistorics

sub _new_from_prehistoric {

    my $class      = shift;
    my $filespec   = shift;
    my %tp4_of_tp8 = %{ +shift };

    my %spec;

    open my $skedsfh, '<', $filespec
      or die "Can't open $filespec for input";

    local ($_);

    $_ = <$skedsfh>;
    trim;

    my ( $linegroup, $direction, $days ) = split(/_/);
    $spec{linegroup} = $linegroup;
    $spec{direction} = $direction;
    
    state %seen_linegroup;
    if (not $seen_linegroup{$linegroup}) {
        emit_over $linegroup unless $seen_linegroup{$linegroup};
        $seen_linegroup{$linegroup} = 1;
    }

    $_ = <$skedsfh>;
    # Currently ignores "Note Definitions" line

    $_ = <$skedsfh>;
    trim;

    my @place9s;
    ( undef, undef, undef, undef, @place9s ) = split(/\t/) ;
   
    s/=[0-9]+\z//sx foreach @place9s;
    
    my @place8s = _tp9_to_tp8( @place9s) ;
    
    # the first four columns are always
    # "SPEC DAYS", "NOTE" , "VT" , and "RTE NUM"
    
    s/=.*// foreach @place8s; # get rid of =2, =3, etc.

    $spec{place9_r} = \@place9s;
    $spec{place8_r} = \@place8s;
    $spec{place4_r} = [ map { $tp4_of_tp8{$_} } @place8s ];

    my $last_tp_idx = $#place8s;

    my @trips;
    
    while (<$skedsfh>) {
        rtrim;

        next unless $_;    # skips blank lines

        my @fields = split(/\t/);

        my %tripspec;
        $tripspec{daysexceptions} = shift @fields;

        $tripspec{noteletter}  = shift @fields;
        $tripspec{vehicletype} = shift @fields;
        $tripspec{line}    = shift @fields;

        $#fields = $#place8s;

        $tripspec{placetime_r} = \@fields;

        # this means that the number of time columns will be the same as
        # the number timepoint columns -- discarding any extras and
        # padding out empty ones with undef values

        push @trips, Actium::Sked::Trip->new(%tripspec);

    } ## tidy end: while (<$skedsfh>)

    my @daysexceptions = uniq( map { $_->daysexceptions } @trips );
    
    if ( @daysexceptions == 1 and $linegroup !~ /\A 6 \d \d \z/sx) {
        given ( $daysexceptions[0] ) {
            when ('SD') {
                $days = Actium::Sked::Days->new( $days, 'D' );
            }
            when ('SH') {
                $days = Actium::Sked::Days->new( $days, 'H' );
            }
            when ( exists $DAYS_FROM_TRANSITINFO{$_} ) {
                $days = Actium::Sked::Days->new( $DAYS_FROM_TRANSITINFO{$_} );
            }
            default {
                $days = Actium::Sked::Days->new($days);
            }
        }
    }
    else {
        if ($linegroup =~ /\A 6 \d \d \z/sx) {
        $days = Actium::Sked::Days->new($days, 'D');
        } else {
        $days = Actium::Sked::Days->new($days);
        }
    }

    $spec{days} = $days;

    $spec{trip_r} = \@trips;

    close $skedsfh or die "Can't close $filespec for reading: $OS_ERROR";

    $class->new(%spec);

} ## tidy end: sub _new_from_prehistoric

sub write_prehistorics {

    my $class = shift;
    my $skeds_r = shift;
    my $signup  = shift;

    emit 'Preparing prehistoric sked files';

    my %prehistorics_of;

    emit 'Creating prehistoric file data';

    foreach my $sked ( @{$skeds_r} ) {
        my $group_dir = $sked->linegroup . q{_} . $sked->direction;
        my $days      = $sked->prehistoric_days();
        emit_over "${group_dir}_$days";
        $prehistorics_of{$group_dir}{$days} = $sked->prehistoric_skedsfile();
    }

    emit_done;

    # so now %{$prehistorics_of{$group_dir}} is a hash:
    # keys are days (WD, SU, SA)
    # and values are the full text of the prehistoric sked

    my %allprehistorics;

    my @comparisons
      = ( [qw/SA SU WE/], [qw/WD SA WA/], [qw/WD SU WU/], [qw/WD WE DA/], );

    emit 'Merging days';

    foreach my $group_dir ( sort keys %prehistorics_of ) {

        emit_over $group_dir;

        # merge days
        foreach my $comparison_r (@comparisons) {
            my ( $first_days, $second_days, $to ) = @{$comparison_r};

            next
              unless $prehistorics_of{$group_dir}{$first_days}
                  and $prehistorics_of{$group_dir}{$second_days};

            my $prefirst  = $prehistorics_of{$group_dir}{$first_days};
            my $presecond = $prehistorics_of{$group_dir}{$second_days};

            my ( $idfirst,  $bodyfirst )  = split( /\n/s, $prefirst,  2 );
            my ( $idsecond, $bodysecond ) = split( /\n/s, $presecond, 2 );

            if ( $bodyfirst eq $bodysecond ) {
                my $new = "${group_dir}_$to\n$bodyfirst";
                $prehistorics_of{$group_dir}{$to} = $new;
                delete $prehistorics_of{$group_dir}{$first_days};
                delete $prehistorics_of{$group_dir}{$second_days};
            }

        }    ## <perltidy> end foreach my $comparison_r (@comparisons)

        # copy to overall list

        foreach my $days ( keys %{ $prehistorics_of{$group_dir} } ) {
            $allprehistorics{"${group_dir}_$days"}
              = $prehistorics_of{$group_dir}{$days};
        }

    }    ## <perltidy> end foreach my $group_dir ( sort...)

    emit_done;

    $signup->subfolder('prehistoric')
      ->write_files_from_hash( \%allprehistorics, 'prehistoric', 'txt' );
    emit_done;

    return;

}    ## <perltidy> end sub write_prehistorics

## INTERNAL SUBROUTINES

sub _tp9_to_tp8 {

    my @places = @_;

  PLACE:
    foreach my $place (@places) {
        next PLACE unless $place =~ / /;
      CHARACTER:
        for my $i ( reverse 0 .. 4 ) {
            if ( substr( $place, $i, 1 ) eq $SPACE ) {
                substr( $place, $i, 1, $EMPTY_STR );
                last CHARACTER;
            }
        }
    }

    return wantarray ? @places : $places[0];

}

1;
