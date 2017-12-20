package Actium::Cmd::Timetables 0.012;

# Produces InDesign tag files that represent timetables.

use Actium;

use Actium::O::Sked::Collection;
use Actium::O::Sked;
use Actium::IDTables;

sub HELP {

    say <<'HELP' or die q{Can't write to STDOUT};
timetables. Reads schedules and makes timetables out of them.
HELP

    return;
}

sub OPTIONS {
    return qw/signup actiumdb/;
}

sub START {
    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;
    my $signup   = $env->signup;

    my $tabulae_folder    = $signup->ensure_subfolder('timetables');
    my $multipubtt_folder = $tabulae_folder->ensure_subfolder('pub-idtags');

    my $collection
      = Actium::O::Sked::Collection->load_storable( collection => 'final' );

    chdir( $signup->folder->stringify );

    my @skeds = $collection->skeds;

    @skeds = grep {
        my $linegroup = $_->linegroup;
        not( $linegroup =~ /^(?:BS[DHN]|4\d\d)/ )
    } @skeds;

    my @all_lines = map { $_->lines } @skeds;
    @all_lines = u::uniq u::sortbyline @all_lines;

    my ( $pubtt_contents_with_dates_r, $pubtimetables_r )
      = Actium::IDTables::get_pubtt_contents_with_dates( $actiumdb,
        \@all_lines );

    @skeds = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortable_id() ] } @skeds;

    my ( $alltables_r, $tables_of_r )
      = Actium::IDTables::create_timetable_texts( $actiumdb, @skeds );

    Actium::IDTables::output_all_tables( $tabulae_folder, $alltables_r );

    Actium::IDTables::output_a_pubtts( $multipubtt_folder,
        $pubtt_contents_with_dates_r, $pubtimetables_r, $tables_of_r );

    return;

} ## tidy end: sub START

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

