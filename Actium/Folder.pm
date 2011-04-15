# Folder.pm
# Objects representing folders (directories) on disk

# Subversion: $Id$

# legacy stage 4

use 5.012;
use strict;

package Actium::Folder 0.001;

use Moose;
use MooseX::StrictConstructor;

use Actium::Constants;
use Actium::Types ('FolderList');
use Actium::Term(':all');
use Carp;
use English '-no_match_vars';
use File::Spec;

use Params::Validate qw(:all);

# class or object methods

has folderlist_r => (
    reader   => '_folderlist_r',
    isa      => FolderList,
    coerce   => 1,
    required => 1,
    traits   => ['Array'],
    handles  => { folders => 'elements' },
);

sub folder {
    my $self         = shift;
    my $folderlist_r = $self->_folderlist_r;
    return $folderlist_r->[-1];
}

sub parents {

    my $self    = shift;
    my $volume  = $self->volume;
    my @folders = $self->folders;
    pop @folders;    # don't return this folder, just parents

    my $path_so_far = $EMPTY_STR;
    my @parents;

    while (@folders) {
        $path_so_far =
          File::Spec->catpath( $volume,
            File::Spec->catdir( $path_so_far, shift @folders ) );
        push @parents, $path_so_far;
    }

    return @parents;
}

has volume => (
    default => $EMPTY_STR,
    isa     => 'Str',
    is      => 'ro',
);

has path => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_path',
    lazy    => 1,
);

sub _build_path {
    my $self = shift;
    return File::Spec->catpath( $self->volume,
        File::Spec->catdir( $self->folders ) );
}

has must_exist => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

#######################
### CONSTRUCTION

around BUILDARGS => sub {
    my $orig           = shift;
    my $class          = shift;
    my $first_argument = shift;
    my @rest           = @_;

    my $hashref;
    if ( ref($first_argument) ne 'HASH' ) {
        $hashref = $first_argument;
    }
    else {
        $hashref = { folderlist_r => [ $first_argument, @rest ], };
    }

    return $class->$orig($hashref)

};

sub BUILD {
    my $self = shift;
    my $path = $self->path;

    if ( $self->must_exist ) {
        croak "Directory '$path' not found"
          unless -d $path;
    }
    elsif ( -d $path ) {
        my @paths = ( $self->parents, $self->path );

        foreach my $path_so_far (@paths) {
            if ( not -d $path_so_far ) {
                mkdir $path_so_far
                  or croak "Can't make directory '$path_so_far': $!";
            }
        }
    }

    return;

}    ## tidy end: sub BUILD

#######################
### CLONING

sub subfolder {
    my $self           = shift;
    my $first_argument = shift;
    my @rest           = @_;

    my $params_r;
    if ( ref($first_argument) eq 'HASH' ) {
        $params_r = $first_argument;
    }
    else {
        $params_r = { subfolders => [ $first_argument, @rest ] };
    }

    if ( exists $params_r->{subfolders} ) {
        my $subfolders = $params_r->{subfolders};
        if ( ref($subfolders) eq 'ARRAY' ) {
            $params_r->{folderlist_r} = [ $self->folders, @{$subfolders} ];
        }
        else {
            $params_r->{folderlist_r} = [ $self->folders, $subfolders ];
        }
        delete $params_r->{subfolders};
    }

    if ( not exists $params_r->{must_exist} ) {
        $params_r->{must_exist} = 0;
    }

    return $self->meta->clone_object( $self, $params_r );

}    ## tidy end: sub subfolder

########################
### FILE NAMES, GLOBBING FILES, ETC.

sub make_filespec {

    # returns a filename in this directory
    my $self     = shift;
    my $filename = shift
      or croak 'No file specified to make_filespec';

    return File::Spec->catfile( $self->path, $filename );

}

sub glob_files {
    my $self = shift;
    my $pattern = shift || q{*};
    return glob( File::Spec->catfile( $self->path, $pattern ) );
}

sub glob_plain_files {
    my $self = shift;
    return grep { -f $_ } $self->glob_files(@_);
}

#######################
### READ OR WRITE MISC FILES IN THIS FOLDER

sub mergeread {

    # should be obsolete with Actium::Files::FMPXMLResult
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);
    require Actium::Files::Merge::Mergefiles;
    return Actium::Files::Merge::Mergefiles->mergeread($filespec);
}

sub retrieve {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    croak "$filespec does not exist"
      unless -e $filespec;

    emit("Retrieving $filename");

    require Storable;
    my $data_r = Storable::retrieve($filespec);

    unless ($data_r) {
        emit_error();
        croak "Can't retreive $filespec: $OS_ERROR";
    }

    emit_done;

    return $data_r;
}    ## tidy end: sub retrieve

