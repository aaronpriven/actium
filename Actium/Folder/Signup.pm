# Signup.pm
# Object-oriented interface to the signup folder

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::Folder::Signup 0.001;

use Actium::Options qw(add_option option is_an_option);
use Carp;
use File::Spec;
use Readonly;
use FindBin;

use Moose;
use MooseX::StrictConstructor;

extends 'Actium::Folder';

Readonly my $BASE_ENV   => 'ACTIUM_BASE';
Readonly my $SIGNUP_ENV => 'ACTIUM_SIGNUP';
Readonly my $CACHE_ENV => 'ACTIUM_CACHE';

Readonly my $LAST_RESORT_BASE =>
  File::Spec->catdir( $FindBin::Bin, File::Spec->updir(), 'signups' );
Readonly my $DEFAULT_HSA_FILENAME => 'hsa.storable';

Readonly my $DEFAULT_BASE =>
  ( $ENV{$BASE_ENV} // $LAST_RESORT_BASE );
Readonly my $DEFAULT_SIGNUP => ( $ENV{$SIGNUP_ENV} // 'none' );

add_option( 'base=s',
    'Base folder (normally [something]/Actium/signups); current default is "'
      . $DEFAULT_BASE
      . '"' );

add_option( 'signup=s',
        'Signup. This is the subfolder under the base folder. Typically'
      . qq<something like "f08" (meaning Fall 2008). >
      . qq<Current default is "$DEFAULT_SIGNUP"> );

add_option( 'cache=s',
        'Cache folder. Files (like SQLite files) that cannot be stored '
      . 'on network filesystems are stored here. Defaults to the location '
      . 'of the files being cached.' );

around BUILDARGS {
    my $orig           = shift;
    my $class          = shift;
    my $first_argument = shift;
    my @rest           = @_;

    # Allow for non-hashref argument

    my $params_r;
    if ( ref($first_argument) eq 'HASH' ) {
        $params_r = $first_argument;
    }
    else {
        $params_r = { subfolders => [ $first_argument, @rest ] };
    }

    # build folderlist argument from base, signup, and subfolders
    # (Actium::Folder takes care of dividing pieces that have several
    # folders, like "/users/yourname/actium/base", into individual pieces

    my $base   = $params_r->{base}   // $class->_build_base;
    my $signup = $params_r->{signup} // $class->_build_signup;

    if ( exists $params_r->{subfolders} ) {
        my $subfolders = $params_r->{subfolders};
        if ( ref($subfolders) eq 'ARRAY' ) {
            $params_r->{folderlist} = [ $base, $signup, @{$subfolders} ];
        }
        else {
            $params_r->{folderlist} = [ $base, $signup, $subfolders ];
        }
        delete $params_r->{subfolders};
    }
    else {
        $params_r->{folderlist} = [ $base, $signup ];
    }

    $params_r->{must_exist} = 0 unless $params_r->{must_exist};

    return $class->$orig($params_r);

} ## tidy end: BUILDARGS

has base => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub _build_base {
    # invoked from BUILDARGS
    return option('base') // $ENV{$BASE_ENV} // $LAST_RESORT_BASE;
}

has signup => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

sub _build_signup {
    # invoked from BUILDARGS
    return option('signup') if option('signup');
    return $ENV{$BASE_ENV}  if $ENV{$BASE_ENV};
    croak 'No signup folder specified';
}

around load_sqlite => sub {
    my ( $orig, $self, $default_subfolder, $db_class, $params_r ) = @_;
    if ( not exists( $params_r->{db_folder} ) ) {
        $params_r->db_folder = option('cache');
    }
    $self->$orig( $default_subfolder, $db_class, $params_r );

};

has cache => (
   is => 'ro' ,
   isa => 'Str' ,
   builder => '_build_cache',
   lazy => 1,
);

sub _build_cache {
    return option('cache') if option('cache');
    return $ENV{$CACHE_ENV}  if $ENV{$CACHE_ENV};
    return;
}

__END__

=head1 NAME

Actium::Folder::Signup - Signup folder objects for the Actium system

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Signup;

 $signup = Actium::Signup->new();
 $skeds = $signup->subfolder('skeds');
 # or alternatively
 $skeds = Actium::Signup->new('skeds') # same thing

 $rawskeds = Actium::Signup->subfolder('rawskeds');

 $oldsignup = Actium::Signup->new({SIGNUP => 'f08'});
 $oldskeds = $oldsignup->subfolder('skeds');

 $filespec = $oldskeds->make_filespec('10_EB_WD.txt');
 # $filespec is something like /Actium/signups/f08/skeds/10_EB_WD.txt

 @files = $skeds->glob_files('*.txt');
 # @files contains all the *.txt files in the 'skeds' folder
 # in the command-line signup folder

=head1 DESCRIPTION

=head2 Introduction

Actium::Folder::Signup provides an object-oriented interface to the system of
signup folders.

(They are referred to here as "folders" rather than "directories" mainly
because "dir" is more commonly used within the Actium system as an 
abbreviation for "direction", and I wanted to avoid ambiguity.)

A "signup" is the period that a particular set of transit schedules is in 
effect.  (It is named after the drivers' activity of "signing up" for a new
piece of work for that period.) 

Actium uses a series of folders for storing data about each signup.
Each signup has a folder, and then within that there is a series of
subfolders containing different types of data (e.g., processed 
schedule files, files from the Hastus AVL Standard interface, and so
forth).

This module is designed to make it easier to locate the signup folders
and the folders within them. It inherits from Actium::Folder and its objects
are different almost exclusively in object construction, and not in use.

This module is where the base, signup, and cache options are set.

=head2 Actium Folder Structure

The typical Actium folder structure looks something like this:

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

This module is designed to allow access to the folders 
under the "signups" folder.

For the purposes of this module, there are three levels that are important:

=over

=item Base folder

The base folder is, in this example, equivalent to /Actium/signups: it's
the folder where all the folders of signup data are stored.
(Arguably "base folder" would more likely apply to "/Actium", but I can't
think of a better name for the base folder than that.)

The base folder is specified as follows (in the following order of
precedence):

=over

=item *

In the "base" argument to the "signup" method call

=item *
In the command line with the "-base" option

=item *
By the environment variable "ACTIUM_BASE".

=back

If none of these are set, Actium::Folder::Signup uses L<FindBin|FindBin> to 
find the folder 
where the script is running (in the above example, /Actium/bin), and 
sets the base folder to "signups" in the script folder's parent folder. 
In other words, it's something like "/Actium/bin/../signups". In the normal
case where the "bin" folder is in the same folder as the Actium data
this means it will all work fine without any specification of the base 
folder. If not, then it will croak. 

=item Signup folder

The data for each signup is stored in a subfolder of the base folder.
This folder is usually named after the period of time when the signup
becomes effective ("w08" meaning "Winter 2008", for example). 

The signup folder is specified as follows (in the following order of
precedence):

=over

=item *
In the "signup" argument to the "signup" method call

=item *
In the command line with the "-signup" option

=item *
By the environment variable "ACTIUM_SIGNUP".

=back

If none of these are present, then Actium::Signup 
will croak "No signup folder specified."

=item Subfolder

Subfolders are found under the signup folder. Most of the input
and output files used by Actium are stored in these subfolders. 
This is generally equivalent to a subset of data for that particular signup:
the data from the Hastus AVL Standard Interface in "hasi", HTML schedules in 
"html", and so forth. Occasionally some data will be found further down in the
folder tree, so several different subfolders will be needed. The 
new() and subfolder() calls both can take a series of folder names.

Subfolders are specified in the arguments to the "new" class method
or the "subfolder" object method call.

=back

=head1 COMMAND-LINE OPTIONS AND ENVIRONMENT VARIABLES

=over

=item -base (option)

=item ACTIUM_BASE (environment variable)

These supply a base folder used when the calling program doesn't
specify one.

=item -signup (option)

=item ACTIUM_SIGNUP (environment variable)

These supply a signup folder used when the calling program doesn't
specify one.

=item -cache (option)

=item ACTIUM_CACHE (environment variable)

These supply a cache folder used when the calling program doesn't
specify one. See the method "cache" below.

=back

=head1 OBJECT CONSTRUCTION

Actium::Folder::Signup objects are created using the B<new> constructor 
inherited from Moose. Alternatively, they can be cloned from an existing 
Actium::Folder::Signup object, using B<subfolder>.

For either method, if the first argument is a hash reference, 
it is taken as a reference to named
arguments. If not, the arguments given are considered part of the 
I<subfolders> argument. So this:

 my $folder = Actium::Folder::Signup->new($folder1, $folder2 )
 
is a shortcut for this:

 my $folder = Actium::Folder->new({subfolders => [ $folder1, $folder2 ]})

=head2 NAMED ARGUMENTS

=over

=item I<base>

This is the base folder, described above.

=item I<signup>

This is the signup folder, described above.

=item I<subfolders>

This can be a single string with an entire path ('path/to/folder'), 
a reference to a list containing that single string (['path/to/folder']),
a series of strings each with a folder name (['path' , 'to' , 'folder']),
or a combination (['path/to' , 'folder']). Actium::Folder splits the pieces
into individual folders for you.

If none is supplied, Actium::Folder::Signup will represent the signup
itself.

=item I<cache>

If supplied, specifies a default folder where SQLite databases are to
be stored.

SQLite will not work if its database is on a networked filesystem. This option
is provided to allow the signup folder to be on a networked filesystem
while storing the SQLite databases locally.

=item I<volume>

=item I<must_exist>

See L<Actium::Folder|Actium::Folder> .

=back

=head1 METHODS

Most methods are inherited from L<Actium::Folder|Actium::Folder> and are 
described in the documentation for that module.

=over

=item B<$obj-E<gt>load_sqlite()>

=item B<$obj-E<gt>load_xml()>

=item B<$obj-E<gt>load_hasi()>

Identical to their Actium::Folder counterparts, except that if present, the 
Actium::Folder::Signup cache folder
(specified on the command line, or in the cache argument to 
Actium::Folder::Signup->new ) is used instead of the SQLite default.

=back

=head1 DIAGNOSTICS

See L<Actium::Folder|Actium::Folder> for most diagnostics.

=over

=item No signup folder specified

A call to new() was made, but no signup was specified either on the
command line, in the environment, or in the method call.

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Moose

=item Moose::StrictConstructor

=item Readonly

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 