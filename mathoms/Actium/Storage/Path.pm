package Actium::Storage::Path 0.014;

# A module adding methods to Path::Tiny

use Actium;
use Kavorka ('method');
use Path::Tiny;

# Objects representing folders (directories) on disk

use Kavorka ('method');

method Path::Tiny::existing_folder ($class: @pathcomponents) {
    return path(@pathcomponents)->_must_exist;
}

method Path::Tiny::ensure_folder ($class: @pathcomponents) {
    return path(@pathcomponents)->_ensure;
}

method Path::Tiny::existing_subfolder (@pathcomponents) {
    return $self->child(@pathcomponents)->_must_exist;
}

method Path::Tiny::ensure_subfolder (@pathcomponents) {
    return $self->child(@pathcomponents)->_ensure;
}

method Path::Tiny::is_folder {
    goto &Path::Tiny::is_dir;
}

method Path::Tiny::_ensure {
    Carp::croak "$self is not a directory"
      if $self->exists and not $self->is_folder;
    $self->mkpath;
    return $self;
}

method Path::Tiny::_must_exist {
    Carp::croak "$self does not exist" unless $self->is_folder;
    return $self;
}

method Path::Tiny::enclosing_folder ($class: @pathcomponents) {
    my $path     = path(@pathcomponents);
    my $filename = $path->basename;
    $path = $path->parent;
    return ( $path, $filename );
}

method Path::Tiny::glob ($pattern //= '*') {
    require Text::Glob;
    my $regex = Text::Glob::glob_to_regex($pattern);
    return $self->children($regex);
}

method Path::Tiny::glob_files ($pattern) {
    my @children = $self->glob_files($pattern);
    @children = map { $_->is_file } @children;
    return @children;
}

method Path::Tiny::glob_folders ($pattern) {
    my @children = $self->glob_files($pattern);
    @children = map { $_->is_folder } @children;
    return @children;
}

method Path::Tiny::json_retrieve_child (@pathcomponents!) {
    my $child = $self->child(@pathcomponents);
    $child->json_retrieve;
}

method Path::Tiny::json_retrieve {
    my $basename  = $self->basename;
    my $cry       = cry("Retrieving JSON file $basename");
    my $json_text = $self->slurp_utf8;
    require JSON;    ### DEP ###
    my $data_r = JSON::from_json($json_text);
    $cry->done;
    return $data_r;
}

method Path::Tiny::json_store_child ($data_r!, @pathcomponents!) {
    my $child = $self->child(@pathcomponents);
    return $child->json_store($data_r);
}

method Path::Tiny::json_store ($data_r!) {
    my $basename = $self->basename;
    my $cry      = cry("Storing JSON file $basename...");
    require JSON;    ### DEP ###
    my $json_text = JSON::to_json( $data_r, { pretty => 1, canonical => 1 } );
    my $result = $self->spew_utf8($json_text);
    $cry->done;
    return $result;
}

method Path::Tiny::retrieve_child (@pathcomponents!) {
    my $child = $self->child(@pathcomponents);
    return $child->retrieve;
}

method Path::Tiny::retrieve {
    my $basename = $self->basename;
    my $cry      = cry("Retrieving $basename");
    require Storable;
    my $data_r = Storable::retrieve($self);
    unless ($data_r) {
        $cry->d_error();
        Carp::croak "Can't retreive $self: $!";
    }
    $cry->done;
    return $data_r;
}

method Path::Tiny::store_child ($data_r!, @pathcomponents!) {
    my $child = $self->child(@pathcomponents);
    return $child->store($data_r);
}

method Path::Tiny::store ($data_r ) {
    my $basename = $self->basename;
    my $cry      = cry("Storing $basename...");
    require Storable;
    my $result = Storable::nstore( $data_r, $self );
    unless ($result) {
        $cry->d_error;
        Carp::croak "Can't store $self: $!";
    }
    $cry->done;
    return $result;
}

method Path::Tiny::write_children_with_method ( 
    : \@objects !, 
    Str : $method !, 
    Str : $extension = $Actium::EMPTY, 
    Str : $subfolder? , 
    Str :$filename_method = 'id', 
    : \@args = [],
    ) {

    $extension =~ s/\A[.]*/./
      if ( $extension ne $Actium::EMPTY );

    my $folder = defined $subfolder ? $self->child($subfolder) : $self;

    my $cry = cry("Writing $method files to $folder");

    my %seen_id;

    foreach my $obj (@objects) {
        my $id = $obj->$filename_method;
        $cry->over( $id . q[ ] );
        $seen_id{$id}++;
        $id .= "_$seen_id{$id}" unless 1 == $seen_id{$id};
        my $filename = $id . $extension;

        $folder->write_child_with_method(
            cry      => $cry,
            object   => $obj,
            method   => $method,
            filename => $filename,
            args     => \@args,
        );
    }

    $cry->over($Actium::EMPTY);
    $cry->done;
    return;

} ## tidy end: method Path::Tiny::ensure_folder9