sub store {
    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    emit("Storing $filename...");

    require Storable;
    my $result = Storable::nstore( $data_r, $filespec );

    unless ($result) {
        emit_error;
        croak "Can't store $filespec: $OS_ERROR";
    }

    emit_done;
}

#######################
### READ OR WRITE SQLITE FILES IN THIS FOLDER

sub load_sqlite {
    my $self              = shift;
    my $default_subfolder = shift;
    my $database_class    = shift;
    my %params            = validate(
        @_,
        {
            subfolder => 0,
            db_folder => 0,
        }
    );

    my $subfolder;
    if ( exists $params{$subfolder} ) {
        $subfolder = $params{subfolder};
        delete $params{$subfolder};
    }
    else {
        $subfolder = $default_subfolder;
    }

    if ($subfolder ne $EMPTY_STR) {
       $params{flats_folder} = $self->subfolder( $subfolder )->path;
    }

    my $db_folder = $params{db_folder};
    if ( $db_folder and blessed $db_folder) {
        $params{db_folder} = $db_folder->path;
    }

    eval("require $database_class");

    return $database_class->new(%params);

}    ## tidy end: sub _load_sqlite

sub load_xml {
    my $self = shift;
    $self->_load_sqlite( 'xml', 'Actium::Files::FMPXMLResult', @_ );
}

sub load_hasi {
    my $self = shift;
    $self->_load_sqlite( 'hasi', 'Actium::Files::HastusASI', @_ );
}

##########################
### READ OR WRITE FILES IN THIS FOLDER FROM OBJECTS

sub write_files_with_method {
    my $self = shift;

    my %params = validate(
        @_,
        {
            OBJECTS   => { type => ARRAYREF },
            METHOD    => 1,
            EXTENSION => 1,
            SUBFOLDER => 0,
        }
    );

    my @objects   = @{ $params{OBJECTS} };
    my $extension = $params{EXTENSION};
    my $method    = $params{METHOD};
    my $subfolder = $params{SUBFOLDER};

    my $folder;
    if ($subfolder) {
        $folder = $self->subfolder($subfolder);
    }
    else {
        $folder = $self;
    }

    my $count;

    emit( "Writing $method files to " . $folder->path );

    my %seen_id;

    foreach my $obj (@objects) {

        my $out;

        my $id = $obj->id;
        emit_over $id;

        $seen_id{$id}++;

        $id .= "_$seen_id{$id}" unless $seen_id{$id} == 1;
        $folder->write_file_with_method(
            {
                OBJECT   => $obj,
                METHOD   => $method,
                FILENAME => "$id.$extension"
            }
        );

    }

    emit_done;

}    ## tidy end: sub write_files_with_method

sub write_file_with_method {
    my $self     = shift;
    my %params   = %{ +shift };
    my $obj      = $params{OBJECT};
    my $filename = $params{FILENAME};
    my $method   = $params{METHOD};

    my $out;

    my $file = $self->make_filespec($filename);

    unless ( open $out, '>', $file ) {
        emit_error;
        croak "Can't open $file for writing: $OS_ERROR";
    }

    print $out $obj->$method() or croak "Can't print to $file: $OS_ERROR";

    unless ( close $out ) {
        emit_error;
        croak "Can't close $file for writing: $OS_ERROR";
    }

}    ## tidy end: sub write_file_with_method

sub write_files_from_hash {

    my $self = shift;

    my %hash      = %{ shift @_ };
    my $filetype  = shift;
    my $extension = shift;

    my $count;

    emit("Writing $filetype files");

    foreach my $key ( sort keys %hash ) {

        my $out;
        emit_over $key;

        my $file = $self->make_filespec( $key . ".$extension" );

        unless ( open $out, '>', $file ) {
            emit_error;
            die "Can't open $file for writing: $OS_ERROR";
        }

        print $out $hash{$key} or die "Can't print to $file: $OS_ERROR";

        unless ( close $out ) {
            emit_error;
            die "Can't close $file for writing: $OS_ERROR";
        }

    }    ## tidy end: foreach my $key ( sort keys...)

    emit_done;

}

1;

__END__

=head1 NAME

Actium::Signup - Signup directory objects for the Actium system

=head1 VERSION

This documentation refers to Actium::Signup version 0.001

=head1 SYNOPSIS

 use Actium::Signup;

 $signupdir = Actium::Signup->new();
 $skedsdir = $signupdir->subdir('skeds');
 # or alternatively
 $skedsdir = Actium::Signup->new('skeds') # same thing

 $rawskedsdir = Actium::Signup->subdir('rawskeds');

 $oldsignup = Actium::Signup->new({SIGNUP => 'f08'});
 $oldskeds = $oldsignup->subdir('skeds');

 $filespec = $oldskeds->make_filespec('10_EB_WD.txt');
 # $filespec is something like /Actium/signups/f08/skeds/10_EB_WD.txt

 @files = $skedsdir->glob_files('*.txt');
 # @files contains all the *.txt files in the 'skeds' directory
 # in the command-line signup directory

