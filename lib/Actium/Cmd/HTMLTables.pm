package Actium::Cmd::HTMLTables 0.011;

use Actium::Preamble;

# Produces HTML tables that represent timetables.

use Actium::Constants;
use Actium::O::Sked;
use Actium::O::Sked::Collection;
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
    my $actiumdb       = $env->actiumdb;
    my $signup         = $env->signup;
    my $storablefolder = $signup->subfolder('s');

    my $html_folder = $signup->subfolder('html');

    my $collection
      = Actium::O::Sked::Collection->load_storable($storablefolder);

    my @skeds = $collection->skeds;

    my $tttext_cry = cry('Creating timetable texts');

    my @tables;
    my $prev_linegroup = $EMPTY_STR;

    my %htmls_of_linegroup;

    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;
        
        if ( $linegroup ne $prev_linegroup ) {
            $tttext_cry->over("$linegroup ");
            $prev_linegroup = $linegroup;
        }

        my $table
          = Actium::O::Sked::Timetable->new_from_sked( $sked, $actiumdb );
        push @tables, $table;
        push @{ $htmls_of_linegroup{$linegroup} }, $table->html_table;

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

    foreach my $linegroup ( u::sortbyline keys %htmls_of_linegroup ) {
        my $file = "$linegroup.html";
        my @htmls = @{ $htmls_of_linegroup{$linegroup} };
        my $html
          = '<head>'
          . '<link rel="stylesheet" type="text/css" href="timetable.css">'
          . '</head><body>'
          . join( '<br />', @htmls )
          . '</body>';

        $html_folder->slurp_write ( $html, $file );
    }

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
