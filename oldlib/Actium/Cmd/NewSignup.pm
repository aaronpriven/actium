package Actium::Cmd::NewSignup 0.012;

# Prepares a new signup directory

use Actium;
use Actium::Import::Xhea;
use Archive::Zip;    ### DEP ###

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        'newsignup',
        {   spec        => 'xhea=s',
            description => 'ZIP file containing Xhea export ',
            fallback    => $EMPTY,
        },
    );
}

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium newsignup -- prepare new signup directories and extract files
HELP

    return;

}

sub START {

    my $class   = shift;
    my $env     = shift;
    my $xheazip = $env->option('xhea');

    my $signup_cry = cry( "Making new signup " . $env->option('signup') );

    my $signup = $env->signup;

    my $xhea_folder;
    if ($xheazip) {
        $xhea_folder = $signup->ensure_subfolder('xhea');

        my $xcry = cry("Extracting XHEA files");

        unless ( -e $xheazip ) {
            die "Can't find xhea zip file $xheazip";
        }

        my $zipobj = Archive::Zip->new($xheazip);

        foreach my $member ( $zipobj->members ) {
            next if $member->isDirectory;

            my $filename = u::filename( $member->fileName );

            $xcry->over( $filename . '...' );
            my $filespec = $xhea_folder->file($filename)->stringify;

            $member->extractToFileNamed("$filespec");

        }

        $xcry->over('');

        $xcry->done;

    }    ## tidy end: if ($xheazip)
    else {
        $xhea_folder = $signup->existing_subfolder('xhea');
    }

    my $sch_cal_folder = $signup->subfolder('sch_cal');
    my $gtfs_folder    = $signup->subfolder('gtfs');

    my %schcal_xhea_specs;

    #my $calendar_of_block_r;

    if ( $gtfs_folder->exists and $gtfs_folder->glob_files('*.txt') ) {

        my $suppcry = cry("Importing GTFS calendars");
        require Actium::Import::GTFS::TripCalendars;

        my $note_of_trip_r
          = Actium::Import::GTFS::TripCalendars::calendar_notes_of_trips(
            $signup);

        %schcal_xhea_specs = ( note_of_trip => $note_of_trip_r );

        $signup->folder->file('note_of_trip.dump')
          ->spew_utf8( Actium::dumpstr($note_of_trip_r) );

        $suppcry->done;

    }
    elsif ( $sch_cal_folder->exists and $sch_cal_folder->glob_files('*.xlsx') )
    {

        my $suppcry = cry("Importing supplementary calendars");
        require Actium::Import::Xhea::SuppCalendar;

        my $calendar_of_block_r
          = Actium::Import::Xhea::SuppCalendar::read_supp_calendars(
            $sch_cal_folder);

        %schcal_xhea_specs = ( sch_cal_data => $calendar_of_block_r );

        $suppcry->done;
    }

    if ( $xheazip or $xhea_folder->glob_files('*.xml') ) {

        my $impcry = cry("Importing xhea files");

        my $tab_folder = $xhea_folder->ensure_subfolder('tab');

        my %xhea_import_specs = (
            signup      => $signup,
            xhea_folder => $xhea_folder,
            tab_folder  => $tab_folder,
            %schcal_xhea_specs,
        );

        Actium::Import::Xhea::xhea_import(%xhea_import_specs);

        $impcry->done;

        my $hasicry     = cry("Creating HASI files from XHEA files");
        my $hasi_folder = $signup->ensure_subfolder('hasi');

        Actium::Import::Xhea::to_hasi( $tab_folder, $hasi_folder, $signup );

        $hasicry->done;

    }    ## tidy end: if ( $xheazip or $xhea_folder...)

    $signup_cry->done;

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

