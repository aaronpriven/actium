# /Actium/Cmd/MRImport.pm

# Command-line access to import_to_repository in Actum::MapRepostory

# Subversion: $Id$

# Legacy status: 4

package Actium::Cmd::MRImport 0.001;

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
add_option( 'makeweb|mw!',
    'Create web files of maps (on by default; turn off with -no-makeweb)', 1 );
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
    say 'actium.pl mr_import _folder_ _folder_...'
      or die "Can't display usage: $OS_ERROR";
    output_usage;
    return;
}

sub START {

    my @importfolders = @_;
    unless (@importfolders) {
        HELP();
        return;
    }
    my $move          = option('move');
    my $makeweb       = option('makeweb');
    my $webfolder_opt = option('webfolder');
    my $verbose       = option('verbose');

    my $specified_webfolder_obj;

    if ( $makeweb and $webfolder_opt ) {
        $specified_webfolder_obj = Actium::Folder->new( option('webfolder') );
    }

    my $repository = Actium::Folder->new( option('repository') );

    foreach (@importfolders) {

        # import to repository
        my $importfolder   = Actium::Folder->new($_);
        my @imported_files = import_to_repository(
            repository   => $repository,
            move         => option('move'),
            importfolder => $importfolder
        );

        # make web files

        if ($makeweb) {
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

    } ## tidy end: foreach (@importfolders)

    return;

} ## tidy end: sub START

1;

__END__


=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.001

=head1 USAGE

 # brief working invocation example(s) using the most comman usage(s)

=head1 REQUIRED ARGUMENTS

A list of every argument that must appear on the command line when
the application is invoked, explaining what each one does, any
restrictions on where each one may appear (i.e., flags that must
appear before or after filenames), and how the various arguments
and options may interact (e.g., mutual exclusions, required
combinations, etc.)

If all of the application's arguments are optional, this section
may be omitted entirely.

=over

=item B<argument()>

Description of argument.

=back

=head1 OPTIONS

A complete list of every available option with which the application
can be invoked, explaining wha each does and listing any restrictions
or interactions.

If the application has no options, this section may be omitted.

=head1 DESCRIPTION

A full description of the program and its features.

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

