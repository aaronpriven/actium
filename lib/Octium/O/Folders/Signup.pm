package Octium::O::Folders::Signup 0.012;

# Object-oriented interface to the signup folder

use Actium('class');
use Octium;

const my $BASE_CLASS => 'Octium::O::Folder';
extends $BASE_CLASS;

#around BUILDARGS => sub {
#    my $orig  = shift;
#    my $class = shift;

around BUILDARGS ( $orig, $class: @ ) {

    my $first_argument = shift;
    my @rest           = @_;

    # Allow for non-hashref argument

    my $params_r;
    if ( ref($first_argument) eq 'HASH' ) {
        $params_r = $first_argument;
    }
    else {
        $params_r = { $first_argument, @rest };
    }

    # build folderlist argument from base, signup, and subfolders

    my ( $base, $signup );

    if ( exists $params_r->{base} and defined $params_r->{base} ) {
        $base = $params_r->{base};
    }
    else {
        croak "No base specified to " . __PACKAGE__;
    }

    if ( exists $params_r->{signup} and defined $params_r->{signup} ) {
        $signup = $params_r->{signup};
    }
    else {
        croak "No signup specified to " . __PACKAGE__;
    }

    if ( exists $params_r->{subfolders} ) {
        my $subfolders = $params_r->{subfolders};
        $params_r->{subfolders} = $class->split_folderlist($subfolders);
        $params_r->{folderlist} = [ $base, $signup, $subfolders ];
    }
    else {
        $params_r->{folderlist} = [ $base, $signup ];
        $params_r->{subfolders} = [];
    }
    # all arrayrefs in folderlist will be flattened in the Octium::O::Folder
    # BUILDARGS

    return $class->$orig($params_r);

};    ## tidy end: BUILDARGS

has base => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has signup => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

#around load_sqlite => sub {
around load_sqlite ($orig, $self: $default_subfolder, $db_class, $params_r = +{} ) {
    #    my ( $orig, $self, $default_subfolder, $db_class, $params_r ) = @_;
    if ( not exists( $params_r->{db_folder} ) and $self->cache ) {
        $params_r->{db_folder} = $self->cache;
    }
    $self->$orig( $default_subfolder, $db_class, $params_r );

}

has cache => (
    is  => 'ro',
    isa => 'Maybe[Str]',
);

has subfolderlist_r => (
    reader   => '_subfolderlist_r',
    init_arg => 'subfolders',
    isa      => 'ArrayRef[Str]',
    required => 1,
    traits   => ['Array'],
    handles  => { subfolders => 'elements', _subfolder_count => 'count', },
);

# Because subfolderlist comes from File::Spec->splitdir, it may
# have elements that are the empty string. I don't think
# this will matter.

# for below, see big comment in Octium::O::Folder

override original_parameters {

    #    my $self     = shift;
    my $params_r = super();
    delete $params_r->{folderlist};
    $params_r->{base}       = $self->base;
    $params_r->{signup}     = $self->signup;
    $params_r->{subfolders} = $self->_subfolderlist_r;
    $params_r->{cache}      = $self->cache;

    return $params_r;

};

override subfolderlist_reader {'_subfolderlist_r'};
override subfolderlist_init_arg {'subfolders'};

override display_path {
    #    my $self       = shift;
    my @subfolders = $self->subfolders;
    if (@subfolders) {
        return File::Spec->catdir(@subfolders) . " in signup " . $self->signup;
    }
    return "signup " . $self->signup;

};

sub signup_obj {

    my $self  = shift;
    my $class = blessed $self;
    return $self unless $self->_subfolder_count;

    return $class->new(
        {   base   => $self->base,
            signup => $self->signup,
            cache  => $self->cache,
            volume => $self->volume,
        }
    );
}

sub base_obj {
    my $self = shift;

    return $BASE_CLASS->new(
        {   folderlist => $self->base,
            volume     => $self->volume,
        }
    );

}

method folder ( :$phylum!, :$collection!, :$format ) {
    # at the moment, nothing special is done with these... but that could
    # change

    return $self->signup_obj->subfolder( $phylum, $collection )
      if ( not defined $format or $format eq $EMPTY );

    return $self->signup_obj->subfolder( $phylum, $collection, $format );
}

Actium::immut;

1;

__END__

=head1 NAME

Octium::O::Folders::Signup - Signup folder objects for the Actium
system

=head1 VERSION

This documentation refers to version 0.010

=head1 SYNOPSIS

 use Octium::O::Folders::Signup;

 $signup = Octium::O::Folders::Signup->new(
      base => '/Actium/signups/',
      signup => 'w00',
    );
 $skeds = $signup->subfolder('skeds');
 # or alternatively
 $skeds = Octium::O::Folders::Signup->new(
      base => '/Actium/signups/',
      signup => 'w00',
      subfolders => ['skeds'],
    );
 # $skeds is the same thing

 $oldsignup = Octium::O::Folders::Signup->new(
    { base => '/Actium/signups/' , signup => 'f08'}
    );
 $oldskeds = $oldsignup->subfolder('skeds');
 $filespec = $oldskeds->make_filespec('10_EB_WD.txt');
 # $filespec is something like /Actium/signups/f08/skeds/10_EB_WD.txt

 @files = $skeds->glob_files('*.txt');
 # @files contains all the *.txt files in the 'skeds' folder
 # in the command-line signup folder

