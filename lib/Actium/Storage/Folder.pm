package Actium::Storage::Folder 0.014;
# vimcolor: #d8d0b8

# Objects representing folders (directories) on disk
# A module adding methods to Path::Class::Dir

use Actium;
use Kavorka ('method');    ### DEP ###
use Path::Class();         ### DEP ###
use parent ('Path::Class::Dir');

## no critic 'RequirePodAtEnd'

=encoding utf8

=head1 NAME

Actium::Storage::Folder - Folder objects for the Actium system

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium::Storage::Folder (qw/folder/);
 
 $folder = Actium::Storage::Folder->new('/path/to/folder');

 $file = $folder->child('10_EB_WD.txt');
 # $file stringifies to something like /path/to/folder/10_EB_WD.txt

 @files = $folder->glob_files('*.txt');
 # @files contains objects for all the *.txt files 
 # in the '/path/to/folder' folder

=head1 DESCRIPTION

Actium::Storage::Folder provides an object-oriented interface to
folders on disk. (They are referred to here as "folders" rather than
"directories" mainly because "dir" is more commonly used within the
Actium system as an abbreviation for "direction", and I wanted to avoid
ambiguity.)

It only adds methods to the L<Path::Class::Dir|Path::Class::Dir> module
from CPAN.  All methods in Path::Class::Dir are supported by this
module, and readers should look at Path::Class::Dir for complete
documentation on it.

The following comprises documentation for methods in
Actium::Storage::Folder.

=cut

=head1 CLASS METHODS

=head3 ensure_folder

Like L<C<new()> from Path::Class::Dir|Path::Class::Dir/new>,  but if it
does not already exist, creates the folder and any necessary parents.

=cut

method ensure_folder ($class: @pathcomponents) {
    return $class->new(@pathcomponents)->_ensure;
}

=head3 existing_folder

Like L<C<new()> from Path::Class::Dir|Path::Class::Dir/new>,  but
croaks if the folder does not already exist.

=cut

method existing_folder ($class: @pathcomponents) {
    return $class->new(@pathcomponents)->_must_exist;
}

=head3 file_class

Returns the class which is used to create file objects:
Actium::Storage::File.

=cut

sub file_class {
    require Actium::Storage::File;
    return 'Actium::Storage::File';
}

=head3 home

 Actium::Storage::Folder->home(); # home folder
 Actium::Storage::Folder->home('my_data'); # data folder
 Actium::Storage::Folder->home('users_videos', 'foo'); 
    # the foo user's video folder

Fetches a folder from the L<File::HomeDir|File::HomeDir> module and
returns it as an Actium::Storage::Folder object.

If no arguments are specified, fetches a folder using the C<my_home>
method from File::HomeDir. Otherwise, fetches a folder using the
specified method. If any further arguments are passed, forwards them
along to File::HomeDir.

=cut

method home ($class: $method = 'my_home', @args? ) {
    require File::HomeDir;    ### DEP ###
    my $home = File::HomeDir->$method(@args);
    croak "Can't fetch $method from File::HomeDir" unless defined $home;
    return $class->new($home);
}

=head1 OBJECT METHODS

=head2 Folders and Files

=head3 exists

Returns a boolean value: true if there is actually a folder on the file
system associated with this object.

=cut

method exists {
    return ( -e -d $self );
}

=head3 is_folder

Returns a boolean value indicating whether this object represents a
folder. Actium::Storage::Folder objects always return true, and
Actium::Storage::File  objects always return false.

=cut

method is_folder {
    return 1;
}

=head3 mkpath

 $folder->mkpath($verbose, $safe)
 $folder->mkpath(\%options)


Like mkpath() from Path::Class::Dir, but throws an exception on error
(unless an 'error' reference is provided in the options hash).

=cut

method mkpath {
    $self->_file_path_old_interface( 'mkpath', @_ );
}

{

    const my %VERB_OF    => ( mkpath => 'making', rmtree => 'unlinking' );
    const my %LASTARG_OF => ( mkpath => 'mode',   rmtree => 'safe' );

    method _file_path_old_interface {
        my $realmethod = shift;
        # two possibilities:
        # method(verbose, mode)
        # or method( dir, dir, dir, ... , \%opts)
        # this converts former into latter, and keeps the returned
        # errors if user didn't ask for them
        my $err;
        my %args;
        if ( @_ and Actium::is_hashref( $_[-1] ) ) {
            %args = %{ +pop };
            $args{error} = \$err unless exists $args{error};
            # if the user asked for errors, just return them
        }
        else {
            my $verbose = shift;
            my $lastarg = shift;
            $args{verbose}                    = $verbose if defined $verbose;
            $args{ $LASTARG_OF{$realmethod} } = $lastarg if defined $lastarg;
            $args{error}                      = \$err;
        }

        my $supermethod = "SUPER::$realmethod";

        my @results = $self->$supermethod( $self, @_, \%args );

        return if not $err;
        # which means error specified in options and it was never set here.
        # so just return the results

        return unless @$err;
        # no errors were returned

        # so there were errors! assemble the list and croak
        my @errormessages;
        for my $diag (@$err) {
            my ( $file, $message ) = %$diag;
            if ( $file eq '' ) {
                push @errormessages, $message;
            }
            else {
                push @errormessages,
                  "problem " . $VERB_OF{$realmethod} . "$file: $message";
            }
        }

        croak( $realmethod . ':' . join( ' - ', @errormessages ) );

    }

}

