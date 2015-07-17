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
use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
htmltables. Reads schedules and makes HTML tables out of them.
Also writes JSON structs, just for fun.
HELP

    Actium::Term::output_usage();

    return;
}

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
    my $signup   = Actium::O::Folders::Signup->new;

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
