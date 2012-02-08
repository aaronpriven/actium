#LineMaps.pm

# Routines for dealing with the filenames of line maps

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

package Actium::LineMaps 0.001;

use Params::Validate ':all';
use File::Copy();
use Carp;
use Actium::Folder;

use Actium::Util('filename');

use Actium::Term ':all';

my $DEFAULT_RESOLUTION = 288;

### SHARED PARAMETER SPECIFICATIONS

my $import_to_repository_paramspec = {
    importfolder => { can  => qw<path glob_plain_files>, },
    repository   => { can  => qw<path subfolder make_filespec>, optional => 1 },
    move         => { type => BOOLEAN, optional => 1 },
};

my $make_web_maps_paramspec = {
    web_folder => { can  => qw<path make_filespec> },
    files      => { type => ARRAYREF },
    resolution => { type => SCALAR, default => $DEFAULT_RESOLUTION },
};

my $new_map_paramspec = {
    %{$import_to_repository_paramspec},
    web_folder => { can  => qw<path make_filespec> },
    resolution => { type => SCALAR, default => $DEFAULT_RESOLUTION },
};

### IMPORTING NEW MAPS

sub new_maps {
    my %params = validate( @_, $import_to_repository_paramspec );
    my @files = import_to_repository(@_);
    make_web_maps( { web_folder => $params{web_folder}, files => \@files } );
}

sub import_to_repository {

    my %params = validate( @_, $import_to_repository_paramspec );

    # this default is not in the parameter spec because if
    # in the spec, the default object would always be created whether or
    # not they were actually needed (which is bad)

    my $repository = _repository( $params{repository} );

    my $importfolder = $params{importfolder};
    emit "Importing line maps from " . $importfolder->path;
    my @files = $importfolder->glob_plain_files();

    my @copied_files;

  FILE:
    foreach my $filespec (@files) {

        next FILE if -d $filespec;

        my $filename    = filename($filespec);
        my $newfilename = $filename;

        # if newfilename isn't valid, first run it through normalize_filename.
        # Then if it's still not valid, carp and move on.

        $newfilename = normalize_filename($newfilename)
          unless filename_is_valid($newfilename);

        if ( not filename_is_valid($newfilename) ) {
            emit_text
"Can't find line, date, version or extension in $filename: skipped";
            next FILE;
        }

        my $lines = _lines_from_filename($filename);
        $lines =~ s/_/ /g;
        my $linefolder = $repository->subfolder($lines);

        my $newfilespec = $linefolder->make_filespec($newfilename);

        if ( -e $newfilespec ) {
            emit_text
"Can't move $filespec because $newfilespec already exists: skipped";
            next FILE;
        }

        my $result;
        my $verb;
        if ( $params{move} ) {
            _move_file( $filespec, $newfilespec );
        }
        else {
            _copy_file( $filespec, $newfilespec );
        }

    } ## tidy end: foreach my $filespec (@files)
    emit_done;

    return @copied_files;

} ## tidy end: sub import_to_repository

### COPYING/RASTERIZING WEB MAPS

sub make_web_maps {

    my %params = validate( @_, $make_web_maps_paramspec );

    my $output_folder = $params{web_folder};
    my $gsargs        = "-r $params{resolution} -sDEVICE=jpeg "
      . "-dGraphicsAlphaBits=4 -dTextAlphaBits=4";

    emit "Making maps for web";

    foreach my $filespec ( @{ $params{files} } ) {

        my $filename = filename($filespec);

        next unless $filename =~ /\.pdf\z/i;

        my $lines = _lines_from_filename($filename);

        my @output_lines = split( /_/, $lines );

        # copy PDFs
        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.pdf");
            _copy_file( $filespec, $outfile );
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
            _copy_file( $filespec, $outfile );
        }

    } ## tidy end: foreach my $filespec ( @{ $params...})

    emit_done;

} ## tidy end: sub make_web_maps

### FILENAME NORMALIZATION AND CHECKING

sub normalize_filename {
    # this is designed to handle only the most common filenames received from
    # Eureka. Earlier versions handled the many, many irregular filenames
    # we received over the years...

    my ( $filename, $ext ) = split( /\./, shift() );
    my ( $lines, $date, $ver ) = split( /-/, $filename );

    $lines =~ s/,/_/g;

    if ( $date =~ /\A[[:alpha:]]{3}\d{2}\z/ ) {
        for ($date) {
            # Warning -- this has a Y2100 problem! Do not use after that! :)

            # there is probably a less repetitive way to write this, but
            # who cares
            s/jan(\d\d)/20${1}_01/i;
            s/feb(\d\d)/20${1}_02/i;
            s/mar(\d\d)/20${1}_03/i;
            s/apr(\d\d)/20${1}_04/i;
            s/may(\d\d)/20${1}_05/i;
            s/jun(\d\d)/20${1}_06/i;
            s/jul(\d\d)/20${1}_07/i;
            s/aug(\d\d)/20${1}_08/i;
            s/sep(\d\d)/20${1}_09/i;
            s/oct(\d\d)/20${1}_10/i;
            s/nov(\d\d)/20${1}_11/i;
            s/dec(\d\d)/20${1}_12/i;
        }
    } ## tidy end: if ( $date =~ /\A[[:alpha:]]{3}\d{2}\z/)

    given ($ver) {
        when ( not( defined or $_ eq q{} ) ) {
            $ver = 'v1';
        }
        when (/\A[[:alpha:]]+\z/) {
            $ver .= '1';
        }
        when (/\A\d+\z/) {
            $ver = "v$ver";
        }
    }

    return "$lines-$date-$ver.$ext";

} ## tidy end: sub normalize_filename

