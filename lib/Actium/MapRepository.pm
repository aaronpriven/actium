#MapRepository.pm

# Routines for dealing with the filenames of line maps

# Legacy status: 4

# The filename pattern is supposed to be

#  <lines>-<date>-<ver>.<ext>

# <lines>  is a list of lines separated by underscores, followed by
# an optional equals sign followed by a token (used to distinguish
# eastbound from westbound or weekday from weeekend, e.g., M=e-2005_15-v1.txt

# <date> is yyyy_mm (numeric)

# <ver>is <type><seq> - "type" is v for a line map, wv for a web-
# formatted line map (8.5x11), tt for a timetable map, "schem" for a schematic
# map, etc. At this point (Feb. 2012) only tt is used

#<ext> is of course .eps or .pdf, or another standard filename

use 5.014;
use warnings;

package Actium::MapRepository 0.010;

use Sub::Exporter -setup => {
    exports => [
        qw(import_to_repository  make_web_maps      copylatest
          normalize_filename     filename_is_valid
          )
    ]
};
# Sub::Exporter ### DEP ###

use Carp; ### DEP ###
use Const::Fast; ### DEP ###
use English '-no_match_vars'; ### DEP ###
use File::Copy(); ### DEP ###
use Params::Validate ':all'; ### DEP ###

use Actium::O::Folder;
use Actium::Util(qw<filename file_ext remove_leading_path>);
use Actium::Sorting::Line('sortbyline');
use Actium::Constants;
use Actium::Crier(qw/cry last_cry/);

const my $LINE_NAME_LENGTH   => 4;
const my $DEFAULT_RESOLUTION => 288;

const my $CAN_ACTIUM_FOLDER =>
  [qw<path children glob_plain_files subfolder make_filespec folder>];
# these are all the methods that Params::Validate tests for to see if it's
# a working folder object. Doing it with "can" rather than "isa" means we
# can use subclasses such as Actium::O::Folders::Signup.

### IMPORTING NEW MAPS

my $import_to_repository_paramspec = {
    importfolder => { can  => $CAN_ACTIUM_FOLDER },
    repository   => { can  => $CAN_ACTIUM_FOLDER },
    move         => { type => BOOLEAN, optional => 1 },
    verbose      => { type => BOOLEAN, default => 0 },
};

sub import_to_repository {

    my %params = u::validate( @_, $import_to_repository_paramspec );

    # this default is not in the parameter spec because if
    # in the spec, the default object would always be created whether or
    # not they were actually needed (which is bad)

    my $repository = $params{repository};
    my $move       = $params{move};
    my $verbose    = $params{verbose};

    my $importfolder = $params{importfolder};
    my $cry = cry ( 'Importing line maps from ' . $importfolder->path);
    my @files = $importfolder->glob_plain_files();

    my @copied_files;

  FILE:
    foreach my $filespec (sort @files) {

        next FILE if -d $filespec;

        my $filename    = filename($filespec);
        my $newfilename = $filename;
        $cry->over ($filename) unless $verbose;

        # if newfilename isn't valid, first run it through normalize_filename.
        # Then if it's still not valid, carp and move on.

        my $filename_is_valid = filename_is_valid($newfilename);

        $newfilename = normalize_filename($newfilename)
          unless $filename_is_valid;

        if ( not filename_is_valid($newfilename) ) {
            # check of the newly normalized name - not a duplicate call

            $cry->text (
"Can't find line, date, version or " . "extension in $filename: skipped");
            next FILE;
        }

        my %nameparts = %{ _mapname_pieces($newfilename) };

        my $lines      = $nameparts{lines};
        my $linefolder = $repository->subfolder($lines);

        my $newfilespec = $linefolder->make_filespec($newfilename);

        if ( -e $newfilespec ) {
            $cry->text (
"Can't move $filespec " . "because $newfilespec already exists: skipped");
            next FILE;
        }

        if ($move) {
            _move_file( $filespec, $newfilespec, $repository->path, $verbose );
        }
        else {
            _copy_file( $filespec, $newfilespec, $repository->path, $verbose );
        }
        push @copied_files, $newfilespec;
    } ## tidy end: foreach my $filespec (@files)
    $cry->done;

    return @copied_files;

} ## tidy end: sub import_to_repository

