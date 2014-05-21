# Actium/Files/FM_StopCache.pm
# Caches Actium_DB stop data for use in quicker-loading programs

# Subversion: $Id$

# Legacy status: 4

package Actium::Files::FM_StopCache;

use Actium::Preamble;

use Sub::Exporter -setup => { exports => [qw(get_stops search)] };

const my @COLUMNS => (
    qw[
      h_stp_511_id
      h_stp_identifier
      c_description_full
      p_active
      h_loca_longitude
      h_loca_latitude
      ]
);

const my $STOPS_TABLE => 'Stops_Neue';

const my $TIME_TO_LIVE  => 60 * 60;             # seconds

sub get_stops {
    my ( $actium_db, $folder, $tempfile ) = @_;

    my $do_reload = 1;
    my ( $savedtime, $of_511_id, $of_hastus_id );

    if ( -e $tempfile ) {
        ( $savedtime, $of_511_id, $of_hastus_id )
          = @{ $folder->retrieve($tempfile) };
        if ( $savedtime + $TIME_TO_LIVE >= time ) {
            $do_reload = 0;
        }

        #say $do_reload, " " , $savedtime, " " , time;
    }

    if ($do_reload) {

        ( $of_511_id, $of_hastus_id ) = _get_stops_from_db($actium_db);
        $savedtime = time;
        $folder->store( [ $savedtime, $of_511_id, $of_hastus_id ],
            $tempfile );
    }

    return $of_511_id, $of_hastus_id;

} ## tidy end: sub get_stops

sub _get_stops_from_db {
    my $actium_db = shift;
    my $dbh       = $actium_db->dbh;

    my ( $of_511_id, $of_hastus_id );

    $of_511_id = $actium_db->all_in_columns_key( $STOPS_TABLE, @COLUMNS );

    foreach my $row ( values %{$of_511_id} ) {
        $of_hastus_id->{ $row->{h_stp_identifier} } = $row;
    }

    return ( $of_511_id, $of_hastus_id );

}

sub search {
    my $argument     = shift;
    my $of_511_id    = shift;
    my $of_hastus_id = shift;

    if (/\A\d{5}\z/) {
        return ( $of_511_id->{$argument} // $argument );
    }

    if (/\A\d{6}\z/) {
        return ( $of_hastus_id->{"0$argument"} // $argument );
    }

    if (/\A\d{7,8}\z/) {
        return ( $of_hastus_id->{"$argument"} // $argument );
    }

    my @rows;

    foreach my $fields_r ( values %{$of_511_id} ) {

        my $desc = $fields_r->{c_description_full};

        $argument =~ s{/}{.*}g;
        # slash is easier to type, doesn't need to be quoted,
        # not a regexp char normally, not usually found in descriptions
        push @rows, $fields_r
          if $desc =~ m{$argument}i;

    }

    return @rows;

} ## tidy end: sub search

1;

__END__
