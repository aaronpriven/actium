# /Actium/Cmd/MRCopy.pm

# Command-line access to copylatest in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRCopy 0.002;

use 5.014;
use warnings;

use Actium::MapRepository (':all');
use Actium::O::Folder;

use Actium::Options(qw<add_option option>);
use Actium::Term ('output_usage');

use English '-no_match_vars';

add_option(
    'repository=s',
    'Location of repository in file system',
    '/Volumes/Bireme/Maps/Repository'
);
add_option(
    'activemapfile=s',
    'Name of file containing list of active maps. '
      . 'Must be located in the repository.',
    'active_maps.txt',
);
add_option( 'web!',
    'Create web files of maps (on by default; turn off with -no-web)', 1 );
add_option( 'fullnames!',
    'Copy files with their full names ' . 
    '(on by default; turn off with -no-fullnames)',
    1, );
add_option(
    'linesnames!',
    'Copy files using the lines and token as the name only '
      . '(on by default; turn off with -no-linesnames)',
    1,
);
add_option( 'verbose!',
    'Display detailed information on each file copied or rasterized.', 0 );

add_option( 'webfolder|wf=s',
        'Folder where web files will be created. '
      . 'Default is "_web" in the repository' );
add_option( 'linesfolder|lf=s',
        'Folder to where lines and tokens files will be copied. '
      . 'Default is "_linesnames" in the repository' );
add_option( 'fullfolder|ff=s',
        'Folder to where full names will be copied. '
      . 'Default is "_fullnames" in the repository' );

sub HELP {
 
    my $usage = <<'EOF';
actium.pl mr_copy (options) ...

  The mr_copy command is used for determining what the latest version
  of each map in the map repository is, and making copies of it. 
  See the document "The Actium Maps Repository: Quick Start Guide"
  for more information.
EOF

    say $usage 
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my $repository = Actium::O::Folder->new( option('repository') );

    my $webfolder = option_folder( $repository, 'web', 'webfolder', '_web' );
    my $fullfolder
      = option_folder( $repository, 'fullnames', 'fullfolder', '_fullnames' );
    my $linesfolder = option_folder( $repository, 'linesnames', 'linesfolder',
        '_linesnames' );

    copylatest(
        repository      => $repository,
        fullname        => $fullfolder,
        linesname       => $linesfolder,
        web             => $webfolder,
        verbose         => option('verbose'),
        active_map_file => option('activemapfile'),
    );
    return;

} ## tidy end: sub START

sub option_folder {
    my ( $repository, $option, $folderoption, $default ) = @_;

    my $folder_obj;

    if ( option($option) ) {
        if ( option($folderoption) ) {
            $folder_obj = Actium::O::Folder->new( option($folderoption) );
        }
        else {
            $folder_obj = $repository->subfolder($default);
        }
    }

    return $folder_obj;

}

1;

__END__


=head1 NAME

Actium::Cmd::MRCopy - Copy latest map files from the map repository

=head1 VERSION

This documentation refers to Actium::Cmd::MRCopy version 0.001

=head1 USAGE

From a shell:

 actium.pl mr_copy <options>
 
=head1 DESCRIPTION

The Actium::Cmd::MRCopy module provides a command-line interface to the 
B<copylatest> routine of Actium::MapRepository. It expects to be run by
actium.pl. See the documentation to actium.pl for more information on the START
and HELP methods.

mr_copy goes through the map repository and copies the very latest 
active map of each line and type to a separate folder. 

Detailed documentation on the maps repository and how to use mr_copy 
can be found in the separate documents, "The Actium Maps Repository: 
Quick Start Guide" and "The Actium Maps Repository: Extended Usage 
and Technical Detail." 

=head1 COMMAND-LINE OPTIONS

The mr_copy program has several options that can be used on the command line. These should be placed after mr_import:

 actium.pl mr_copy -no-web
 
 actium.pl mr_copy -repository /Users/me/MyRepository
 
 actium.pl mr_copy -help
 
However, in practice only a few of them are actually useful.

=over

=item -activemapfile

This allows the user to use a different file than active_maps.txt
as the list of active maps. The file must, however, still be located
in the repository folder.

=item -fullfolder

This allows you to change where copies with the full names are made. The default is "_fullnames" in the repository. Use "-fullfolder" to specify another location on the file system:

 actium.pl mr_copy -fullfolder 
    /Volumes/SHARE$/District Public Share/Apriven/CurrentLineMaps
    
"fullfolder" can be abbreviated "ff".

=item -fullnames

This option will copy the files into the "_fullnames" folder (or
whatever the  fullfolder option specifies). This is on by default.
To suppress copying of full names files, use "-no-fullnames" on the
command line.

=item -linesfolder

This allows you to change where copies with just the line names are
made. The default is "_linesnames" in the repository. Use "-linesfolder"
to specify another location on the file system:

 actium.pl mr_copy -linesfolder 
    /Volumes/SHARE$/District Public Share/Apriven/LineMapsNoDates
    
"linesfolder" can be abbreviated "lf".

=item -fullnames

This option will copy the files into the "_linesnames" folder (or
whatever the  linesfolder option specifies). This is on by default.
To suppress copying of lines names files, use "-no-linesnames" on
the command line.

=item -repository

The repository is currently located at "/Volume/Bireme/Maps/Repository". To use another repository, specify its full path here. 

=item -web

This option will copy the files into the "_web" folder (or whatever the -webfolder option specifies), and create the JPEG files. This is on by default. To suppress copying and rasterization of web files, use "-no-web" on the command line. 

Rasterization takes the longest time so I suspect "-no-web" is the most likely option to be used.

=item -webfolder

This allows you to change where web files made. The default is "_web" in the repository. Use "-webfolder" to specify another location on the file system:

 actium.pl mr_copy -webfolder 
    /Volumes/SHARE$/District Public Share/Apriven/MapsForWeb
    
=item -quiet, -verbose, and -progress

These three options tell the program how much detail to display on screen. 

"-quiet" eliminates all display except text that describes why the program quit unexpectedly. 

"-verbose" displays on the screen a message indicating the names of each map copied or rasterized.

"-progress" produces a running indication of which lines' maps are being 
processed, when " verbose" is not in effect. This is on by default; use "-no-progress" to turn it off.

=back

=head1 DIAGNOSTICS

Actium::Cmd::MRCopy issues no error messages on its own, but see its
dependencies below.

=head1 DEPENDENCIES

=over

=item * Perl 5.14

=item * Actium::MapRepository

=item * Actium::O::Folder

=item * Actium::Options

=item * Actium::Term 

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2012

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.