### COPYING/RASTERIZING WEB MAPS

my $make_web_maps_paramspec = {
    web_folder     => { can  => $CAN_ACTIUM_FOLDER },
    files          => { type => ARRAYREF },
    resolution     => { type => SCALAR, default => $DEFAULT_RESOLUTION },
    path_to_remove => { type => SCALAR, optional => 1 },
    verbose        => { type => BOOLEAN, default => 0 },
};

sub make_web_maps {

    my %params = u::validate( @_, $make_web_maps_paramspec );

    my $output_folder  = $params{web_folder};
    my $verbose        = $params{verbose};
    my $path_to_remove = $params{path_to_remove};
    my $gsargs         = "-r$params{resolution} -sDEVICE=jpeg "
      . '-dGraphicsAlphaBits=4 -dTextAlphaBits=4 -q';

    my $cry = cry( 'Making maps for web');

    foreach my $filespec ( @{ $params{files} } ) {

        my $filename = filename($filespec);
        next unless $filename =~ /[.]pdf\z/si;

        my %nameparts = %{ _mapname_pieces($filename) };

        $cry->over ($nameparts{lines}) if not $verbose;

        my @output_lines = @{ $nameparts{lines_r} };
        my $token        = $nameparts{token};

        if ( $token ne $EMPTY_STR ) {
            foreach (@output_lines) {
                $_ .= "=$token";
            }
        }

        # copy PDFs
        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.pdf");
            _copy_file( $filespec, $outfile, $path_to_remove, $verbose );
        }

        # copy JPGs

        my $first_line      = shift @output_lines;
        my $first_jpeg_spec = $output_folder->make_filespec("$first_line.jpeg");

        my $result = system qq{gs $gsargs -o "$first_jpeg_spec" "$filespec"};

        if ( $result == 0 ) {
            if ($verbose) {
                my $display_path = _display_path( $first_jpeg_spec, $filespec,
                    $path_to_remove );
                $cry->text ("Successfully rasterized: $display_path");
            }
        }
        else {
            my $display_path
              = _display_path( $first_jpeg_spec, $filespec, $path_to_remove );
            die "Couldn't rasterize: $display_path.\n"
              . "   System returned $result";
        }

        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.jpeg");
            _copy_file( $first_jpeg_spec, $outfile, $path_to_remove, $verbose );
        }

    } ## tidy end: foreach my $filespec ( @{ $params...})

    $cry->done;

    return;

} ## tidy end: sub make_web_maps

### FILENAME NORMALIZATION AND CHECKING

sub normalize_filename {
    # this is designed to handle only the most common filenames received from
    # Eureka. Earlier versions handled the many, many irregular filenames
    # we received over the years...

    my $filename = shift;

    my ( $filepart, $ext ) = split( /[.]/s, $filename );
    my ( $lines, $date, $ver ) = split( /-/s, $filepart );

    return $filename unless defined $date and defined $ver;

    $lines =~ s/,/_/gs;

    my @lines = split( /_/s, $lines );
    foreach (@lines) {
        $_ = uc($_) unless length($_) > $LINE_NAME_LENGTH;
    }
    $lines = join( '_', @lines );

    # there's probably a simpler regexy way of writing that, but I don't know
    # what it is right now

    if ( $date =~ /\A [[:alpha:]]{3} \d{2} \z/sx ) {
        for ($date) {
            # Warning -- this has a Y2100 problem! Do not use after that! :)

            # there is probably a less repetitive way to write this, but
            # who cares

            s/jan(\d\d)/20${1}_01/sxi;
            s/feb(\d\d)/20${1}_02/sxi;
            s/mar(\d\d)/20${1}_03/sxi;
            s/apr(\d\d)/20${1}_04/sxi;
            s/may(\d\d)/20${1}_05/sxi;
            s/june?(\d\d)/20${1}_06/sxi;
            s/july?(\d\d)/20${1}_07/sxi;
            s/aug(\d\d)/20${1}_08/sxi;
            s/sept?(\d\d)/20${1}_09/sxi;
            s/oct(\d\d)/20${1}_10/sxi;
            s/nov(\d\d)/20${1}_11/sxi;
            s/dec(\d\d)/20${1}_12/sxi;
        }
    } ## tidy end: if ( $date =~ /\A [[:alpha:]]{3} \d{2} \z/sx)

    for ($ver) {
        if ( not( defined or $_ eq q{} ) ) {
            $ver = 'v1';
            next;
        }
        if (/\A [[:alpha:]]+ \z/sx) {
            $ver .= '1';
            next;
        }
        #        when (/\A\d+\z/s) {
        #            $ver = "v$ver";
        #        }
    }

    my $newfilename = "$lines-$date-$ver";
    $newfilename .= ".$ext" if defined $ext;
    return $newfilename;

} ## tidy end: sub normalize_filename

