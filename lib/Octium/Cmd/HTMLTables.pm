package Octium::Cmd::HTMLTables 0.012;

use Actium;
use Octium;

# Produces HTML tables that represent timetables.

use Octium::O::Sked;
use Octium::O::Sked::Collection;
use Octium::O::Sked::Timetable;

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

    my $actiumdb = env->actiumdb;
    my $signup   = env->signup;

    my $html_folder = $signup->subfolder('html');

    my $collection
      = Octium::O::Sked::Collection->load_storable( collection => 'final' );

    my @skeds = $collection->skeds;

    my $tttext_cry = env->cry('Creating timetable texts');

    my @tables;
    my $prev_linegroup = $EMPTY;

    my %htmls_of_linegroup;

    foreach my $sked (@skeds) {

        my $linegroup = $sked->linegroup;

        if ( $linegroup ne $prev_linegroup ) {
            $tttext_cry->over("$linegroup ");
            $prev_linegroup = $linegroup;
        }

        my $table
          = Octium::O::Sked::Timetable->new_from_sked( $sked, $actiumdb );
        push @tables, $table;
        push @{ $htmls_of_linegroup{$linegroup} }, $table->html_table;

    }

    $tttext_cry->done;

    my $htmlcry = env->cry('Writing HTML files');

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_html',
            EXTENSION => 'html',
            SUBFOLDER => 'html',
        }
    );

    foreach my $linegroup ( Actium::sortbyline keys %htmls_of_linegroup ) {
        my $file  = "$linegroup.html";
        my @htmls = @{ $htmls_of_linegroup{$linegroup} };
        my $html
          = "<!DOCTYPE html>\n"
          . '<head><link rel="stylesheet" type="text/css" href="timetable.css">'
          . '</head><body>'
          . join( '<br />', @htmls )
          . '</body>';

        $html_folder->slurp_write( $html, $file );
    }

    $htmlcry->done;

    my $jsoncry = env->cry('Writing JSON struct files');

    $signup->write_files_with_method(
        {   OBJECTS   => \@tables,
            METHOD    => 'as_public_json',
            EXTENSION => 'json',
            SUBFOLDER => 'public_json',
        }
    );

    $jsoncry->done;

    return;

}    ## tidy end: sub START

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

