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
add_option( 'web!',
    'Create web files of maps (on by default; turn off with -no-web)', 1 );
add_option( 'fullnames!',
    'Copy files with their full names (on by default; turn off with -no-web)',
    1, );
add_option(
    'linesnames!',
    'Copy files using the lines and token as the name only '
      . '(on by default; turn off with -no-web)',
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
        repository => $repository,
        fullname   => $fullfolder,
        linesname  => $linesfolder,
        web        => $webfolder,
        verbose    => option('verbose'),
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

