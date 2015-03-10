# Folder.pm
# Objects representing folders (directories) on disk

# Subversion: $Id$

# legacy stage 4

use 5.012;
use strict;

package Actium::O::Folder 0.008;

use Moose;
use MooseX::StrictConstructor;

use namespace::autoclean;

use Actium::Constants;
use Actium::Term(':all');
use Actium::Util('flatten');
use Carp;
use English '-no_match_vars';
use File::Spec;
use File::Glob ('bsd_glob');

use Params::Validate qw(:all);

use overload (
    q[""]    => '_stringify',
    fallback => 1,
);

# class or object methods

has folderlist_r => (
    reader   => '_folderlist_r',
    init_arg => 'folderlist',
    isa      => 'ArrayRef[Str]',
    required => 1,
    traits   => ['Array'],
    handles  => { folders => 'elements' },
);

# Because folderlist comes from File::Spec->splitdir, it may
# have elements that are the empty string. I don't think
# this will matter.

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

    my $path_so_far = File::Spec->rootdir;
    my @parents;

    while (@folders) {
        $path_so_far = File::Spec->catdir( $path_so_far, shift @folders );
        push @parents, File::Spec->catpath( $volume, $path_so_far, $EMPTY_STR );
    }

    return @parents;
}

has volume => (
    default => $EMPTY_STR,
    isa     => 'Str',
    is      => 'ro',
);

has path => (
    is       => 'ro',
    isa      => 'Str',
    init_arg => undef,
    builder  => '_build_path',
    lazy     => 1,
);

sub _stringify {
    my $self = shift;
    return $self->path;
}

sub _build_path {
    my $self = shift;
    return File::Spec->catpath( $self->volume,
        File::Spec->catdir( File::Spec->rootdir, $self->folders ) );
}

sub display_path {
    my $self = shift;
    return $self->path;
}

sub subfolder_path {
    my $self    = shift;
    my $subpath = shift;
    return File::Spec->catpath( $self->volume,
        File::Spec->catdir( File::Spec->rootdir, $self->folders, $subpath ) );
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
    if ( ref($first_argument) eq 'HASH' ) {
        $hashref = $first_argument;
    }
    else {
        $hashref = { folderlist => [ $first_argument, @rest ], };
    }

    # If relative, add the current working directory to the beginning
    # of the folder list

    my @folders = @{ $class->split_folderlist( $hashref->{folderlist} ) };

    my $volume = $EMPTY_STR;
    $volume = $hashref->{volume} if exists $hashref->{volume};

    my $temppath = File::Spec->catpath( $volume, File::Spec->catdir(@folders) );

    if ( not File::Spec->file_name_is_absolute($temppath) ) {

        # is relative
        require Cwd;
        unshift @folders, Cwd::getcwd();
    }

    $hashref->{folderlist} = $class->split_folderlist(@folders);

    return $class->$orig($hashref)

};

sub split_folderlist {

    # splits folder list into components (e.g., "path/to" becomes qw<path to>).
    # Takes either an array of strings, or an arrayref of strings.

    my $self     = shift;
    my $folder_r = flatten(@_);

    my @new_folders;
    foreach my $folder ( @{$folder_r} ) {

        my $canon = File::Spec->canonpath($folder);
        if ( $canon eq $EMPTY_STR ) {
            push @new_folders, $EMPTY_STR;
        }
        else {
            my @split = File::Spec->splitdir($canon);
            push @new_folders, @split;
        }

    }

    return \@new_folders;

#    $folder_r = [ map { File::Spec->splitdir( File::Spec->canonpath($_) ) } @{$folder_r} ];
#    return $folder_r;

}    ## tidy end: sub split_folderlist

sub BUILD {
    my $self = shift;
    my $path = $self->path;

    if ( $self->must_exist ) {
        croak qq<Folder "$path" not found>
          unless -d $path;
    }
    elsif ( not( -d $path ) ) {
        my @paths = ( $self->parents, $self->path );

        foreach my $path_so_far (@paths) {
            if ( not -d $path_so_far ) {
                mkdir $path_so_far
                  or croak qq<Can't make folder "$path_so_far": $OS_ERROR>;
            }
        }
    }

    return;

}    ## tidy end: sub BUILD

