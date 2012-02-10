#MapRepository.pm

# Routines for dealing with the filenames of line maps

# Subversion:
# $Id$

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

package Actium::MapRepository 0.001;
use Sub::Exporter -setup => {
    exports => [
        qw(import_to_repository  make_web_maps      copylatest
          normalize_filename     filename_is_lines
          )
    ]
};

use Carp;
use Const::Fast;
use English '-no_match_vars';
use File::Copy();
use Params::Validate ':all';

use Actium::Folder;
use Actium::Util(qw<filename file_ext remove_leading_path>);
use Actium::Sorting::Line('sortbyline');
use Actium::Term ':all';

const my $DEFAULT_RESOLUTION => 288;
const my $LINE_NAME_RE       => '[[:upper:]\d]{1,3}';

const my $CAN_ACTIUM_FOLDER =>
  [qw<path children glob_plain_files subfolder make_filespec folder>];
# these are all the methods that Params::Validate tests for to see if it's
# a working folder object. Doing it with "can" rather than "isa" means we
# can use subclasses such as Actium::Folders::Signup.

### IMPORTING NEW MAPS

my $import_to_repository_paramspec = {
    importfolder => { can  => $CAN_ACTIUM_FOLDER },
    repository   => { can  => $CAN_ACTIUM_FOLDER },
    move         => { type => BOOLEAN, optional => 1 },
};

sub import_to_repository {

    my %params = validate( @_, $import_to_repository_paramspec );

    # this default is not in the parameter spec because if
    # in the spec, the default object would always be created whether or
    # not they were actually needed (which is bad)

    my $repository = $params{repository};
    my $move       = $params{move};

    my $importfolder = $params{importfolder};
    emit 'Importing line maps from ' . $importfolder->path;
    my @files = $importfolder->glob_plain_files();

    my @copied_files;

  FILE:
    foreach my $filespec (@files) {

        next FILE if -d $filespec;

        my $filename    = filename($filespec);
        my $newfilename = $filename;
        emit_over $filename;

        # if newfilename isn't valid, first run it through normalize_filename.
        # Then if it's still not valid, carp and move on.

        $newfilename = normalize_filename($newfilename)
          unless filename_is_lines($newfilename);

        if ( not filename_is_lines($newfilename) ) {
            emit_text
"Can't find line, date, version or extension in $filename: skipped";
            next FILE;
        }

        my $lines      = _lines_from_filename($filename);
        my $linefolder = $repository->subfolder($lines);

        my $newfilespec = $linefolder->make_filespec($newfilename);

        if ( -e $newfilespec ) {
            emit_text
"Can't move $filespec because $newfilespec already exists: skipped";
            next FILE;
        }

        my $result;
        if ($move) {
            _move_file( $filespec, $newfilespec, $repository->path );
        }
        else {
            _copy_file( $filespec, $newfilespec, $repository->path );
        }

    } ## tidy end: foreach my $filespec (@files)
    emit_done;

    return @copied_files;

} ## tidy end: sub import_to_repository

### COPYING/RASTERIZING WEB MAPS

my $make_web_maps_paramspec = {
    web_folder => { can  => $CAN_ACTIUM_FOLDER },
    files      => { type => ARRAYREF },
    resolution => { type => SCALAR, default => $DEFAULT_RESOLUTION },
    path_to_remove => { type => SCALAR, optional => 1 },
};

