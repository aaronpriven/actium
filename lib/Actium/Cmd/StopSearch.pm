# /Actium/Cmd/StopSearch.pm
#
# Command-line utility to search for stps

package Actium::Cmd::StopSearch 0.010;

use Actium::Preamble;
use Actium::O::Folder;
use Actium::Cmd::Config::ActiumFM('actiumdb');

sub OPTIONS {

    my ($class, $env) = @_;

    return ( Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        [ 'tab', 'Uses tabs instead of spaces to separate text' ] );
}

my $divider;
const my $DEFAULT_DIVIDER => $SPACE x 2;

sub START {

    my ( $class, $env ) = @_;

    $env->be_quiet();

    my $actiumdb = actiumdb($env);

    $divider = $env->option('tab') ? "\t" : $DEFAULT_DIVIDER;

    my @args = $env->argv;

    # split arguments by commas as well as spaces
    # (assumes we're not searching for commas...)
    @args = map { split /,/s } @args;

    if (@args) {
        foreach (@args) {
            my @rows = $actiumdb->search_ss($_);
            _display(@rows);
        }

        return;
    }
    else {

        say 'Enter a stop ID, phone ID, or pattern to match.';
        say 'Enter a blank line to quit.';

        require Term::ReadLine;    ### DEP ###

        my $term = Term::ReadLine->new('st.pl');
        $term->ornaments(1);
        my $prompt = 'st.pl >';
        while ( defined( $_ = $term->readline($prompt) ) ) {
            last if ( not $_ );
            my @rows = $actiumdb->search_ss($_);
            _display(@rows);
            say $EMPTY_STR;
        }

        say 'Exiting.';

    } ## tidy end: else [ if (@args) ]

    return;

} ## tidy end: sub START

sub _display {

    my @rows = @_;

    foreach my $fields_r (@rows) {

        if ( not defined u::reftype($fields_r) ) {
            say "Unknown id $fields_r";
            next;
        }
        my $active = $fields_r->{p_active};

        print $fields_r->{h_stp_511_id}, $divider,
          $fields_r->{h_stp_identifier}, $divider;
        say( $active ? $EMPTY_STR : '*', $fields_r->{c_description_full} );
    }

    return;
} ## tidy end: sub _display

1;

__END__