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
          normalize_filename     filename_is_valid
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
use Actium::Constants;

const my $LINE_NAME_LENGTH   => 4;
const my $DEFAULT_RESOLUTION => 288;
const my $LINE_NAME_RE       => '(?:[[:upper:]\d]{1,4}|[[:alpha:]\d{5,})';

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
    verbose      => { type => BOOLEAN, default => 0 },
};

sub import_to_repository {

    my %params = validate( @_, $import_to_repository_paramspec );

    # this default is not in the parameter spec because if
    # in the spec, the default object would always be created whether or
    # not they were actually needed (which is bad)

    my $repository = $params{repository};
    my $move       = $params{move};
    my $verbose    = $params{verbose};

    my $importfolder = $params{importfolder};
    emit 'Importing line maps from ' . $importfolder->path;
    my @files = $importfolder->glob_plain_files();

    my @copied_files;

  FILE:
    foreach my $filespec (@files) {

        next FILE if -d $filespec;

        my $filename    = filename($filespec);
        my $newfilename = $filename;
        emit_over $filename unless $verbose;

        # if newfilename isn't valid, first run it through normalize_filename.
        # Then if it's still not valid, carp and move on.

        $newfilename = normalize_filename($newfilename)
          unless filename_is_valid($newfilename);

        if ( not filename_is_valid($newfilename) ) {
            emit_text
"Can't find line, date, version or extension in $filename: skipped";
            next FILE;
        }

        my %nameparts = %{ _mapname_pieces($newfilename) };

        my $lines      = $nameparts{lines};
        my $linefolder = $repository->subfolder($lines);

        my $newfilespec = $linefolder->make_filespec($newfilename);

        if ( -e $newfilespec ) {
            emit_text
"Can't move $filespec because $newfilespec already exists: skipped";
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
    emit_done;

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

    my %params = validate( @_, $make_web_maps_paramspec );

    my $output_folder  = $params{web_folder};
    my $verbose        = $params{verbose};
    my $path_to_remove = $params{path_to_remove};
    my $gsargs         = "-r$params{resolution} -sDEVICE=jpeg "
      . '-dGraphicsAlphaBits=4 -dTextAlphaBits=4 -q';

    emit 'Making maps for web';

    foreach my $filespec ( @{ $params{files} } ) {

        my $filename = filename($filespec);
        next unless $filename =~ /[.]pdf\z/si;

        my %nameparts = %{ _mapname_pieces($filename) };

        emit_over $nameparts{lines} if not $verbose;

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
                emit_text "Successfully rasterized: $display_path";
            }
        }
        else {
            my $display_path
              = _display_path( $first_jpeg_spec, $filespec, $path_to_remove );
            die "Couldn't rasterize: $display_path\n"
              . "system returned $result";
        }

        foreach my $output_line (@output_lines) {
            my $outfile = $output_folder->make_filespec("$output_line.jpeg");
            _copy_file( $filespec, $outfile, $path_to_remove, $verbose );
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

    my @lines = split( /_/s, $lines );
    foreach (@lines) {
        $_ = lc($_) unless length($_) >= $LINE_NAME_LENGTH;
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
        #        when (/\A\d+\z/s) {
        #            $ver = "v$ver";
        #        }
    }

    return "$lines-$date-$ver.$ext";

} ## tidy end: sub normalize_filename

sub filename_is_valid {

    my $filename = shift;

    my $year_re = '(?:19[89]\d|20\d\d)';
    # year - another Y2100 problem
    my $month_re = '(?:0[123456789]|1[012])';
    # numeric month

    return $filename =~ m{
              $LINE_NAME_RE
                  # one transit line 
              (?:_$LINE_NAME_RE)* 
                  # zero or more transit lines, separated by _
              (?:=\w+)
                  # one token starting with = and containing word characters
              \-
                  # hyphen separating lines and date
              $year_re
                  # year (another Y2100 problem!)
              _$month_re
                  # underscore followed by numeric month
              \-
                  # hyphen separating date and version
              \w+
                  # version (arbitrary word characters)
              [.]\w+
                  # extension
              }sx;

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

    my %params             = validate( @_, $copylatest_spec );
    my $fullname_folder    = $params{fullname};
    my $linesname_folder   = $params{linesname};
    my $web_folder         = $params{web};
    my $defining_extension = $params{defining_extension};
    my $verbose            = $params{verbose};

    my $repository = $params{repository};

    emit 'Getting list of folders in map repository';
    my @folder_objs = $repository->children;
    emit_done;

    my ( $is_an_active_map_r, $is_an_active_line_r )
      = _active_maps( $repository, $params{active_map_file} );

    my %latest_date_of;
    my %latest_ver_of;

    emit 'Copying files in repository folders';

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

        emit_over $foldername unless $verbose;

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

    emit_done;

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

    emit 'Getting list of active maps';

    my $repository = shift;
    my $filename   = shift;

    my $filespec = $repository->make_filespec($filename);

    open my $fh, '<', $filespec
      or croak "Can't open $filespec for reading: $OS_ERROR";

    my ( %is_an_active_map, %is_an_active_line );

    while (<$fh>) {
        chomp;
        $is_an_active_map{$_} = 1;
        s/=.*//;
        $is_an_active_line{$_} = 1;
    }

    emit_done;

    return \%is_an_active_map, \%is_an_active_line;
} ## tidy end: sub _active_maps

sub _file_action {

    my ( $from, $to, $path, $verbose, $action_r, $actionword ) = @_;

    if ( $action_r->( $from, $to ) ) {
        if ($verbose) {
            my $display_path = _display_path( $from, $to, $path );
            emit_text "Successful $actionword: $display_path";
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

#sub _copy_file {
#
#    my ( $from, $to, $path, $verbose ) = @_;
#    my $display_path;
#    $display_path = _display_path(@_) if $verbose;
#
#    if ( File::Copy::copy( $from, $to ) ) {
#        emit_text "Copied: $display_path" if $verbose;
#    }
#    else {
#        die "Couldn't copy: $display_path\n$OS_ERROR";
#    }
#    return;
#}
#
#sub _move_file {
#    my ( $from, $to, $path, $verbose ) = @_;
#    my $display_path;
#    $display_path = _display_path(@_) if $verbose;
#
#    if ( File::Copy::move( $from, $to ) ) {
#        emit_text "Moved: $display_path" if $verbose;
#    }
#    else {
#        die "Couldn't move: $display_path\n$OS_ERROR";
#    }
#    return;
#}

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
