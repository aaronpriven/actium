package Actium::Cmd::HTMLTables 0.011;

use warnings;
use 5.014;

# Produces HTML tables that represent timetables.

use Actium::Constants;
use Actium::O::Sked;
use Actium::O::Sked::Timetable;

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
htmltables. Reads schedules and makes HTML tables out of them.
Also writes JSON structs, just for fun.
HELP

    return;
}

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my $signup   = $env->signup;

    my $html_folder = $signup->subfolder('html');

    my $prehistorics_folder = $signup->subfolder('skeds');

    my $loadcry = cry('Loading prehistoric schedules');

    my @skeds
      = Actium::O::Sked->load_prehistorics( $prehistorics_folder, $actiumdb );

    $loadcry->done;

    my $tttext_cry = cry('Creating timetable texts');

    my @tables;
    my $prev_linegroup = $EMPTY_STR;
    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;
        if ( $linegroup ne $prev_linegroup ) {
            $tttext_cry->over("$linegroup ");
            $prev_linegroup = $linegroup;
        }

        push @tables,
          Actium::O::Sked::Timetable->new_from_sked( $sked, $actiumdb );

    }

    $tttext_cry->done;

    my $htmlcry = cry('Writing HTML files');

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_html',
            EXTENSION => 'html',
            SUBFOLDER => 'html',
        }
    );

    $htmlcry->done;

    my $jsoncry = cry('Writing JSON struct files');

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_public_json',
            EXTENSION => 'json',
            SUBFOLDER => 'public_json',
        }
    );

    $jsoncry->done;

    return;

} ## tidy end: sub START

1;

__END__