#######################
### CLONING

sub original_parameters {
    my $self = shift;

    my $params_r = {
        folderlist => $self->_folderlist_r,
        volume     => $self->volume,
    };

    return $params_r;

    # must_exist deliberately omitted -- must be specified
    # explicitly for each folder

}

=begin comment

The idea here is that Actium::O::Folder has a single list of folders,
"folderlist," which is specified in the new() constructor and
subfolder() cloner. In the cloner, the specified folderlist is added to the
old one to form the complete new folderlist.

The Actium::O::Folders::Signup subclass, however, has a second list of folders 
that is primary -- "subfolders". The idea is that the subfolders
are kept separately from the base and signup folders.

So what this does is as follows:

1) It determines what the attribute is that is used as the primary set 
of folders. This is retreived by the method subfolder_attribute, which is
'folderlist' in this class but overridden in other classes.

2) It gets the list of subfolders from either the argument list, if it
is using non-named arguments, or from the named arguments if they are used.
All other non-named arguments are preserved.

3) It gets the original parameter settings. These aren't the actual
parameter settings passed to the constructor -- we don't want to 
copy the must_exist attribute, for example. Just whatever would be 
useful in cloning.

4) It adds the new subfolders to the old folders.

5) It copies all other old named arguments to the new named argument list.

6) It returns a new object of the proper type.

I tried doing this with $object->meta->clone_object but it didn't seem
to set up the new object properly, so here we are.

=end comment

=cut

sub subfolderlist_reader   { '_folderlist_r' }
sub subfolderlist_init_arg { 'folderlist' }

sub subfolder {
    my $self = shift;

    my $init_arg = $self->subfolderlist_init_arg;
    my $reader   = $self->subfolderlist_reader;

    my ( $params_r, @subfolders );

    if ( ref( $_[0] ) eq 'HASH' ) {
        $params_r   = { %{ $_[0] } };           # new ref
        @subfolders = $params_r->{$init_arg};
        delete $params_r->{$init_arg};
    }
    else {
        $params_r   = {};
        @subfolders = @_;
    }

    croak 'No folders passed to method "subfolder"'
      unless @subfolders;

    my $original_params_r = $self->original_parameters;

    $params_r->{$init_arg} = [ $self->$reader, @subfolders ];

    # constructor will flatten the arrayrefs into an array

    delete $original_params_r->{$init_arg};

    while ( my ( $key, $value ) = each %{$original_params_r} ) {
        $params_r->{$key} = $value unless exists $params_r->{$key};
    }

    my $class = blessed($self);
    return $class->new($params_r);

}    ## tidy end: sub subfolder

sub new_from_file {

    # takes a filename and creates a new Actium::O::Folder from the path part
    # must_exist is not implemented yet
    my $class    = shift;
    my $filespec = shift;
    $filespec = File::Spec->rel2abs($filespec);
    my ( $volume, $path, $filename ) = File::Spec->splitpath($filespec);
    
    my $folder = $class->new( { folderlist => $path, volume => $volume } );
    return ( $folder, $filename );

}

########################
### FILE NAMES, GLOBBING FILES, ETC.

sub make_filespec {

    # returns a filename in this folder
    my $self     = shift;
    my $filename = shift
      or croak 'No file specified to make_filespec';

    return File::Spec->catfile( $self->path, $filename );

}

sub glob_files {
    my $self    = shift;
    my $pattern = shift || q{*};
    my @results = bsd_glob( File::Spec->catfile( $self->path, $pattern ) );

    return @results unless File::Glob::GLOB_ERROR;

    croak "Error while globbing pattern '$pattern': $!";

}

sub glob_plain_files {
    my $self = shift;
    return grep { -f $_ } $self->glob_files(@_);
}

sub children {

    # make subfolders
    my $self = shift;
    my $path = $self->path;

    my @folderpaths = grep { -d } $self->glob_files(@_);
    my @foldernames = map { File::Spec->abs2rel( $_, $path ) } @folderpaths;

    # removes $path from each @foldername. If the path is /a and the
    # current folderpath is /a/b, returns b

    return map { $self->subfolder($_) } @foldernames;

}

