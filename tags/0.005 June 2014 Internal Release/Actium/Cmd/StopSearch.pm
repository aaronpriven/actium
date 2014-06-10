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

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    
    my $actium_db = Actium::Cmd::Config::ActiumFM::actiumdb($config_obj);

    set_option( 'quiet', 1 );
    Actium::Term::_option_quiet(1);
    # sigh - need to rewrite Actium::Term

    my @args = @{ $params{argv} };

    if (@args) {
        foreach (@args) {
            my @rows = $actium_db->search_ss($_);
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
            my @rows = $actium_db->search_ss($_);
            _display(@rows);
            say '';
        }

        say "Exiting.";

    } ## tidy end: else [ if (@args) ]

} ## tidy end: sub START

const my $DIVIDER => '  ';

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