const my $LINE_NAME_RE       => qr/(?:[[:upper:]\d]{1,4}|[[:alpha:]\d]{5,})/;
const    my $YEAR_RE => '(?:19[89]\d|20\d\d)';
    # year - another Y2100 problem
const    my $MONTH_RE => '(?:0[123456789]|1[012])';
    # numeric month

sub filename_is_valid {

    my $filename = shift;

    my $result = $filename =~ m{
              \A
              $LINE_NAME_RE
                  # one transit line 
              (?:_$LINE_NAME_RE)* 
                  # zero or more transit lines, separated by _
              (?:=\w+)?
                  # zero or one token starting with = and containing word characters
              \-
                  # hyphen separating lines and date
              $YEAR_RE
                  # year (another Y2100 problem!)
              _$MONTH_RE
                  # underscore followed by numeric month
              \-
                  # hyphen separating date and version
              \w+
                  # version (arbitrary word characters)
              [.]\w+
                  # extension
              \z
              }sx;

    return $result;

} ## tidy end: sub filename_is_valid

### COPY LATEST FILES TO NEW DIRECTORY

my $copylatest_spec = {
    repository         => { can  => $CAN_ACTIUM_FOLDER },
    fullname           => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    linesname          => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    web                => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    resolution         => { type => SCALAR, default => $DEFAULT_RESOLUTION },
    defining_extension => { type => SCALAR, default => 'eps' },
    verbose            => { type => BOOLEAN, default => 0 },
    active_map_file    => { type => SCALAR, default => 'active_maps.txt' },
};

