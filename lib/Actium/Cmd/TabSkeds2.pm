package Actium::Cmd::TabSkeds2 0.011;

# This creates the "tab files" that are used in the
# Designtek-era web schedules

use Actium::Preamble;

use Actium::O::Sked::Collection;
use Actium::O::DestinationCode;

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb       = $env->actiumdb;
    my $signup         = $env->signup;
    my $basefolder     = $signup->base_obj;
    my $commonfolder   = $basefolder->subfolder('common');
    my $tabfolder      = $signup->subfolder('tabxchange');
    my $storablefolder = $signup->subfolder('s');

    my $collection
      = Actium::O::Sked::Collection->load_storable($storablefolder);
      
    my $dbh = $actiumdb->dbh;
    # just there to move the display forward from where it would
    # otherwise lazily be loaded...

    $collection->write_tabxchange(
        tabfolder    => $tabfolder,
        commonfolder => $commonfolder,
        actiumdb     => $actiumdb,
    );
} ## tidy end: sub START

1;

__END__
