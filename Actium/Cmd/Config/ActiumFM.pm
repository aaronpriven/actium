# Actium/Cmd/Config/ActiumFM.pm

# Configuration and command-line options for ActiumFM

# legacy stage 4

package Actium::Cmd::Config::ActiumFM 0.010;

use Actium::Preamble;
use Actium::O::Files::ActiumFM;

use Sub::Exporter ( -setup => { exports => [qw(actiumdb)] } );    ### DEP ###

const my $CONFIG_SECTION => 'ActiumFM';
const my $DEFAULT_DBNAME => 'ActiumFM';

sub OPTIONS {

    return (

        [ 'db_user=s',     'User name to access Actium database' ],
        [ 'db_password=s', 'Password to access Actium database' ],
        [
            'db_name=s',
            'Name of the database in the ODBC driver. '
              . qq[The default is "$DEFAULT_DBNAME".],
            $DEFAULT_DBNAME,
        ]
    );

}

sub actiumdb {
    
    my $env = shift;
    
    my $config_obj = $env->config;

    my %config     = $config_obj->section($CONFIG_SECTION);

    my %params;
    foreach (qw(db_user db_password db_name)) {
        $params{$_} = $env->option($_) // $config{$_};
    }

    $params{db_user}
      //= Actium::Cmd::term_readline('User name to access Actium database:');

    $params{db_password}
      //= Actium::Cmd::term_readline( 'Password to access Actium database:',
        1 );

    $params{db_name} //= $DEFAULT_DBNAME;

    my $actium_db = Actium::O::Files::ActiumFM::->new(%params);
    return $actium_db;

} ## tidy end: sub actiumdb

1;

__END__