=head1 DESCRIPTION

=head2 Introduction

Actium::Signup provides an object-oriented interface to the system of
signup directories.

A "signup" is the period that a particular set of transit schedules is in 
effect.  (It is named after the drivers' activity of "signing up" for a new
piece of work for that period.) 

Actium uses a series of directories for storing data about each signup.
Each signup has a directory, and then within that there is a series of
subdirectories containing different types of data (e.g., processed 
schedule files, files from the Hastus Standard AVL interface, and so
forth).

This module is designed to make it easier to locate the signup directories
and the subdirectories within them.

=head2 Actium Directory Structure

The typical Actium directory structure looks something like this:

 Actium
 |-- bin                (the Actium program files)
 |   |-- Actium
 |-- signups
 |   |-- sp09           (the Spring 2009 signup)
 |   |   |-- exceptions
 |   |   |-- fulls
 |   |   |-- headways
 |   |   |-- hsa
 |   |   |-- html
 |   |   |-- idpoints
 |   |   |-- rawskeds
 |   |   |-- skeds
 |   |   `-- tabxchange
 |   `-- w08            (the Winter 2008 signup)
 |       |-- exceptions
 |       |-- fulls
 |       |-- headways
 |       |-- hsa
 |       |-- html
 |       |-- idpoints
 |       |-- rawskeds
 |       |-- skeds
 |       `-- tabxchange
 |-- signart
 |-- stop lists
 `-- subsidiary

This module is designed to allow access to the directories 
under the "signups" directory.

For the purposes of this module, there are three levels that are important:

=over

=item Base directory

The base directory is, in this example, equivalent to /Actium/signups: it's
the directory where all the directories of signup data are stored.
(Arguably "base directory" would more likely apply to "/Actium", but I can't
think of a better name for the base directory than that.)

The base directory is specified as follows (in the following order of
precedence):

=over

=item *

In the "BASEDIR" argument to the "signup" method call

=item *
In the command line with the "-basedir" option

=item *
By the environment variable "ACTIUM_BASEDIR".

=back

If none of these are set, Actium::Signup uses L<FindBin> to find the directory 
where the script is running (in the above example, /Actium/bin), and 
sets the base directory to "signups" in the script directory's parent directory. 
In other words, it's something like "/Actium/bin/../signups". In the normal
case where the "bin" directory is in the same directory as the Actium data
this means it will all work fine without any specification of the base 
directory. If not, then it will croak. 

=item Signup directory

The data for each signup is stored in a subdirectory of the base directory.
This directory is usually named after the period of time when the signup
becomes effective ("w08" meaning "Winter 2008", for example). 

The signup directory is specified as follows (in the following order of
precedence):

=over

=item *
In the "SIGNUP" argument to the "signup" method call

=item *
In the command line with the "-signup" option

=item *
By the environment variable "ACTIUM_SIGNUP".

=back

If none of these are present, then Actium::Signup 
will croak "No signup directory specified."

=item Subdirectory

Subdirectories are found under the signup directory. Most of the input
and output files used by Actium are stored in these subdirectories. 
This is generally equivalent to a subset of data for that particular signup:
the data from the Hastus AVL interface in "hsa", HTML schedules in "html", 
and so forth. Occasionally some data will be found further down in the
directory tree, so several different subdirectories will be needed. The 
new() and subdir() calls both can take a 

Subdirectories are specified in the arguments to the "new" class method
or the "subdir" object method call.

=back

=head1 COMMAND-LINE OPTIONS AND ENVIRONMENT VARIABLES

=over

=item -basedir (option)

=item ACTIUM_BASEDIR (environment variable)

These supply a base directory used when the calling program doesn't
specify one.

=item -signup (option)

=item ACTIUM_SIGNUP (environment variable)

These supply a signup directory used when the calling program doesn't
specify one.

=back

=head1 METHODS

=over

=item B<< $obj = Actium::Signup->new() >>

This is a class method which constructs and returns 
a new Actium::Signup object.

The B<new> method can be called in two ways. If the first argument
is a hash reference, it uses the hash as a series of named parameters.
If it is not, then it uses all arguments as a list of subdirectory
names.

The named parameters are as follows:

=over

=item BASEDIR

This is a string that specifies a base directory. See L</Base directory>.

=item SIGNUP

This is a string that specifies a signup directory. See L</Signup directory>.

=item NEWSIGNUP