sub filename_is_valid {

    my $filename = shift;

    return m{
              [[:upper:]\d]{1,3}      
                  # one transit line ( 1 to 3 ASCII letters or numbers )
              (?:_[[:upper]\d]{1,3})* 
                  # zero or more transit lines, separated by _
              (?:=\w+)
                  # one token containing word characters
              -
                  # hyphen separating lines and date
              (?:19[89]\d|20\d\d)
                  # year (another Y2100 problem!)
              _(?:0[123456789]|1[012])
                  # underscore followed by numeric month
              -
                  # hyphen separating date and version
              \w+
                  # version (arbitrary word characters)
              \.\w+
                  # extension
              }x;

} ## tidy end: sub filename_is_valid

### COPY LATEST FILES TO NEW DIRECTORY

my $copylatest_spec = {
    repository => { can => qw<path subfolder make_filespec>, optional => 1 },
    withdates  => { can => qw<path subfolder make_filespec>, optional => 1 },
    nodates    => { can => qw<path subfolder make_filespec>, optional => 1 },
    web        => { can => qw<path subfolder make_filespec>, optional => 1 },
    resolution         => { type => SCALAR, default => $DEFAULT_RESOLUTION },
    defining_extension => { type => SCALAR, default => 'eps' },
};

sub copylatest {

    my %params             = validate( @_, $copylatest_spec );
    my $nodates_folder     = $params{nodates};
    my $withdates_folder   = $params{withdates};
    my $web_folder         = $params{web};
    my $defining_extension = $params{defining_extension};

    my $repository = _repository( $params{repository} );

    my @folder_objs = $repository->children;

    my %validlines = validlines($repository);

  FOLDER:

    my %latest_date_of;
    my %latest_ver_of;

    foreach my $folder_obj (@folder_objs) {
        my $foldername = $folder_obj->folder;
        next FOLDER unless $foldername =~ m{
                      \A
                      [[:alpha:]\d]{1,3}  # three alphanumerics
                      (?:[ ]               # with optional space and
                      [[:alpha]]\d]{1,3}  #    three alphanums
                      )*
                      \z
                      }x;

        next FOLDER unless $validlines{$foldername};

        my @filespecs = $folder_obj->glob_plain_files;

      FILE:
        foreach my $filespec (@filespecs) {
            next FILE unless $filespec =~ /\.$defining_extension\z/i;
            my $filename = filename($filespec);

            my ( $lines_and_token, $date, $ver ) = split( /-/, $filename, 3 );

            if (   !exists( $latest_date_of{$lines_and_token} )
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
            my $globpattern = join( "-",
                $line_and_token,
                $latest_date_of{$line_and_token},
                $latest_ver_of{$line_and_token} )
              . '.*';

            my @filespecs = $folder_obj->glob_plain_files($globpattern);

            foreach my $filespec (@filespecs) {
                my $filename = filename($filespec);
                my $ext      = file_ext($filename);

                if ($nodates_folder) {
                    my $newfilespec
                      = $nodates_folder->make_filespec($line_and_token)
                      . ".$ext";
                    _copy_file( $filespec, $newfilespec );
                }

                if ($withdates_folder) {
                    my $newfilespec
                      = $withdates_folder->make_filespec($filename);
                    _copy_file( $filespec, $newfilespec );
                }

                if ( $web_folder and lc($ext) eq 'pdf' ) {
                    make_web_maps(
                        {   web_folder => $web_folder,
                            files      => [$filespec],
                            resolution => $params{resolution},
                        }
                    );
                }

            } ## tidy end: foreach my $filespec (@filespecs)

        } ## tidy end: foreach my $line_and_token ...

    } ## tidy end: foreach my $folder_obj (@folder_objs)

} ## tidy end: sub copylatest

my $validlines_paramspec = {
    repository => { can => qw<path subfolder make_filespec>, optional => 1 },
    validfile => { type => SCALAR, default => '_validlines' }
};

sub validlines {
    my %params = ( @_, $validlines_paramspec );
    my $repository = _repository( $params{repository} );

    open my $fh, '<', $params{validfile}
      or croak "Can't open $params{validfile} for reading: $!";

    my %validlines;

    while (<$fh>) {
        chomp;
        $validlines{$_} = 1;
    }

    return %validlines;
}

### PRIVATE UTILITY METHODS

sub _repository {

    my $repository = shift()
      // Actium::Folder::new('/Volumes/Bireme/Maps/Line Maps/');
    return $repository;

}

sub _copy_file {
    my ( $from, $to ) = shift;
    if ( File::Copy::copy( $from, $to ) ) {
        emit_text "Copied: $from => $to";
    }
    else {
        die "Couldn't copy: $from => $to\n$!";
    }
}

sub _move_file {
    my ( $from, $to ) = shift;
    if ( File::Copy::move( $from, $to ) ) {
        emit_text "Moved: $from => $to";
    }
    else {
        die "Couldn't move: $from => $to\n$!";
    }
}

sub _lines_from_filename {
    my $filename = shift;
    my $lines    = $filename;
    $lines =~ s/[-=].*//;
    return $lines;
}
