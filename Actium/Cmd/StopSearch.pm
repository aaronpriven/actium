# /Actium/Cmd/StopSearch.pm
#
# Command-line utility to search for stps

# Subversion: $Id$

package Actium::Cmd::StopSearch 0.005;

use Actium::Preamble;
use Actium::O::Folder;
use Actium::Util('tabulate');
use Actium::Cmd::Config::ActiumFM;
use Actium::Options(qw/set_option option/);
use Actium::Term;

sub HELP {
    say "Help not implemented.";
}

const my $CACHEFILENAME => 'actium-ss.cache';
const my $TIME_TO_LIVE  => 60 * 60;             # seconds

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    set_option( 'quiet', 1 );
    Actium::Term::_option_quiet(1);
    # sigh - need to rewrite Actium::Term

    my $folder   = Actium::O::Folder->new('/tmp');
    my $tempfile = $folder->make_filespec($CACHEFILENAME);
    
    my ( $of_511_id, $of_hastus_id ) = _get_stops($config_obj, $folder, $tempfile);

    my @args = @{ $params{argv} };

    if (@args) {
        foreach (@args) {
            my @rows = _search($_, $of_511_id, $of_hastus_id);
            _display(@rows);
        }

        return;
    }
    else {

        say 'Enter a stop ID, phone ID, or pattern to match.';
        say 'Enter a blank line to quit.';

        require Term::ReadLine;

        my $term = Term::ReadLine->new('st.pl');
        $term->ornaments(1);
        my $prompt = "st.pl >";
        while ( defined( $_ = $term->readline($prompt) ) ) {
            last if ( not $_ );
            my @rows = _search($_, $of_511_id, $of_hastus_id);
            _display(@rows);
            say '';
        }

        say "Exiting.";

    } ## tidy end: else [ if (@args) ]

} ## tidy end: sub START

const my @COLUMNS => (
    qw[
      h_stp_511_id
      h_stp_identifier
      c_description_full
      p_active
      ]
);

const my $STOPS_TABLE => 'Stops_Neue';

const my $DIVIDER => '  ';


sub _get_stops {
    my ($config_obj, $folder, $tempfile) = @_;
    
    my $do_reload = 1;
    my ($savedtime, $of_511_id, $of_hastus_id);

    if ( -e $tempfile ) {
        ( $savedtime, $of_511_id, $of_hastus_id )
          = @{ $folder->retrieve($CACHEFILENAME) };
        if ( $savedtime + $TIME_TO_LIVE >= time ) {
            $do_reload = 0;
        }

        #say $do_reload, " " , $savedtime, " " , time;
    }

    if ($do_reload) {

        my $actium_db = Actium::Cmd::Config::ActiumFM::actiumdb($config_obj);

        ( $of_511_id, $of_hastus_id ) = _get_stops_from_db($actium_db);
        $savedtime = time;
        $folder->store( [ $savedtime, $of_511_id, $of_hastus_id ],
            $CACHEFILENAME );
    }
    
    return $of_511_id, $of_hastus_id;
    
    
}

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

sub _search {
    my $argument = shift;
    my $of_511_id = shift;
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

} ## tidy end: sub _search

sub _display {

    my @rows = @_;

    foreach my $fields_r (@rows) {

        if ( not defined reftype($fields_r) ) {
            say "Unknown id $fields_r";
            next;
        }
        my $active = $fields_r->{p_active};

        print $fields_r->{h_stp_511_id}, $DIVIDER,
          $fields_r->{h_stp_identifier}, $DIVIDER;
        say( $active ? '' : "*", $fields_r->{c_description_full} );

    }

} ## tidy end: sub _display

1;

__END__