=head1 DESCRIPTION

=head2 Introduction

Octium::O::Folders::Signup provides an object-oriented interface to the
system of signup folders.

(They are referred to here as "folders" rather than "directories"
mainly because "dir" is more commonly used within the Actium system as
an abbreviation for "direction", and I wanted to avoid ambiguity.)

A "signup" is the period that a particular set of transit schedules is
in effect.  (It is named after the drivers' activity of "signing up"
for a new piece of work for that period.)

Actium uses a series of folders for storing data about each signup.
Each signup has a folder, and then within that there is a series of
subfolders containing different types of data (e.g., processed 
schedule files, files from the Hastus AVL Standard interface, and so
forth).

This module is designed to make it easier to locate the signup folders
and the folders within them. It inherits from Octium::O::Folder and its
objects are different almost exclusively in object construction, and
not in use.

This module is where the base, signup, and cache options are used.

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

This module is designed to allow access to the folders  under the
"signups" folder.

For the purposes of this module, there are three levels that are
important:

=over

=item Base folder

The base folder is, in this example, equivalent to /Actium/signups:
it's the folder where all the folders of signup data are stored.
(Arguably "base folder" would more likely apply to "/Actium", but I
can't think of a better name for the base folder than that.)

The base folder is a required attribute of this object. The module
Octium::Cmd::Config::Signup contains utilities for selecting the base
folder from command line programs, using configuration files,
environment variables, or commnad-line options.

=item Signup folder

The data for each signup is stored in a subfolder of the base folder.
This folder is usually named after the period of time when the signup
becomes effective ("w08" meaning "Winter 2008", for example).

The signup folder is a required attribute of this object. The module
Octium::Cmd::Config::Signup contains utilities for selecting the base
folder from command line programs, using configuration files,
environment variables, or commnad-line options.

=item Subfolder

Subfolders are found under the signup folder. Most of the input and
output files used by Actium are stored in these subfolders.  This is
generally equivalent to a subset of data for that particular signup:
the data from the Hastus AVL Standard Interface in "hasi", HTML
schedules in "html", and so forth. Occasionally some data will be found
further down in the folder tree, so several different subfolders will
be needed. The new() and subfolder() calls both can take a series of
folder names.

Subfolders are specified in the arguments to the "new" class method or
the "subfolder" object method call.

=back

=head1 OBJECT CONSTRUCTION

Octium::O::Folders::Signup objects are created using the B<new>
constructor inherited from Moose. Alternatively, they can be cloned
from an existing Octium::O::Folders::Signup object, using B<subfolder>.

The B<new> constructor takes named arguments either in a hash or hash
reference.

The B<subfolder> constructor takes named arguments in a hash reference.
If it is passed non-reference arguments, the arguments given are
considered part of the I<subfolders> argument. So this:

 my $folder = $signup->new($folder1, $folder2 )
 
is a shortcut for this:

 my $folder =  $signup->subfolder(
     {subfolders => [ $folder1, $folder2 ]}
   );

=head2 NAMED ARGUMENTS

=over

=item I<base>

This is the base folder, described above.

=item I<signup>

This is the signup folder, described above.

=item I<subfolders>

This can be a single string with an entire path ('path/to/folder'), a
reference to a list containing that single string (['path/to/folder']),
a series of strings each with a folder name (['path' , 'to' ,
'folder']), or a combination (['path/to' , 'folder']).
Octium::O::Folder splits the pieces into individual folders for you.

If none is supplied, Octium::O::Folders::Signup will represent the
signup folder itself.

=item I<cache>

If supplied, specifies a default folder where SQLite databases are to
be stored.

SQLite will not work if its database is on a networked filesystem. This
option is provided to allow the signup folder to be on a networked
filesystem while storing the SQLite databases locally.

=item I<volume>

=item I<must_exist>

See L<Octium::O::Folder|Octium::O::Folder> .

=back

=head1 METHODS

Most methods are inherited from L<Octium::O::Folder|Octium::O::Folder>
and are described in the documentation for that module.

=over

=item B<$obj-E<gt>load_sqlite()>

=item B<$obj-E<gt>load_hasi()>

Identical to their Octium::O::Folder counterparts, except that if
present, the cache folder is used instead of the SQLite default.

=item B<$obj-E<gt>base_obj()>

Returns an object representing the base folder of this object. Since
the base folder is, by definition, not a signup folder, this is not an
Octium::O::Folders::Signup object, but instead an
L<Octium::O::Folder|Octium::O::Folder> object.

=item B<$obj-E<gt>signup_obj()>

Returns an object representing the signup folder of this object. Useful
if, in a method or subroutine, one is only passed an object
representing a signup subfolder and one needs the signup folder itself.

=back

=head1 DIAGNOSTICS

See L<Octium::O::Folder|Octium::O::Folder> for most diagnostics.

=over

=item No base specified

=item No signup specified

A call to new() was made, but no base folder or signup folder was
specified.

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Moose

=item MooseX::StrictConstructor

=item Const::Fast

=item Octium::O::Folder

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

