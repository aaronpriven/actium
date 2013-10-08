# /Actium/Cmd/MRImport.pm

# Command-line access to import_to_repository in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRImport 0.001;

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
add_option( 'web!',
    'Create web files of maps (on by default; turn off with -no-web)', 1 );
add_option( 'webfolder|wf=s',
        'Folder where web files will be created. '
      . 'Default is "web" in the folder where the maps already are' );
add_option(
    'move|mv!',
    'Move files into repository instead of copying '
      . '(on by default; turn off with -no-move)',
    1
);

add_option( 'verbose!',
    'Display detailed information on each file copied or rasterized.', 0 );

#add_option( 'rename!',
#        'Rename the maps to have the same filenames as those '
#      . 'in the repository. Has no effect when moving instead of copying.' );
# never implemented

sub HELP {
 
    my $usage = <<'EOF';
actium.pl mr_import _folder_ _folder_...

  The mr_import command is used for importing maps into the map repository.
  See the document "The Actium Maps Repository: Quick Start Guide"
  for more information.
EOF

    say $usage 
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my $class = shift;

    my @importfolders = @_;
    unless (@importfolders) {
        $class->HELP();
        return;
    }
    my $web           = option('web');
    my $webfolder_opt = option('webfolder');
    my $verbose       = option('verbose');

    my $specified_webfolder_obj;

    if ( $web and $webfolder_opt ) {
        $specified_webfolder_obj = Actium::O::Folder->new( option('webfolder') );
    }

    my $repository_opt = option('repository');

    my $repository = Actium::O::Folder->new(
        {   folderlist => $repository_opt,
            must_exist => 1,
        }
    );
    foreach my $folderspec (@importfolders) {

        # import to repository
        my $importfolder = Actium::O::Folder->new(
            {   folderlist => $folderspec,
                must_exist => 1,
            }
        );
        my @imported_files = import_to_repository(
            repository   => $repository,
            move         => option('move'),
            verbose      => $verbose,
            importfolder => $importfolder
        );

        # make web files

        if ($web) {
            my $webfolder_obj;

            if ($specified_webfolder_obj) {
                $webfolder_obj = $specified_webfolder_obj;
            }
            else {
                $webfolder_obj = $importfolder->subfolder('web');
            }

            make_web_maps(
                web_folder     => $webfolder_obj,
                files          => \@imported_files,
                path_to_remove => $repository->path,
                verbose        => $verbose,
            );

        }

    } ## tidy end: foreach my $folderspec (@importfolders)

    return;

} ## tidy end: sub START

1;

__END__

=head1 NAME

Actium::Cmd::MRImport - Copy map files into the map repository

=head1 VERSION

This documentation refers to Actium::Cmd::MRImport version 0.001

=head1 USAGE

From a shell:

 actium.pl mr_import <options> <folder>
 
=head1 DESCRIPTION

The Actium::Cmd::MRCopy module provides a command-line interface to the 
B<import_to_repository>  and B<make_web_maps> routines of 
Actium::MapRepository. It expects to be run by
actium.pl. See the documentation to actium.pl for more information on the START
and HELP methods.

mr_import takes one or more folders where maps may exist. First, it checks the names of each of those files, and if it can, puts it into the proper name style for the repository. Second, it copies the files to the repository. Third, it creates versions of the PDF files for the web.

Detailed documentation on the maps repository and how to use mr_import
can be found in the separate documents, "The Actium Maps Repository: 
Quick Start Guide" and "The Actium Maps Repository: Extended Usage 
and Technical Detail." 

=head1 USAGE

The mr_import program takes files and copies them into the repository. You run it by entering the following into the Terminal (shell):

 actium.pl mr_import /Name/Of/A/Folder 
 
or, for more than one folder,

 actium.pl mr_import /Folder1 /Folder2 /AndSoOn
 
One of the most usual ways is to "cd" to the appropriate folder in the Terminal and simply enter (note the period):

 actium.pl mr_import .

=head1 COMMAND-LINE OPTIONS

The mr_import program has several options that can be used on the command line. These should be placed after mr_import:

 actium.pl mr_import -no-web _new
 
 actium.pl mr_import -repository /Users/myname/MyRepository _new
 
A full list of options can be seen by typing

actium.pl mr_import -help

However, in practice only a few of them are actually useful.

=over

=item -move

This option moves, rather than copies, the files into the repository. They will be removed from the specified folder once they are copied successfully. 

This option is on by default. To copy instead of moving, so the maps will remain in the folder you specify, enter "-no-move" on the command line. "move" can be abbreviated as "mv"

=item -repository

The repository is currently located at "/Volume/Bireme/Maps/Repository". To use another repository, specify its full path here. 

=item -web

This option will create a folder called "web" underneath the folder you specify, and create copies of the maps intended for the web in them. (See "Files for the web," above.)

This option is on by default. To suppress the creation of web files, enter "-no-web" on the command line.

=item -webfolder

An alternative folder where web files will be created, instead of "web" under the specified folder. This will be the same for all files converted (it doesn't just replace the folder "web"within each folder with a new name, it specifies a single folder where all converted files will be located). "webfolder" can be abbreviated "wf".

=item -quiet, -verbose, and -progress

These three options tell the program how much detail to display on screen. 

"-quiet" eliminates all display except text that describes why the program quit unexpectedly. 

"-verbose" displays on the screen a message indicating the names of each map copied or rasterized.

"-progress" produces a running indication of which lines' maps are being processed, when "-verbose" is not in effect. This is on by default; use "-no-progress" to turn it off.

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