sub make_web_maps {

    my %params = validate( @_, $make_web_maps_paramspec );

    my $output_folder = $params{web_folder};
    my $path_to_remove = $params{path_to_remove};
    my $gsargs        = "-r$params{resolution} -sDEVICE=jpeg "
      . '-dGraphicsAlphaBits=4 -dTextAlphaBits=4 -q';

    emit 'Making maps for web';

    foreach my $filespec ( @{ $params{files} } ) {

        my $filename = filename($filespec);

        next unless $filename =~ /[.]pdf\z/si;

        my $lines = _lines_from_filename($filename);

        my @output_lines = split( /_/s, $lines );

        # copy PDFs
        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.pdf");
            _copy_file( $filespec, $outfile , $path_to_remove);
        }

        # copy JPGs

        my $first_line      = shift @output_lines;
        my $first_jpeg_spec = $output_folder->make_filespec("$first_line.jpeg");

        my $result = system qq{gs $gsargs -o "$first_jpeg_spec" "$filespec"};

        if ( $result == 0 ) {
            emit_text "Successfully rasterized $filespec to $first_jpeg_spec";
        }
        else {
            die "Couldn't rasterize $filespec to $first_jpeg_spec:\n"
              . "system returned $result";
        }
        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.jpeg");
            _copy_file( $filespec, $outfile , $path_to_remove);
        }

    } ## tidy end: foreach my $filespec ( @{ $params...})

    emit_done;

    return;

} ## tidy end: sub make_web_maps

### FILENAME NORMALIZATION AND CHECKING

sub normalize_filename {
    # this is designed to handle only the most common filenames received from
    # Eureka. Earlier versions handled the many, many irregular filenames
    # we received over the years...

    my ( $filename, $ext ) = split( /[.]/s, shift() );
    my ( $lines, $date, $ver ) = split( /-/s, $filename );

    $lines =~ s/,/_/gs;

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
            s/jun(\d\d)/20${1}_06/sxi;
            s/jul(\d\d)/20${1}_07/sxi;
            s/aug(\d\d)/20${1}_08/sxi;
            s/sep(\d\d)/20${1}_09/sxi;
            s/oct(\d\d)/20${1}_10/sxi;
            s/nov(\d\d)/20${1}_11/sxi;
            s/dec(\d\d)/20${1}_12/sxi;
        }
    } ## tidy end: if ( $date =~ /\A [[:alpha:]]{3} \d{2} \z/sx)

    given ($ver) {
        when ( not( defined or $_ eq q{} ) ) {
            $ver = 'v1';
        }
        when (/\A [[:alpha:]]+ \z/sx) {
            $ver .= '1';
        }
        when (/\A\d+\z/s) {
            $ver = "v$ver";
        }
    }

    return "$lines-$date-$ver.$ext";

} ## tidy end: sub normalize_filename

sub filename_is_lines {

    my $filename = shift;

    my $linename_re = '[[:upper:]\d]{1,3}';
    # 1 to 3 ASCII letters or numbers
    my $year_re = '(?:19[89]\d|20\d\d)';
    # year - another Y2100 problem
    my $month_re = '(?:0[123456789]|1[012])';
    # numeric month

    return m{
              $LINE_NAME_RE
                  # one transit line ( 1 to 3 ASCII letters or numbers )
              (?:_$LINE_NAME_RE)* 
                  # zero or more transit lines, separated by _
              (?:=\w+)
                  # one token containing word characters
              -
                  # hyphen separating lines and date
              $year_re
                  # year (another Y2100 problem!)
              _$month_re
                  # underscore followed by numeric month
              -
                  # hyphen separating date and version
              \w+
                  # version (arbitrary word characters)
              [.]\w+
                  # extension
              }sx;

} ## tidy end: sub filename_is_lines

### COPY LATEST FILES TO NEW DIRECTORY

my $copylatest_spec = {
    repository         => { can  => $CAN_ACTIUM_FOLDER },
    fullname           => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    linesname          => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    web                => { can  => $CAN_ACTIUM_FOLDER, optional => 1 },
    resolution         => { type => SCALAR, default => $DEFAULT_RESOLUTION },
    defining_extension => { type => SCALAR, default => 'eps' },
};