method Path::Tiny::write_child_with_method ( :$object!, :$method!, :$filename! ,  :\@args = [], :$cry? ) {

    my $mycry;
    if ( not defined $cry ) {
        $cry   = cry("Writing to $filename via $method");
        $mycry = 1;
    }

    my $child  = $self->child($filename);
    my $result = $object->$method(@args);

    my $layermethod = $method . '_layers';
    if ( $object->can($layermethod) ) {
        $child->spew( { binmode => $object->$layermethod }, $result );
    }
    else {
        $child->spew_utf8($result);
    }
    $cry->done if $mycry;
    return;

} ## tidy end: method Path::Tiny::existing_subfolder0

method Path::Tiny::write_children_from_hash ( :\%hash! , :$display_type? , :$extension = $Actium::EMPTY ) {

    $extension =~ s/\A[.]*/./
      if ( $extension ne $Actium::EMPTY );

    my $cry = cry("Writing $display_type files to  $self");

    foreach my $key ( sort keys %hash ) {

        $cry->over($key);

        my $filekey = $key =~ s{/}{-}gr;

        my $child = $self->child( $filekey . $extension );
        $child->spew_utf8( $hash{$key} );

    }

    $cry->over($Actium::EMPTY);
    $cry->done;
    return;

} ## tidy end: method Path::Tiny::existing_subfolder1

method Path::Tiny::sheet_retrieve_child (@pathcomponents) {
    my $child = $self->child(@pathcomponents);
    return $child->retrieve_sheet();
}

method Path::Tiny::sheet_retrieve {
    my $basename = $self->basename;
    my $cry      = cry("Retrieving XLSX file $basename");

    require Actium::O::2DArray;
    my $sheet = Actium::O::2DArray::->new_from_file($self);

    $cry->done;
    return $sheet;
}

# Actium::O::Folder equivalents

# in init_arg --
# folderlist -- this is the same as path
# must_exist -- use method existing_folder

# methods --
# folder -- same as basename with no args
# path - same as stringify
# display_path - same as stringify
# subfolder_path($subpath) - same as ->child($subpath)->stringify
# new (with must_exist) - use method existing_folder
# new (without must_exist) - use method ensure_folder
# subfolder (with must_exist) - use method existing_subfolder
# subfolder (without must_exist) - use method ensure_subfolder
# new_from_file - use method enclosing_folder
# make_filespec - use ->child
# file_exists - use ->child->is_file
# children - use glob_folders
# slurp_write - use ->child($filename)->spew_utf8
# slurp_read - use ->child($filename)->slurp_utf8
# json_retrieve - use json_retrieve_child
# json_store_pretty - use json_store_child
# store - use store_child
# retreive - use retrieve_child
# open_read_binary -- use ->child($filename)->openr_raw
# open_read -- use ->child($filename)->openr_utf8
# open_write_binary -- use ->child($filename)->openw_raw
# open_write -- use ->child($filename)->openw_utf8

# load_sqlite, load_hasi - not rewriting this as I need to rewrite
# flagspecs which is the only thing that still uses it

# write_files_from_* become write_children_from_*
# load_sheet - use sheet_retrieve_child

# glob_plain_files -- use glob_files
# glob_files -- use glob

Actium::immut;

1;

__END__

=encoding utf8

=head1 NAME

Actium::Storage::Path - Path objects for the Actium system

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium::Storage::Path (qw/path/);
 
 $path = path('/path/to/folder');

or, equivalently,

 $path = Actium::Storage::Path->new('/path/to/folder');

 $child = $path->child('10_EB_WD.txt');
 # $child is something like /path/to/folder/10_EB_WD.txt

 @files = $folder->glob_files('*.txt');
 # @files contains objects all the *.txt files in the '/path/to/folder' folder

=head1 DESCRIPTION

Actium::Storage::Path is a module providing an object-oriented interface toward
file paths.  It only adds methods to the L<Path::Tiny|Path::Tiny> module 
from CPAN.  

All methods in Path::Tiny are supported by this module,
and readers should look at Path::Tiny for complete documentation on it.
(Of exported functions, however, only "path" is supported.)

=head1 OVERLOADING

=head1 EXPORTED FUNCTIONS

=head2 path

This function is optionally exported.
It works just as the L<path function of Path::Tiny|Path::Tiny/path>. 

=head1 METHODS

Many methods provided by this module come from L<Path::Tiny|Path::Tiny> and
documentation for them can be found therein.

The following comprises documentation for methods in Actium::Storage::Path.

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

=item B<$obj-E<gt>file_exists(I<filename>)>

Returns true if a file with that name exists in the folder.


=item B<$obj-E<gt>store($data_r , F<filename>)>

=item B<$obj-E<gt>retrieve(F<filename>)>

Saves or retrieves a L<Storable|Storable> file (using Storable::nstore and 
Storable::retrieve) in the folder represented by the object. 

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

=item Actium

=item Params::Validate

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
