# Actium/Cmd/HTMLTables.pm

# Produces HTML tables that represent timetables.

# legacy status: 4

use warnings;
use 5.014;

package Actium::Cmd::HTMLTables 0.010;

use Actium::Constants;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;
use Actium::Term;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup ('signup');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
htmltables. Reads schedules and makes HTML tables out of them.
Also writes JSON structs, just for fun.
HELP

    return;
}

sub OPTIONS {
    my ($class, $env) = @_;
    return (Actium::Cmd::Config::ActiumFM::OPTIONS($env), 
    Actium::Cmd::Config::Signup::options($env));
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
        my $signup = signup($env);
    

    my $html_folder = $signup->subfolder('html');

    my $prehistorics_folder = $signup->subfolder('skeds');

    emit 'Loading prehistoric schedules';

    my @skeds
      = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $actiumdb );

    emit_done;

    emit 'Creating timetable texts';

    my @tables;
    my $prev_linegroup = $EMPTY_STR;
    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;
        if ( $linegroup ne $prev_linegroup ) {
            emit_over "$linegroup ";
            $prev_linegroup = $linegroup;
        }

        push @tables,
          Actium::O::Sked::Timetable->new_from_sked( $sked, $actiumdb );

    }

    emit_done;

    emit 'Writing HTML files';

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_html',
            EXTENSION => 'html',
            SUBFOLDER => 'html',
        }
    );

    emit_done;

    emit 'Writing JSON struct files';

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_public_json',
            EXTENSION => 'json',
            SUBFOLDER => 'public_json',
        }
    );

    emit_done;

    return;

} ## tidy end: sub START

1;

__END__