This is a boolean specifying whether the signup directory must already
exist. It defaults to false, which means that the method will croak if the
signup directory does not already exist. If it is true, the signup directory
will be created.

Except when very first processing a new signup, this should be left as false.

=item SUBDIR

This is a string that specifies a single subdirectory. This parameter is
mutually exclusive with SUBDIRS. If both SUBDIR and 
SUBDIRS are provided in the same call, the method will croak.

"SUBDIR => 'skeds'" is the same as "SUBDIRS => [ 'skeds' ]".

=item SUBDIRS

This is an array reference, containing strings that specify a series of
subdirectories.  These are concatenated together to form the final
filespec. 

This parameter is
mutually exclusive with SUBDIR. If both SUBDIR and 
SUBDIRS are provided in the same call, the method will croak.

=back

If the first argument is not a hash reference, then the method uses
all arguments as a list of subdirectory names. "Actium::Signup->new('skeds')"
is the same as "Actium::Signup->new({SUBDIR => 'skeds'}).

Most of the time, usage will be very simple: Actium::Signup->new('skeds')
returns an object representing the 'skeds' subdirectory in the 
base directory and signup directory set either by default, by the
environment, or by the command line. This is usually what's needed.

=item B<< $obj->subdir() >>

The subdir() object method creates a new Actium::Signup object from
an old one. The new object represents a subdirectory of the directory
represented by the old object.  For example, if $dir_obj represents
"/Actium/signups/f08/fulls", then $dir_obj->subdir('72') represents
"/Actium/signups/f08/fulls/72". 

The arguments are a list of subdirectory names.


=item B<$obj-E<gt>get_basedir()>

=item B<$obj-E<gt>get_signup()>

=item B<$obj-E<gt>get_subdirs()>

Returns the applicable attribute, as set by the object constructor. The 
get_basedir and get_signup calls return a scalar, while the get_subdirs 
call returns a list of subdirectories.

=item B<$obj-E<gt>get_dir()>

Returns the complete path of the directory represented, e.g.
"/Actium/signups/f08/fulls/72".

=item B<$obj-E<gt>make_filespec(F<filename>)>

Takes a single string, a filename, and returns a complete filespec
with the file located in the directory represented by the object.

=item B<$obj-E<gt>glob_files(I<pattern>)>

Returns a list of all the files matching the glob pattern in the
directory represented by the object. If no pattern is specified, uses
"*".

=item B<$obj-E<gt>glob_plain_files(I<pattern>)>

Like B<glob_files>, except returns only plain files (that is, where B<-f I<file>> is true).

=item B<$obj-E<gt>mergeread(F<filename>)>

Returns an L<Actium::Files::Merge::Mergefiles> object representing the data in 
F<filename> in the directory represented by this object.

=item B<$obj-E<gt>retrieve(F<filename>)>

Using the routines in L<Actium::Files> (which themselves use L<Storable>),
retrieves a reference to a complex data structure
from the file F<filename> in the directory represented by the object.

=item B<$obj-E<gt>store($data_r , F<filename>)>

Using the routines in L<Actium::Files> (which themselves use L<Storable>),
stores a complex data structure (referred to by $data_r)
to the file F<filename> in the directory represented by the object.

=item B<$obj-E<gt>retrieve_hsa(F<filename>)>

=item B<$obj-E<gt>store_hsa($data_r , F<filename>)>

Just like B<retrieve> and B<store>, but they use 
"hsa.storable" as the default filename.

=item B<$obj-E<gt>load_xml(F<foldername>)>

Returns an Actium::Files::FMPXMLResult object, created from the files 
in the "foldername" subdirectory of the passed object. If no folder name is 
passed, defaults to "xml".

=item B<$obj-E<gt>load_hasi(F<foldername>)>

Returns an Actium::Files::HastusASI object, created from the files 
in the "foldername" subdirectory of the passed object. If no folder name is 
passed, defaults to "hasi".

=back

=head1 DIAGNOSTICS

=over

=item No signup directory specified

A call to new() was made, but no signup was specified either on the
command line, in the environment, or in the method call.

=item Directory I<directory> not found

The directory specified (either as the base directory
or as the signup directory) did not seem to exist.

=item Can't make directory I<directory>

The specified directory was not found on disk and it could not be
created.

=item Can't specify both SUBDIR and SUBDIRS to new()

The new() constructor was passed both SUBDIR and SUBDIRS parameters. 
It will accept one or the other, but not both.

=back

=head1 DEPENDENCIES

=over

=item * perl 5.010 and the core distribution

=item * Actium::Options

=item * Actium::Constants

=item * Readonly

=item * Params::Validate

=item * Actium::Files::Merge::Mergefiles

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.


