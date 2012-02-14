# /Actium/Cmd/MRCopy.pm

# Command-line access to copylatest in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRCopy 0.001;

use 5.014;
use warnings;

use Actium::MapRepository (':all');
use Actium::Folder;

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
    say 'actium.pl mr_copy (options) ...'
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my $repository = Actium::Folder->new( option('repository') );

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
            $folder_obj = Actium::Folder->new( option($folderoption) );
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

This documentation refers to Actium::MRCopy version 0.001

=head1 USAGE

From a shell:

 actium.pl mr_copy
 
=head1 DESCRIPTION

The Actium::MRCopy module implements the mr_copy subcommand of actium.pl.
The program goes through the map repository and copies the very latest 
active map of each line and type to a separate folder. 

Detailed documentation for users is in the separate document, "The Actium
Maps Repository."

See the separate document "About the Maps Repository" for background 
information on the maps repository and how the files are stored.

The program goes through each folder of the repository and determines which
EPS (Encapsulated Postscript) file has the latest date and version.  It then
copies all files of that date and version (whatever the extension) to the 
destination folders.

There are three separate destination folders:

=over 

=item fullnames

Files in this folder have the full name of the map as they are called in the
repository. This has the version and date information, so for example, files
in this folder might be

 1_1R_801-2012_01-TT1.eps
 1_1R_801-2012_01-TT1.pdf
 7-2012_02-TT1.eps
 7-2012_02-TT1.pdf
 11-2010_08-TT2.eps
 11-2010_08-TT2.pdf
 
=item linesnames

Files in this folder have only the lines (and token, if present) as their 
names. So, for example, the files described in fullnames would be present 
here as

 1_1R_801.eps
 1_1R_801.pdf
 7.eps
 7.pdf
 11.eps
 11.pdf

=item web

This folder 

=head1 COMMAND-LINE OPTIONS

=over

=item -repository

This is the location of the repository in the file system. Defaults to 
"/Volumes/Bireme/Maps/Repository."

=item Other Options

See L<OPTIONS in Actium::Term|Actium::Term/OPTIONS>


A complete list of every available option with which the application
can be invoked, explaining wha each does and listing any restrictions
or interactions.

If the application has no options, this section may be omitted.


=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

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