sub copylatest {

    my %params             = u::validate( @_, $copylatest_spec );
    my $fullname_folder    = $params{fullname};
    my $linesname_folder   = $params{linesname};
    my $web_folder         = $params{web};
    my $defining_extension = $params{defining_extension};
    my $verbose            = $params{verbose};

    my $repository = $params{repository};

    my $list_cry= cry( 'Getting list of folders in map repository');
    my @folder_objs = $repository->children;
    $list_cry->done;

    my ( $is_an_active_map_r, $is_an_active_line_r )
      = _active_maps( $repository, $params{active_map_file} );

    my %latest_date_of;
    my %latest_ver_of;

    my $copy_cry = cry( 'Copying files in repository folders');

    my %folder_obj_of;
    $folder_obj_of{ $_->folder } = $_ foreach @folder_objs;

    my @web_maps_to_process;

  FOLDER:
    foreach my $foldername ( sortbyline keys %folder_obj_of ) {

        #        next FOLDER unless $foldername =~ m{
        #                      \A
        #                      $LINE_NAME_RE
        #                      (?:[_]              # with optional underline and
        #                      $LINE_NAME_RE
        #                      )*
        #                      \z
        #                      }sx;
        # if we ever want to have an option to copy lines that are not active,
        # un-commenting that out will have a check against folders like _web,
        # _fullnames, etc.

        next FOLDER unless $is_an_active_line_r->{$foldername};

        my $folder_obj = $folder_obj_of{$foldername};
        my @filespecs  = $folder_obj->glob_plain_files;

        $copy_cry->over ($foldername) unless $verbose;

      FILE:
        foreach my $filespec (@filespecs) {
            next FILE
              unless $filespec =~ /[.] $defining_extension \z/isx;
            my $filename = filename($filespec);

            my %nameparts = %{ _mapname_pieces($filename) };

            my $lines_and_token = $nameparts{lines_and_token};
            my $date            = $nameparts{date};
            my $ver             = $nameparts{ver};
            my $ext             = $nameparts{ext};

            next FILE unless $is_an_active_map_r->{$lines_and_token};

            ## use critic

            if (   not( exists( $latest_date_of{$lines_and_token} ) )
                or $latest_date_of{$lines_and_token} lt $date
                or ( $latest_date_of{$lines_and_token} eq $date
                    and lc( $latest_ver_of{$lines_and_token} ) lt lc($ver) )
              )
              # if there isn't a latest date for this line,
              # or if it's an earlier date, or the same date but an earlier
              # version,
            {
                $latest_date_of{$lines_and_token} = $date;
                $latest_ver_of{$lines_and_token}  = $ver;
                # mark the this file as the latest.
            }

        } ## tidy end: foreach my $filespec (@filespecs)

        # process latest files

        foreach my $line_and_token ( keys %latest_date_of ) {
            my $globpattern = join( '-',
                $line_and_token,
                $latest_date_of{$line_and_token},
                $latest_ver_of{$line_and_token} )
              . '.*';

            my @latest_filespecs = $folder_obj->glob_plain_files($globpattern);

            foreach my $latest_filespec (@latest_filespecs) {
                my $filename = filename($latest_filespec);
                my ( undef, $ext ) = file_ext($filename);

                if ( defined $fullname_folder ) {
                    my $newfilespec
                      = $fullname_folder->make_filespec($filename);
                    _copy_file(
                        $latest_filespec,  $newfilespec,
                        $repository->path, $verbose
                    );
                }

                if ( defined $linesname_folder ) {
                    my $newfilespec
                      = $linesname_folder->make_filespec($line_and_token)
                      . ".$ext";
                    _copy_file(
                        $latest_filespec,  $newfilespec,
                        $repository->path, $verbose
                    );
                }

                if ( defined $web_folder and lc($ext) eq 'pdf' ) {
                    push @web_maps_to_process, $latest_filespec;
                    #      make_web_maps(
                    #      {   web_folder     => $web_folder,
                    #          files          => [$latest_filespec],
                    #          resolution     => $params{resolution},
                    #          path_to_remove => $repository->path,
                    #          verbose        => $verbose,
                    #       }
                    #      );
                }

            } ## tidy end: foreach my $latest_filespec...

        } ## tidy end: foreach my $line_and_token ...

    } ## tidy end: foreach my $foldername ( sortbyline...)

    $copy_cry->done;

    if (@web_maps_to_process) {
        make_web_maps(
            {   web_folder     => $web_folder,
                files          => \@web_maps_to_process,
                resolution     => $params{resolution},
                path_to_remove => $repository->path,
                verbose        => $verbose,
            }
        );

    }
    return;

} ## tidy end: sub copylatest

### PRIVATE UTILITY METHODS

sub _active_maps {

    my $cry = cry( 'Getting list of active maps');

    my $repository = shift;
    my $filename   = shift;

    my $filespec = $repository->make_filespec($filename);

    open my $fh, '<', $filespec
      or croak "Can't open active maps file $filespec for reading: $OS_ERROR";

    my ( %is_an_active_map, %is_an_active_line );

    while (<$fh>) {
        chomp;
        $is_an_active_map{$_} = 1;
        s/=.*//;
        $is_an_active_line{$_} = 1;
    }

    $cry->done;

    return \%is_an_active_map, \%is_an_active_line;
} ## tidy end: sub _active_maps

sub _file_action {

    my ( $from, $to, $path, $verbose, $action_r, $actionword ) = @_;

    if ( $action_r->( $from, $to ) ) {
        if ($verbose) {
            my $display_path = _display_path( $from, $to, $path );
            last_cry()->text ("Successful $actionword: $display_path");
        }
    }
    else {
        my $display_path = _display_path( $from, $to, $path );
        die "Couldn't $actionword: $display_path\n$OS_ERROR";
    }
    return;

}

sub _display_path {

    my ( $from, $to, $path ) = @_;    # making copies
    if ( defined $path ) {
        foreach ( $from, $to ) {      # aliasing $_ to each in turn
            my $new = remove_leading_path( $_, $path );
            if ( $_ ne $new ) {
                $_ = ".../$new";
            }
        }
    }
    return "$from => $to";
}