#######################
### READ OR WRITE MISC FILES IN THIS FOLDER

sub slurp_write {

    my $self     = shift;
    my $string   = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    emit("Writing $filename...");

    require File::Slurp::Tiny;
    File::Slurp::Tiny::write_file( $filespec, $string,
        binmode => ':encoding(UTF-8)' );

    emit_done;

}

sub json_retrieve {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    croak "$filespec does not exist"
      unless -e $filespec;

    emit("Retrieving $filename");

    require File::Slurp::Tiny;
    my $json_text =
      File::Slurp::Tiny::read_file( $filespec, binmode => ':encoding(UTF-8)' );

    require JSON;
    my $data_r = JSON::from_json($json_text);

    emit_done;

    return $data_r;

}    ## tidy end: sub json_retrieve

sub json_store {

    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    emit("Storing $filename...");

    require JSON;
    my $json_text = JSON::to_json($data_r);

    require File::Slurp::Tiny;
    File::Slurp::Tiny::write_file( $filespec, $json_text,
        binmode => ':encoding(UTF-8)' );

    emit_done;

}

sub json_store_pretty {

    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    emit("Storing $filename...");

    require JSON;
    my $json_text = JSON::to_json( $data_r, { pretty => 1, canonical => 1 } );

    require File::Slurp::Tiny;
    File::Slurp::Tiny::write_file( $filespec, $json_text,
        binmode => ':encoding(UTF-8)' );

    emit_done;

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

sub open_read {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    open my $fh, '<:encoding(UTF-8)', $filespec
      or croak "Can't open $filespec for reading: $OS_ERROR";

    return $fh;

}

sub open_write {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    open my $fh, '>:encoding(UTF-8)', $filespec
      or croak "Can't open $filespec for writing: $OS_ERROR";

    return $fh;

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
    if ( exists $params{subfolder} ) {
        $subfolder = $params{subfolder};
        delete $params{$subfolder};
    }
    else {
        $subfolder = $default_subfolder;
    }

    my $subfolder_is_empty = (
        ( $subfolder eq $EMPTY_STR )
          or (  ref $subfolder eq 'ARRAY'
            and @{$subfolder} == 1
            and $subfolder->[0] eq $EMPTY_STR )
    );

    if ($subfolder_is_empty) {
        $params{flats_folder} = $self->path;
    }
    else {
        $params{flats_folder} = $self->subfolder($subfolder)->path;
    }

    my $db_folder = $params{db_folder};
    if ( $db_folder and blessed $db_folder) {
        $params{db_folder} = $db_folder->path;
    }

    eval("require $database_class");

    return $database_class->new(%params);

}    ## tidy end: sub load_sqlite

sub load_hasi {
    my $self = shift;
    $self->load_sqlite( 'hasi', 'Actium::O::Files::HastusASI', @_ );
}

################################################
### READ OR WRITE FILES IN THIS FOLDER FROM OBJECTS

sub write_files_with_method {
    my $self = shift;

    my %params = validate(
        @_,
        {
            OBJECTS   => { type => ARRAYREF },
            METHOD    => 1,
            EXTENSION => 0,
            SUBFOLDER => 0,
        }
    );

    my @objects   = @{ $params{OBJECTS} };
    my $extension = $EMPTY_STR;
    if ( exists $params{EXTENSION} ) {
        $extension = $params{EXTENSION};
        $extension =~ s/\A\.*/./;

        # make sure there's only one a leading period
    }

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

    emit( "Writing $method files to " . $folder->display_path );

    my %seen_id;

    foreach my $obj (@objects) {

        my $out;

        my $id = $obj->id;
        emit_over $id;

        $seen_id{$id}++;

        $id .= "_$seen_id{$id}" unless $seen_id{$id} == 1;

        my $filename = $id . $extension;

        $folder->write_file_with_method(
            {
                OBJECT   => $obj,
                METHOD   => $method,
                FILENAME => $filename,
            }
        );

    }    ## tidy end: foreach my $obj (@objects)

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

    my $layermethod = $method . '_layers';
    if ( $obj->can($layermethod) ) {
        my $layers = $obj->$layermethod;
        binmode( $out, $layers );
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
    if ( defined $extension ) {
        $extension = ".$extension";
    }
    else {
        $extension = $EMPTY_STR;
    }

    emit( "Writing $filetype files to " . $self->display_path );

    foreach my $key ( sort keys %hash ) {

        emit_over $key;

        my $file = $self->make_filespec( $key . $extension );

        my $out = $self->open_write( $key . $extension );

        print $out $hash{$key} or die "Can't print to $file: $OS_ERROR";

        unless ( close $out ) {
            emit_error;
            die "Can't close $file for writing: $OS_ERROR";
        }

    }    ## tidy end: foreach my $key ( sort keys...)

    emit_done;

}    ## tidy end: sub write_files_from_hash

sub load_sheet {

    my $self     = shift;
    my $filename = shift;
    
    my $filespec = $self->make_filespec($filename);
    
    require Actium::O::2DArray;
    my $sheet = Actium::O::2DArray::->new_from_file($filespec);
    
    return $sheet;
    
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::O::Folder - Folder objects for the Actium system

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::O::Folder;

 $folder = Actium::O::Folder->new('/path/to/folder');

 $filespec = $folder->make_filespec('10_EB_WD.txt');
 # $filespec is something like /path/to/folder/10_EB_WD.txt

 @files = $folder->glob_files('*.txt');
 # @files contains all the *.txt files in the '/path/to/folder' folder

=head1 DESCRIPTION

Actium::O::Folder provides an object-oriented interface to folders on disk.
(They are referred to here as "folders" rather than "directories" mainly
because "dir" is more commonly used within the Actium system as an 
abbreviation for "direction", and I wanted to avoid ambiguity.)

This module is intended to make it easier to open files within folders and
create new subfolders.

It forms the base class used by 
L<Actium::O::Folders::Signup|Actium::O::Folders::Signup>, which is more likely to be
used directly in programs.

As much as possible, Actium::O::Folder uses the L<File::Spec> module in order
to be platform-independent (although Actium is tested only under Mac OS X for 
the moment).

=head1 OBJECT CONSTRUCTION

Actium::O::Folder objects are created using the B<new> constructor inherited from
Moose. Alternatively, they can be cloned from an existing Actium::O::Folder object,
using B<subfolder>, or from a file path using B<new_from_file>.

For either B<new> or B<subfolder>, if the first argument is a hash reference, 
it is taken as a reference to named
arguments. If not, the arguments given are considered part of the 
I<folderlist> argument. So this:

 my $folder = Actium::O::Folder->new($folder1, $folder2 )
 
is a shortcut for this:

 my $folder = Actium::O::Folder->new({folderlist => [ $folder1, $folder2 ]})
 
The B<new_from_file> method takes only a single argument, a file specification.
It drops the file part, if any, and creates the appropriate folder list 
(and volume). It uses File::Spec->splitpath to split the path; see 
that documentation for specifics on when the last component is treated as a
file and when it is treated as a folder. It returns a two-item list: the 
folder object and the filename portion of the file specification.
 
=head2 NAMED ARGUMENTS

=over

=item I<folderlist>

This required attribute consists of a string representing a folder path, or a 
reference to an array of strings, representing folders in a folder path.

This can be a single string with an entire path ('/path/to/folder'), or 
an array reference. The array reference can point to an array
containing that single string (['/path/to/folder']),
a series of strings each with a folder name (['path' , 'to' , 'folder']),
or a combination (['/path/to' , 'folder']). Actium::O::Folder splits the pieces
into individual folders for you.

Actium::O::Folder's I<new> constructor accepts both relative paths and absolute 
paths. If passed a relative path, adds the current working directory 
(from L<Cwd/Cwd>) to the beginning of the path.

Folder lists passed to B<subfolder> are always treated as relative to the 
folder represented by the original object.

=item I<volume>

This optional attribute to I<new> is the volume ID under operating systems 
(such as Windows) that care about it. It will be ignored under operating 
systems that don't. In B<subfolder>, the value is copied from the original
object to the new object.

=item I<must_exist>

This attribute, if set to a true value, will cause Actium::O::Folder to throw
an exception if the specified folder does not yet exist. If not set, 
Actium::O::Folder will attempt to create this folder and, if necessary, its 
parents.

Unless specified in the arguments to either B<new> or B<subfolder>, the
value will be false. The B<subfolder> routine resets the value to false,
and does not copy the value from the original object.

=back

=head1 OVERLOADING

Using an Actium::O::Folder object as a string will return the path() value.
For example,

 say "That file is in $folderobject";
 
will result in something like

 That file is in /Users/Shared/Folderpath

=head1 ATTRIBUTES

=over

=item B<< $self->folders() >>

Returns the list of folder names that, combined, make up the path to the
folder represented by this object.

=item B<< $self->folder() >>

The folder name of the folder that is represented by this object.
The same as the last element of I<< $self->folders() >>.

=item B<< $self->path() >>

The full path name of the folder represented by this object, as a string.

=item B<< $self->volume() >>

=item B<< $self->must_exist() >>

The values of the B<volume> and B<must_exist> attributes, respectively.

=back

=head1 OBJECT METHODS

=over

=item B<< $self->subfolder_path(F<path>) >>

Returns a path name to a specified subfolder under the folder -- that is,
this:

 $folder = new Actium::O::Folder ('/Users');
 $path = $folder->subfolder_path('apriven');

will yield "/Users/apriven".

Generally it might
be better to create a new folder object, but in some instances (e.g.,
when a whole series of subfolders are created) this is overkill.

=item B<< $self->make_filespec(F<filename>) >>

Takes a passed filename and returns the full path to the file in the 
folder represented by the object. (That is, turns "file.txt" into
"/path/to/folder/file.txt")

=item B<$obj-E<gt>glob_files(I<pattern>)>

Returns a list of all the files matching the glob pattern in the
folder represented by the object. If no pattern is specified, uses
"*".

=item B<$obj-E<gt>glob_plain_files(I<pattern>)>

Like B<glob_files>, except returns only plain files 
(that is, where B<-f I<file>> is true).

=item B<$obj-E<gt>store($data_r , F<filename>)>

=item B<$obj-E<gt>retrieve(F<filename>)>

Saves or retrieves a L<Storable|Storable> file (using Storable::nstore and 
Storable::retrieve) in the folder represented by the object. 
Uses Actium::Term to provide feedback to the terminal.

=item B<open_read (F<filename>)>

=item B<open_write (F<filename>)>

Opens a file for reading (using mode '<'), or writing (using mode '>'), 
in the object's folder with the current filename, throwing an exception
upon failure. Returns the open file handle. In either case, uses UTF-8
encoding.

=item B<$obj-E<gt>load_hasi({I<named arguments>>)>

Returns an Actium::O::Files::HastusASI 
object. The named arguments are:

=over

=item subfolder

An optional item representing the folder where the flat files are to be found:
either a string, or an array to a list of one or more strings.

If the empty string is provided, then the folder of the object itself is used.
Otherwise, a subfolder of the object's folder is used: either one specified
by the string or strings provided, or the default: 'hasi' for load_hasi.

=item db_folder

An optional item passed to Actium::O::Files::SQLite: the folder where the SQLite 
database will be stored.

=back

=item B<load_sqlite (I<default_subfolder>, I<database_class> , I<named_arguments>>

This method is used to do the work of the load_xml and load_hasi routines. 
The named arguments are the same as those methods. 

The default subfolder is a string or reference to a list of strings representing
subfolders of the folder of the current object.

The database class will be some perl class to be "require"d by this method,
probably composing the Actium::O::Files::SQLite role.

The named arguments are the same as those of the B<load_hasi> method, above.

=item B<$obj-E<gt>write_files_with_method({I<named arguments>})>

This routine takes a list of objects passed to it, takes the result of
an object method applied to each of those objects, and saves that result
in files in the specified folder.  The filename used will be the result
of the object's B<id> method, followed by the extension, if provided.
It takes named arguments, as follows:

=over

=item OBJECTS

A reference to an array of objects. The objects must implement an B<id> method
as well as the method passed in the METHOD argument.

=item METHOD

The name of a method the object is to perform. The results are saved
in the file.

Also, this name is used to determine the I/O layers used on the file. 
The routine looks to see whether a method 
"METHOD_layers" is implemented on the object (e.g., for a method "spaced", 
it looks for the additional method "spaced_layers"). If that method exists,
it is called, and the return value is passed to perl's binmode function.
See L<perlfunc/binmode>.

=item EXTENSION

An optional argument indicating a file extension to be appended to the 
filename, after a period.  (If omitted, no extension is used.)

=item SUBFOLDER

A folder, or series of folders, under the folder represented by this object.
This is where the series of files are to be stored.

=back

=item B<$obj-E<gt>write_file_with_method({I<named arguments>>)>

Writes the result of a single method to a file in the folder represented by
the current object. It takes named arguments as follows. All are mandatory.

=over

=item OBJECT

An object that can perform the method passed in the METHOD argument.

=item METHOD

The name of a method the object is to perform. The results are saved
in the file.

Also, this name is used to determine the I/O layers used on the file. 
The routine looks to see whether a method 
"METHOD_layers" is implemented on the object (e.g., for a method "spaced", 
it looks for the additional method "spaced_layers"). If that method exists,
it is called, and the return value is passed to perl's binmode function.
See L<perlfunc/binmode>.

=item FILENAME

The file name that the results of the method are to be saved in. It will 
be saved in the folder represented by the Actium::O::Folder object.

=back

=item B<$obj-E<gt>write_files_from_hash(I<hashref> , I<filetype> , I<extension>)>

This somewhat antiquated routine is similar to B<write_files_with_method> but
uses a hash reference instead of a series of objects. In this case, the 
arguments are positional, and all are mandatory except I<extension>.
The files are saved in the folder represented by this object.

=over

=item I<hashref>

A reference to a hash of strings.  The keys will be used as the filenames 
(with the extension, if any, appended). The values will be used as the content
of the files.

=item I<filetype>

This is a string used in describing the files in feedback to the terminal.

=item I<extension>

The file extension. If it is not empty, it is added to the filename, after
a period.

=back

=back

=head1 CLASS METHOD

=over

=item B<< $class->split_foldernames(I<foldernames>) >>

This class method takes a folder list and split it into component folders
(e.g., "path/to" becomes qw<path to>). It flattens any nested array references 
passed to it.

Mainly useful in subclasses, which would want to have their own BUILDARGS 
routines.

=head1 DIAGNOSTICS

=over

=item Folder "$path" not found
        
In creating the Actium::O::Folder object, the must_exist attribute was given
as true, but the folder was not found.

=item Can't make folder "$path": $OS_ERROR

The folder (which could be the folder of this object, or a parent folder) 
was not found on disk and it could not be created.

=item No folderlist specified to object method subfolder

The method B<subfolder> had no named argument "folderlist".

=item No file specified to make_filespec;

The method B<make_filespec> did not receive a file in its argument list.

=item $filespec does not exist

In attempting to retrieve a L<Storable|Storable> file, the file was not found.

=item Can't retreive $filespec: $OS_ERROR

=item Can't store $filespec: $OS_ERROR

An input/output error was found trying to use L<Storable> to retrieve or store
a file.

=item Can't open $file for writing: $OS_ERROR

=item Can't print to $file: $OS_ERROR

=item Can't close $file for writing: $OS_ERROR

An input/output error occurred in the L<write_file_with_method> or
L<write_files_from_hash> routines.

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Moose

=item MooseX::StrictConstructor

=item Const::Fast

=item Params::Validate

=item Actium::Constants

=item Actium::Term

=item Actium::Util

=back

The following are loaded only when necessary:

=over

=item Actium::O::Files::HastusASI

=back

=head1 NOTES

Arguably, this module should be a subclass of Path::Class::Dir, which 
provides additional functionality for largely the same purpose. 

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 
