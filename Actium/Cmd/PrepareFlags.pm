# Actium/Cmd/PrepareFlags.pm

# Prepare artwork so that flags are built

# Subversion: $Id$

# legacy stage 4

package Actium::Cmd::PrepareFlags 0.003;

use Actium::Preamble;
use Actium::O::Files::ActiumFM;

const my $CONFIG_SECTION => 'ActiumFM';
const my %IS_A_CONFIG_KEY => ( db_user => 1, db_password => 1, db_name => 1 );

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $class = shift;

    my %params = @_;
    my $config = $params{config};

    my %db_config = $config->section($CONFIG_SECTION);

    foreach my $key ( keys %db_config ) {
        unless ( exists $IS_A_CONFIG_KEY{$key} ) {
            croak
              "Invalid key $key in section $CONFIG_SECTION in config file\n"
              . $config->filespec;
        }
    }

    my $actiumdb = Actium::O::Files::ActiumFM::->new(%db_config);
    
} ## tidy end: sub START

1;

__END__

(these are tabs)

% more 19.5x17-RW13 
53315   Washington Blvd. at Fremont Blvd., Fremont, near side, going west       210-c   215-a
55969   Washington Blvd. at Fremont Blvd., Fremont, far side, going east        210-a   215-c