sub copylatest {

    my %params             = validate( @_, $copylatest_spec );
    my $fullname_folder    = $params{fullname};
    my $linesname_folder   = $params{linesname};
    my $web_folder         = $params{web};
    my $defining_extension = $params{defining_extension};

    my $repository = $params{repository};

    emit 'Getting list of folders in map repository';
    my @folder_objs = $repository->children;
    emit_done;

    my %is_an_active_map = _active_maps($repository);

    my %latest_date_of;
    my %latest_ver_of;

    emit 'Copying files in repository folders';

    my %folder_obj_of;
    $folder_obj_of{ $_->folder } = $_ foreach @folder_objs;

  FOLDER:
    foreach my $foldername ( sortbyline keys %folder_obj_of ) {

        next FOLDER unless $foldername =~ m{
                      \A
                      $LINE_NAME_RE       # three alphanumerics
                      (?:[_]              # with optional underline and
                      $LINE_NAME_RE       #    three alphanums
                      )*
                      \z
                      }sx;

        next FOLDER unless $is_an_active_map{$foldername};

        emit_over $foldername;

        my $folder_obj = $folder_obj_of{$foldername};
        my @filespecs  = $folder_obj->glob_plain_files;

      FILE:
        foreach my $filespec (@filespecs) {
            next FILE
              unless $filespec =~ /[.] $defining_extension \z/isx;
            my $filename = filename($filespec);
            my ( $filepart, $ext ) = file_ext($filespec);

            ## no critic (ProhibitMagicNumbers)
            my ( $lines_and_token, $date, $ver ) = split( /-/s, $filepart, 3 );
            ## use critic

            if (   not( exists( $latest_date_of{$lines_and_token} ) )
                or $latest_date_of{$lines_and_token} lt $date
                or (    $latest_date_of{$lines_and_token} eq $date
                    and $latest_ver_of{$lines_and_token} lt $ver )
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

                if (defined $fullname_folder) {
                    my $newfilespec
                      = $fullname_folder->make_filespec($filename);
                    _copy_file( $latest_filespec, $newfilespec,
                        $repository->path );
                }

                if (defined $linesname_folder) {
                    my $newfilespec
                      = $linesname_folder->make_filespec($line_and_token)
                      . ".$ext";
                    _copy_file( $latest_filespec, $newfilespec,
                        $repository->path );
                }

                if ( defined $web_folder and lc($ext) eq 'pdf' ) {
                    make_web_maps(
                        {   web_folder => $web_folder,
                            files      => [$latest_filespec],
                            resolution => $params{resolution},
                            path_to_remove => $repository->path,
                        }
                    );
                }

            } ## tidy end: foreach my $latest_filespec...

        } ## tidy end: foreach my $line_and_token ...

    } ## tidy end: foreach my $foldername ( sortbyline...)

    emit_done;
    return;

} ## tidy end: sub copylatest

### PRIVATE UTILITY METHODS

sub _active_maps {

    emit 'Getting list of active maps';

    my $repository = shift;
    my $filename = shift || '_active_maps.txt';

    my $filespec = $repository->make_filespec($filename);

    open my $fh, '<', $filespec
      or croak "Can't open $filespec for reading: $OS_ERROR";

    my %is_an_active_map;

    while (<$fh>) {
        chomp;
        $is_an_active_map{$_} = 1;
    }

    emit_done;

    return %is_an_active_map;
} ## tidy end: sub _active_maps

sub _copy_file {
    my ($from, $to, $path) = @_;
    my $display_path =  _display_path(@_);
    
    if ( File::Copy::copy( $from, $to ) ) {
        emit_text "Copied: $display_path";
    }
    else {
        die "Couldn't copy: $display_path\n$OS_ERROR";
    }
    return;
}

sub _move_file {
    my ($from, $to, $path) = @_;
    my $display_path =  _display_path(@_);

    if ( File::Copy::move( $from, $to ) ) {
        emit_text "Moved: $display_path";
    }
    else {
        die "Couldn't move: $display_path\n$OS_ERROR";
    }
    return;
}

sub _display_path {
    my ( $from, $to, $path ) = @_;
    if ( defined $path ) {
        foreach ( $from, $to ) {
            my $new = remove_leading_path( $_, $path );
            if ( $_ ne $new ) {
                $_ = "<repos>/$new";
            }
        }

    }
    
    return "$from => $to";

}

sub _lines_from_filename {
    my $filename = shift;
    my $lines    = $filename;
    $lines =~ s/[-=].*//s;
    return $lines;
}

1;

__END__

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 OPTIONS

A complete list of every available command-line option with which
the application can be invoked, explaining what each does and listing
any restrictions or interactions.

If the application has no options, this section may be omitted.

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