sub _copy_file {
    my $action_r   = \&File::Copy::copy;
    my $actionword = "copy";
    return _file_action( @_, $action_r, $actionword );
}

sub _move_file {
    my $action_r   = \&File::Copy::move;
    my $actionword = "move";
    return _file_action( @_, $action_r, $actionword );
}

sub _mapname_pieces {
    ## no critic (ProhibitMagicNumbers)
    my $filename = shift;
    my ( $filepart, $ext ) = file_ext($filename);
    my ( $lines_and_token, $date, $ver ) = split( /-/s, $filepart, 3 );

    my ( $lines, $token ) = split( /=/s, $lines_and_token );

    $token = $EMPTY_STR unless defined $token;

    my @lines = split( /_/s, $lines );
    return {
        lines           => $lines,
        lines_r         => \@lines,
        lines_and_token => $lines_and_token,
        token           => $token,
        date            => $date,
        ver             => $ver,
        ext             => $ext,
    };

    ## use critic

} ## tidy end: sub _mapname_pieces

1;

__END__

=head1 NAME

Actium::MapRepository - Routines to read and write from the maps repository

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::MapsRepository;
 
 $repository = Actium::O::Folder->new('/path/to/repository');
 $import = Actium::O::Folder->new('/path/to/maps/for/importing');
 $webfolder = Actium::O::Folder->new('/path/to/maps/for/web');
 
 my @imported_files = import_to_repository(
    repository   => $repository,
    move         => 1,
    importfolder => $importfolder,
 );
        
 make_web_maps(
    web_folder     => $webfolder,
    files          => \@imported_files,
    path_to_remove => $repository->path,
 );
        
 copylatest( repository => $repository );
 
 do_something_with($filename) if filename_is_valid($filename);
 
 my $new_filename = normalize_filename ($filename);
 
=head1 DESCRIPTION

Actium::MapRepository is a series of routines used to read and write
files from the Actium Maps Repository.

Detailed documentation on the maps repository  
can be found in the separate documents, "The Actium Maps Repository: 
Quick Start Guide" and "The Actium Maps Repository: Extended Usage 
and Technical Detail." 

=head1 NOTE ON FOLDER OPTIONS

Folders passed to any of Actium::MapRepository's routines must be in the form
of an object, not just a string file specification.  Generally, this will
be an Actium::O::Folder object or a subclass. Specifically, the object must
handle the following methods:

=over

=item * path

=item * children

=item * glob plain files

=item * subfolder

=item * make_filespec

=item * folder

=back

See L<Actium::O::Folder/Actium::O::Folder> for information on what these methods
should do.

=head1 SUBROUTINES

=over

=item B<filename_is_valid(I<filename>)>

This routine takes a filename as an argument, and returns true if it
matches the appropriate pattern for a map filename as described in 
"The Actium Maps Repository: Extended Usage and Technical Detail." 

=item B<normalize_filename(I<filename>)>

This routine takes a filename and attempts to convert it to a version
appropriate for use within the repository. It only attempts two simple
conversions: replacing commas with underscores and dates in the form
"mmmyy" (e.g., feb12, apr03) with numeric dates (2012_02, 2003_04).
Note that the date routine assumes years in the 2000-2099 range.

It returns the filename, converted as best it can.

=item B<import_to_repository(<named options>)>

The B<import_to_repository> routine moves or copies files from a 
specified folder
into the repository. It goes through each file in the specified folder,
normalizes the name via B<normalize_filename>, 
copies or moves it into the repository, and returns the file specifications
of the copied files in their new locations.

It takes a series of named arguments, which can be a hash or hash reference.

=head2 Named Arguments

=over

=item importfolder

Mandatory. A folder object representing the folder where the map files to be 
imported are.

=item repository

Mandatory. A folder object representing the folder of the map repository.

=item move

Optional. A boolean value, true if the files should be moved to the repository, 
false if they should be copied to the repository but not removed from
the importfolder. If not specified, defaults to true (files will
be moved).

=item verbose