=head3 remove

Removes a folder, which must be empty (like perl's L<rmdir
function|perlfunc/rmdir>. Throws an exception on errors.

=cut

method remove {
    my $result = $self->SUPER::remove;
    croak "Can't remove $self: $!" unless $result;
    return $result;
}

=head3 rmtree

 $folder->rmtree($verbose, $safe)
 $folder->rmtree(\%options)

Like rmtree() from Path::Class::Dir, but throws an exception on error
(unless an error was provided in the options hash).

=cut

method rmtree {
    $self->_file_path_old_interface( 'rmtree', @_ );
}

=head2 Subfolders

=head3 subfolder

Returns a new Actium::Storage::Folder object representing a subfolder
of the object.

=cut

method subfolder (@subcomponents) {
    return $self->subdir(@subcomponents);
}

=head3 ensure_subfolder

Like C<subfolder()>, but if it does not already exist, creates the
folder and any necessary parents.

=cut

method ensure_subfolder (@subcomponents) {
    return $self->subfolder(@subcomponents)->_ensure;
}

=head3 existing_subfolder

Like <C<subfolder()>, but croaks if the folder does not already exist.

=cut

method existing_subfolder (@subcomponents) {
    return $self->subfolder(@subcomponents)->_must_exist;
}

method _ensure {
    $self->mkpath;
    return $self;
}

method _must_exist {
    Carp::croak "$self does not exist" unless $self->exists;
    return $self;
}

=head2 Files Within the Folder

=head3 grep (qr/regex/)

Returns the children (files or folders) which have a filename matching
the supplied regular expression.

=cut

# expand someday to accept callbacks?

method grep ( RegexpRef $regex! ) {
    my @files       = $self->children;
    my %file_obj_of = map { $_->basename => $_ } @files;
    my @matching    = grep {/$regex/} keys %file_obj_of;
    my @matches     = sort @file_obj_of{@matching};
    return @matches;
}

=head3 glob( $pattern )

Returns a list of Actium::Storage::File or Actium::Storage::Folder
objects representing the children which have a filename matching the
supplied glob pattern. (See L<Text::Glob|Text::Glob> for the glob
pattern rules.)

If no glob pattern is supplied, returns all files and folders.

=cut

method glob (Str $pattern //= '*') {
    require Text::Glob;
    my $regex = Text::Glob::glob_to_regex($pattern);
    return $self->grep($regex);
}

=head3 glob_files

Like C<glob>, but only returns file objects, not folder objects.

=cut

method glob_files (Str $pattern //= '*') {
    my @files = $self->glob($pattern);
    @files = grep { not( $_->is_folder ) } @files;
    return @files;
}

=head3 glob_folders

Like C<glob>, but only returns folder objects, not file objects.

=cut

method glob_folders (Str $pattern //= '*') {
    my @files = $self->glob($pattern);
    @files = grep { $_->is_folder } @files;
    return @files;
}

=head3 open

Like open() from Path::Class::Dir, but throws an exception on error.

=cut

{
    no autodie;    # eliminate redefiniton errors

    method open {
        my $dirh = $self->SUPER::open(@_);
        croak "Can't open folder: $!" unless defined $dirh;
        return $dirh;
    }
}

=head2 Writing Multiple Files In Their Entirety

=head3 spew_from_method

This routine takes a list of objects passed to it, takes the result of
an object method applied to each of those objects, and saves that
result in files in the specified folder.  The filename used will be the
result of the object's B<id> method, followed by the extension, if
provided. It takes named arguments, as follows:

=over

=item objects

A reference to an array of objects. The objects must implement the
methods passed in the C<method> and C<filename_method> arguments.

=item method

The name of a method the object is to perform. The results are saved in
the file.

Also, this name is used to determine the I/O layers used on the file. 
The routine looks to see whether a method  "METHOD_layers" is
implemented on the object (e.g., for a method "spaced",  it looks for
the additional method "spaced_layers"). If that method exists, it is
called, and the return value is passed to perl's binmode function. See
L<perlfunc/binmode>.

=item extension

An optional argument indicating a file extension to be appended to the 
filename, after a period.  (If omitted, no extension is used.)

=item subfolder

A path string representing the folder, or series of folders, under the 
folder represented by this object. This is where the series of files
are to be stored.

=item filename_method

The name of a method used to determine the filename of the resulting
file. If not specified, will use 'id'.

=item args

A reference to an array. This array is passed through as the arguments
to the method generating the data. If not specified, will use no
arguments.

=back

=cut

method spew_from_method (
    : \@objects !,
    Str : $method !,
    Str : $extension = $EMPTY,
    Str : $subfolder? ,
    Str :$filename_method = 'id',
    : \@args = [],
    ) {

    $extension =~ s/\A[.]*/./
      if ( $extension ne $EMPTY );

    my $folder = defined $subfolder ? $self->subfolder($subfolder) : $self;

    my $cry = env->cry("Writing $method files to $folder");

    my %seen_id;

    foreach my $obj (@objects) {
        my $id = $obj->$filename_method;
        $cry->over( $id . q[ ] );
        $seen_id{$id}++;
        $id .= "_$seen_id{$id}" unless 1 == $seen_id{$id};
        my $file = $self->file( $id . $extension );

        $file->spew_from_method(
            do_cry => 0,
            object => $obj,
            method => $method,
            args   => \@args,
        );
    }

    $cry->over($EMPTY);
    $cry->done;
    return;

}

=head3 spew_from_hash

This routine takes a hash reference and saves the hash values in files
named after the hash keys (using utf-8 encoding).  It takes several
named arguments:

=over

=item hash

A reference to a hash of strings.  The keys will be used as the
filenames  (with the extension, if any, appended). The values will be
used as the content of the files.

=item display_type

This is a string used in describing the files in feedback to the
terminal. If not given, will use 'hash'.

=item extension

The file extension. If it is not empty, it is added to the filename,
after a period.

=back

=cut

method spew_from_hash (
       :\%hash! ,
       :$display_type = 'hash' ,
       :$extension = $EMPTY,
    ) {

    $extension =~ s/\A[.]*/./
      if ( $extension ne $EMPTY );

    my $cry = env->cry("Writing $display_type files to  $self");

    foreach my $key ( sort keys %hash ) {

        $cry->over($key);

        my $filekey = $key =~ s{/}{-}gr;

        my $file = $self->file( $filekey . $extension );
        $file->spew_text( $hash{$key} );

    }

    $cry->over($EMPTY);
    $cry->done;
    return;

}

1;

__END__

# Actium::O::Folder equivalents

# in init_arg --
# folderlist -- this is the same as path
# must_exist -- use method existing_folder

# methods --
# folder -- use basename 
# path - same as stringify
# display_path - same as stringify in O::Folder.  Need to consider
# how to implement this for folders in a signup
# subfolder_path($subpath) - same as ->subfolder($subpath)->stringify
# new (with must_exist) - use method existing_folder
# new (without must_exist) - use method ensure_folder
# subfolder (with must_exist) - use method existing_subfolder
# subfolder (without must_exist) - use method ensure_subfolder
# new_from_file - Actium::Storage::File->folder
# make_filespec - use ->file
# file_exists - use Actium::Storage::File->exists
# children - use glob_folders
# slurp_write - use ->file($filename)->spew_utf8
# slurp_read - use ->file($filename)->slurp_utf8
# json_retrieve - use Actium::Storage::File->json_retrieve
# json_store_pretty - use use Actium::Storage::File->json_store
# store - use Actium::Storage::File->store
# retreive - use Actium::Storage::File->retrieve
# load_sheet - use sheet_retrieve

# open_read_binary -- Actium::Storage::File->openr_raw
# open_read -- Actium::Storage::File->openr_utf8
# open_write_binary -- Actium::Storage::File->openw_raw
# open_write -- Actium::Storage::File->openw_utf8

# load_sqlite, load_hasi - not rewriting this as I need to rewrite
# flagspecs which is the only thing that still uses it

# write_files_with_method - use spew_from_method
# write_file_with_method  - use Actium::Storage::File->spew_from_method
# write_files_with_hash - use spew_from_hash

# glob_plain_files -- use glob_files
# glob_files -- use glob
# glob_plain_files_nopath - use glob_files and then map ->basename

__END__

=head1 DIAGNOSTICS

=over

=item I<folder> does not exist" 

The folder listed was given to C<existing_folder> or
C<existing_subfolder>, but that folder didn't exist.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Kavorka

=item Path::Class

=back

The following are loaded only when necessary:

=over

=item Text::Glob

=back

=head1 SEE ALSO

L<< B<folder> from Actium|Actium/folder >>

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic|perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

