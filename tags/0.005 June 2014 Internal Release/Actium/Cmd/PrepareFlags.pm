# Actium/Cmd/PrepareFlags.pm

# Prepare artwork so that flags are built

# Subversion: $Id$

# legacy stage 4

package Actium::Cmd::PrepareFlags 0.004;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Flags;
use Actium::O::Folders::Signup;
use Actium::Term;

sub HELP {
    say "Help not implemented.";
}

sub START {
    
    emit 'Creating flag assignments from Actium FileMaker database';

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my $signup = Actium::O::Folders::Signup->new();

    my $actiumdb = actiumdb($config_obj);

    my $tabbed = Actium::Flags::flag_assignments_tabbed ($actiumdb);
    
    unless ($tabbed) {
        emit_error;
        return;
    }
    
    $signup->slurp_write ($tabbed, 'flag_assignments.txt');

    emit_done;

}

1;

__END__