Optional. If true, sends to the terminal a message indicating the names of each 
map copied or rasterized. Off by default.

=back

=item B<make_web_maps(I<named options>)>

The B<make_web_maps> routine takes specified PDF files and copies them to a 
new folder. It also rasterizes them into JPEG files. See "Files for the Web" in 
"The Actium Maps Repository: Extended Usage and Technical Detail"  for more
information.

It takes a series of named options, which can be a hash or hash reference.

=head2 Named Options

=item webfolder

Mandatory. A folder object representing the destination folder for the 
Web files.

=item files

Mandatory. A reference to an array, whose contents should be the 
file specifications for the files which will be copied and rasterized. 
Files which do not have 
".pdf" extensions will be silently skipped.

=item resolution

Optional. The resolution for rasterizing maps in pixels per inch (passed as
Ghostscript's -r switch).  If not specified, uses 288.

=item verbose

Optional. If true, sends to the terminal a message indicating the names of each 
map copied or rasterized. Off by default.

=item path_to_remove

Optional. A string representing text to be removed from the beginning of
displayed paths when verbose is true. Useful for, for example, removing the
repository name from subfolders of the repository. If found at the beginning
of the webfolder, it will be replaced by an ellipsis ("...").

=back

=item B<copylatest()>

The B<copylatest()> routine searches through the repository, looking for the
latest versions of the maps. It then copies the files to folders
specified in named arguments, and runs B<make_web_maps> on them.

For each set of lines (and token if present), it finds the EPS file 
(or another file, if the defining_extension argument is passed) with
the latest date and version, and copies all the files with that date and
version. (Other types of files that may be dated later are not used for
finding the latest map.) 

Detailed documentation on the map repository's format
can be found in "The Actium Maps Repository: Quick Start Guide."

Detailed documentation on the Hogwarts School of Witchcraft and Wizardry
can be found in I<Hogwarts: A History.>

=head2 Named Arguments

=over

=item repository

Mandatory. A folder object representing the folder of the map repository.

=item fullname

Optional. A folder object representing a destination folder where files will
be copied, with their names intact (including date and version). If omitted, 
this action will be skipped.

=item linesname

Optional. A folder object representing a destination folder where files will
be copied, using only the name of the line (and token, if present), without 
date or version. If omitted, this action will be skipped.

=item web

Optional. A folder object to be passed to the "webfolder" argument
of B<make_web_maps>. If omitted, B<make_web_maps> will be skipped.

=item resolution

See B<make_web_maps>.

=item verbose

Optional. If true, sends to the terminal a message indicating the names of each 
map copied or rasterized. Off by default.

=item active_map_file

Optional. A file name to be used to determine which maps are currently
active. The file should contain a list of active lines (and tokens), 
one per line. Defaults to "active_maps.txt". The file must be located
within the repository folder.

=item defining_extension

Optional. The B<copylatest> routine searches for files of a particular 
extension within the repository to determine which map is the most recent.
If this argument is not specified, it will look for .eps files.

=back

=head1 DIAGNOSTICS

=item Can't find line, date, version or extension in <file>: skipped

The B<import_to_repository> routine found a filename that did not meet 
the expected
file pattern. It will skip this file and move on to the next one. 
Usually the best course is to manually rename the file and try again.

=item Can't move <file> because <new file> already exists: skipped

The B<import_to_repository> routine found that a file found in the 
import folder
already existed in the repository. It will skip this file and move on to
the next one. Determine whether the two files are actually the same, and 
if not, rename the new one and try again.

=item Couldn't rasterize: <path>. System returned <result>

Ghostscript returned an system error to B<make_web_maps>.

=item Can't open active maps file <file> for reading: <error>

Attempting to open the active maps file for reading returned a 
system error.

=item Couldn't move: <files> <error>

=item Couldn't copy: <files> <error>

Attempting to move or copy returned a system error.

=head1 DEPENDENCIES

=over

=item * A working Ghostscript installation, with "gs" in the system's path.

=item * Perl 5.014

=item * Const::Fast

=item * Params::Validate

=item * Sub::Exporter

=item * Actium::Constants

=item * Actium::O::Folder

=item * Actium::Sorting::Line

=item * Actium::Util

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
