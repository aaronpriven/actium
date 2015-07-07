# /Actium/Cmd/StopSearch.pm
#
# Command-line utility to search for stps

# Subversion: $Id: StopSearch.pm 587 2015-04-06 17:03:31Z aaronpriven $

package Actium::Cmd::StopSearch 0.008;

use Actium::Preamble;
use Actium::O::Folder;
use Actium::Cmd::Config::ActiumFM;
use Actium::Options(qw/set_option/);
use Actium::Term;

sub OPTIONS {
    return ( [ 'tab', 'Uses tabs instead of spaces to separate text' ] )
      ;
}

sub HELP {
    say "Help not implemented.";
}

my $divider;

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};
    my $options_r = $params{options};

    my $actium_db = Actium::Cmd::Config::ActiumFM::actiumdb($config_obj);

    $divider = $options_r->{tab} ? "\t" : '  ';

    set_option( 'quiet', 1 );
    Actium::Term::_option_quiet(1);

    # sigh - need to rewrite Actium::Term

    my @args = @{ $params{argv} };
    
    # split arguments by commas as well as spaces
    # (assumes we're not searching for commas...)
    @args = map { split /,/ } @args;

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

    }    ## tidy end: else [ if (@args) ]

}    ## tidy end: sub START

sub _display {

    my @rows = @_;

    foreach my $fields_r (@rows) {

        if ( not defined reftype($fields_r) ) {
            say "Unknown id $fields_r";
            next;
        }
        my $active = $fields_r->{p_active};

        print $fields_r->{h_stp_511_id}, $divider,
          $fields_r->{h_stp_identifier}, $divider;
        say( $active ? '' : "*", $fields_r->{c_description_full} );

    }

}    ## tidy end: sub _display

1;

__END__
