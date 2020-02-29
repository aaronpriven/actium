package Octium::O::Folder 0.014;

# Objects representing folders (directories) on disk

use Actium ('class');
use Octium;

use File::Spec;    ### DEP ###
use File::Glob ('bsd_glob');    ### DEP ###

use Params::Validate qw(:all);  ### DEP ###

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
        push @parents, File::Spec->catpath( $volume, $path_so_far, $EMPTY );
    }

    return @parents;
}

has volume => (
    default => $EMPTY,
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

around BUILDARGS ( $orig, $class : $first_argument, slurpy @rest ) {

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

    my $volume = $EMPTY;
    $volume = $hashref->{volume} if exists $hashref->{volume};

    my $temppath = File::Spec->catpath( $volume, File::Spec->catdir(@folders) );

    if ( not File::Spec->file_name_is_absolute($temppath) ) {

        # is relative
        require Cwd;    ### DEP ###
        unshift @folders, Cwd::getcwd();
    }

    $hashref->{folderlist} = $class->split_folderlist(@folders);

    return $class->$orig($hashref)

}    ## tidy end: around BUILDARGS

sub split_folderlist {

    # splits folder list into components (e.g., "path/to" becomes qw<path to>).
    # Takes either an array of strings, or an arrayref of strings.

    my $self     = shift;
    my $folder_r = Octium::flatten(@_);

    my @new_folders;
    foreach my $folder ( @{$folder_r} ) {

        my $canon = File::Spec->canonpath($folder);
        if ( $canon eq $EMPTY ) {
            push @new_folders, $EMPTY;
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

The idea here is that Octium::O::Folder has a single list of folders,
"folderlist," which is specified in the new() constructor and
subfolder() cloner. In the cloner, the specified folderlist is added to the
old one to form the complete new folderlist.

The Octium::O::Folders::Signup subclass, however, has a second list of folders 
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

sub subfolderlist_reader   {'_folderlist_r'}
sub subfolderlist_init_arg {'folderlist'}

sub subfolder {
    my $self = shift;

    my $init_arg = $self->subfolderlist_init_arg;
    my $reader   = $self->subfolderlist_reader;

    my $params_r = _positional( \@_, '@' . $init_arg );

    my @subfolders = @{ $params_r->{$init_arg} };

    croak 'No folders passed to method "subfolder"'
      unless @subfolders;

    $params_r->{$init_arg} = [ $self->$reader, @subfolders ];

    # constructor will flatten the arrayrefs into an array

    my $original_params_r = $self->original_parameters;
    delete $original_params_r->{$init_arg};

    foreach my $key ( keys %{$original_params_r} ) {
        my $value = $original_params_r->{$key};
        $params_r->{$key} = $value unless exists $params_r->{$key};
    }

    my $class = blessed($self);
    return $class->new($params_r);

}    ## tidy end: sub subfolder

sub _positional {
    # moved from Octium::Util since this is now the only routine that uses it

    my $argument_r = shift;
    my $qualsub    = __PACKAGE__ . '::positional';
    ## no critic (RequireInterpolationOfMetachars)
    croak 'First argument to ' . $qualsub . ' must be a reference to @_'
      if not( ref($argument_r) eq 'ARRAY' );
    ## use critic

    my @arguments = @{$argument_r};
    my @attrnames = @_;
    # if the last attribute begins with @, package up all remaining
    # positional arrguments into an arrayref and return that
    my $finalarray;
    if ( $attrnames[-1] =~ /\A @/sx ) {
        $finalarray = 1;
        $attrnames[-1] =~ s/\A @//sx;
    }

    for my $attrname (@attrnames) {
        next unless $attrname =~ /\A @/sx;
        croak "Attribute $attrname specified.\n"
          . "Only the last attribute specified in $qualsub in can be an array";
    }

    my %newargs;
    if ( defined Octium::reftype( $arguments[-1] )
        and reftype( $arguments[-1] ) eq 'HASH' )
    {
        %newargs = %{ pop @arguments };
    }
    if ( not $finalarray and scalar @attrnames < scalar @arguments ) {
        croak 'Too many positional arguments in object construction';
    }

    while (@arguments) {
        my $name = shift @attrnames;
        if ( not @attrnames and $finalarray ) {
            # if this is the last attribute name, and it originally had a @
            $newargs{$name} = [@arguments];
            @arguments = ();
        }
        else {
            $newargs{$name} = shift @arguments;
        }
    }

    return \%newargs;

}    ## tidy end: sub _positional

sub new_from_file {

    # takes a filename and creates a new Octium::O::Folder from the path part
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

sub file_exists {
    my $self     = shift;
    my $filename = shift;
    my $path     = $self->path;
    return -e File::Spec->catfile( $path, $filename );
}

sub glob_files {
    my $self        = shift;
    my $pattern     = shift || q{*};
    my $path        = $self->path;
    my $fullpattern = File::Spec->catfile( $path, $pattern );
    my @results     = bsd_glob($fullpattern);

    return @results unless File::Glob::GLOB_ERROR;

    croak "Error while globbing pattern '$pattern': $!";

}

sub glob_plain_files {
    my $self = shift;
    return grep { -f $_ } $self->glob_files(@_);
}

sub glob_files_nopath {
    my $self  = shift;
    my @files = $self->glob_files(@_);
    return map { Octium::filename($_) } @files;
}

sub glob_plain_files_nopath {
    my $self  = shift;
    my @files = $self->glob_plain_files(@_);
    return map { Octium::filename($_) } @files;
}

sub children {

    # make subfolders
    my $self = shift;
    my $path = $self->path;

    my @folderpaths = grep {-d} $self->glob_files(@_);
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

    my $cry = cry("Writing $filename...");

    require File::Slurper;
    File::Slurper::write_text( $filespec, $string );

    $cry->done;

}

sub slurp_read {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);
    my $cry      = cry("Reading $filename...");

    croak "$filespec does not exist"
      unless -e $filespec;

    require File::Slurper;
    return scalar File::Slurper::read_text($filespec);

}

sub json_retrieve {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    my $cry = cry("Retrieving JSON file $filename");

    my $json_text = $self->slurp_read($filename);

    require JSON;    ### DEP ###
    my $data_r = JSON::from_json($json_text);

    $cry->done;

    return $data_r;

}

sub json_store {

    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;

    my $cry = cry("Storing JSON file $filename...");

    require JSON;    ### DEP ###
    my $json_text = JSON::to_json($data_r);

    $self->slurp_write( $json_text, $filename );

    $cry->done;

}

sub json_store_pretty {

    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;

    my $cry = cry("Storing JSON file $filename...");

    require JSON;    ### DEP ###
    my $json_text = JSON::to_json( $data_r, { pretty => 1, canonical => 1 } );

    $self->slurp_write( $json_text, $filename );

    $cry->done;

}

sub retrieve {
    my $self     = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    croak "$filespec does not exist"
      unless -e $filespec;

    my $cry = cry("Retrieving $filename");

    require Storable;
    my $data_r = Storable::retrieve($filespec);

    unless ($data_r) {
        $cry->d_error();
        croak "Can't retreive $filespec: $OS_ERROR";
    }

    $cry->done;

    return $data_r;
}    ## tidy end: sub retrieve

sub store {
    my $self     = shift;
    my $data_r   = shift;
    my $filename = shift;
    my $filespec = $self->make_filespec($filename);

    my $cry = cry("Storing $filename...");

    require Storable;
    my $result = Storable::nstore( $data_r, $filespec );

    unless ($result) {
        $cry->d_error;
        croak "Can't store $filespec: $OS_ERROR";
    }

    $cry->done;
}

sub open_read_binary {
    my $self     = shift;
    my $filename = shift;
    $self->_open_read_encoding( $filename, ':raw' );
}

sub open_read {
    my $self     = shift;
    my $filename = shift;
    $self->_open_read_encoding( $filename, ':encoding(UTF-8)' );
}

sub _open_read_encoding {
    my $self     = shift;
    my $filename = shift;
    my $encoding = shift;
    my $filespec = $self->make_filespec($filename);

    open my $fh, "<$encoding", $filespec
      or croak "Can't open $filespec for reading: $OS_ERROR";

    return $fh;

}

sub open_write_binary {
    my $self     = shift;
    my $filename = shift;
    $self->_open_write_encoding( $filename, ':raw' );
}

sub open_write {
    my $self     = shift;
    my $filename = shift;
    $self->_open_write_encoding( $filename, ':encoding(UTF-8)' );
}

sub _open_write_encoding {
    my $self     = shift;
    my $filename = shift;
    my $encoding = shift;
    my $filespec = $self->make_filespec($filename);

    open my $fh, ">$encoding", $filespec
      or croak "Can't open $filespec for writing: $OS_ERROR";

    return $fh;

}

#######################
### READ OR WRITE SQLITE FILES IN THIS FOLDER

sub load_sqlite {
    my $self              = shift;
    my $default_subfolder = shift;
    my $database_class    = shift;
    my %params            = Octium::validate(
        @_,
        {   subfolder => 0,
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
        ( $subfolder eq $EMPTY )
          or (  ref $subfolder eq 'ARRAY'
            and @{$subfolder} == 1
            and $subfolder->[0] eq $EMPTY )
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
    $self->load_sqlite( 'hasi', 'Octium::O::Files::HastusASI', @_ );
}

################################################
### READ OR WRITE FILES IN THIS FOLDER FROM OBJECTS

sub write_files_with_method {
    my $self = shift;

    my %params = Octium::validate(
        @_,
        {   OBJECTS         => { type    => ARRAYREF },
            METHOD          => 1,
            EXTENSION       => 0,
            SUBFOLDER       => 0,
            FILENAME_METHOD => { default => 'id' },
            ARGS => { default => [], type => ARRAYREF },
        }
    );

    my @objects   = @{ $params{OBJECTS} };
    my $extension = $EMPTY;
    if ( exists $params{EXTENSION} ) {
        $extension = $params{EXTENSION};
        $extension =~ s/\A\.*/./;

        # make sure there's only one a leading period
    }

    my $method          = $params{METHOD};
    my $subfolder       = $params{SUBFOLDER};
    my $filename_method = $params{FILENAME_METHOD};

    my $folder;
    if ($subfolder) {
        $folder = $self->subfolder($subfolder);
    }
    else {
        $folder = $self;
    }

    my $count;

    my $cry = cry( "Writing $method files to " . $folder->display_path );

    my %seen_id;

    foreach my $obj (@objects) {

        my $out;

        my $id = $obj->$filename_method;
        $cry->over( $id . $SPACE );

        $seen_id{$id}++;

        $id .= "_$seen_id{$id}" unless $seen_id{$id} == 1;

        my $filename = $id . $extension;

        $folder->write_file_with_method(
            {   CRY      => $cry,
                OBJECT   => $obj,
                METHOD   => $method,
                FILENAME => $filename,
                ARGS     => $params{ARGS},
            }
        );

    }    ## tidy end: foreach my $obj (@objects)

    $cry->over('');

    $cry->done;

}    ## tidy end: sub write_files_with_method

sub write_file_with_method {
    my $self     = shift;
    my %params   = %{ +shift };
    my $obj      = $params{OBJECT};
    my $filename = $params{FILENAME};
    my $method   = $params{METHOD};
    my $args_r   = $params{ARGS} // [];
    my $cry      = $params{CRY} // cry("Writing to $filename via $method");

    my $out;

    my $file = $self->make_filespec($filename);

    unless ( open $out, '>', $file ) {
        $cry->d_error;
        croak "Can't open $file for writing: $OS_ERROR";
    }

    my $layermethod = $method . '_layers';
    if ( $obj->can($layermethod) ) {
        my $layers = $obj->$layermethod;
        binmode( $out, $layers );
    }
    else {
        binmode( $out, ':utf8' );
    }

    print $out $obj->$method(@$args_r)
      or croak "Can't print to $file: $OS_ERROR";

    unless ( close $out ) {
        $cry->d_error;
        croak "Can't close $file for writing: $OS_ERROR";
    }

    if ( not $params{CRY} ) {
        $cry->done;
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
        $extension = $EMPTY;
    }

    my $cry = cry( "Writing $filetype files to " . $self->display_path );

    foreach my $key ( sort keys %hash ) {

        $cry->over($key);

        my $filekey = $key =~ s@/@-@gr;

        my $file = $self->make_filespec( $filekey . $extension );

        my $out = $self->open_write( $filekey . $extension );

        print $out $hash{$key} or die "Can't print to $file: $OS_ERROR";

        unless ( close $out ) {
            $cry->d_error;
            die "Can't close $file for writing: $OS_ERROR";
        }

    }

    $cry->over('');
    $cry->done;

}    ## tidy end: sub write_files_from_hash

sub load_sheet {

    my $self     = shift;
    my $filename = shift;

    my $filespec = $self->make_filespec($filename);

    require Octium::O::2DArray;
    my $sheet = Octium::O::2DArray::->new_from_file($filespec);

    return $sheet;

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Octium::O::Folder - Folder objects for the Actium system

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Octium::O::Folder;

 $folder = Octium::O::Folder->new('/path/to/folder');

 $filespec = $folder->make_filespec('10_EB_WD.txt');
 # $filespec is something like /path/to/folder/10_EB_WD.txt

 @files = $folder->glob_files('*.txt');
 # @files contains all the *.txt files in the '/path/to/folder' folder

=head1 DESCRIPTION

Octium::O::Folder provides an object-oriented interface to folders on disk.
(They are referred to here as "folders" rather than "directories" mainly
because "dir" is more commonly used within the Actium system as an 
abbreviation for "direction", and I wanted to avoid ambiguity.)

This module is intended to make it easier to open files within folders and
create new subfolders.

It forms the base class used by 
L<Octium::O::Folders::Signup|Octium::O::Folders::Signup>, which is more likely to be
used directly in programs.

As much as possible, Octium::O::Folder uses the L<File::Spec> module in order
to be platform-independent (although Actium is tested only under Mac OS X for 
the moment).

=head1 OBJECT CONSTRUCTION

Octium::O::Folder objects are created using the B<new> constructor inherited from
Moose. Alternatively, they can be cloned from an existing Octium::O::Folder object,
using B<subfolder>, or from a file path using B<new_from_file>.

For either B<new> or B<subfolder>, if the first argument is a hash reference, 
it is taken as a reference to named
arguments. If not, the arguments given are considered part of the 
I<folderlist> argument. So this:

 my $folder = Octium::O::Folder->new($folder1, $folder2 )
 
is a shortcut for this:

 my $folder = Octium::O::Folder->new({folderlist => [ $folder1, $folder2 ]})
 
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
or a combination (['/path/to' , 'folder']). Octium::O::Folder splits the pieces
into individual folders for you.

Octium::O::Folder's I<new> constructor accepts both relative paths and absolute 
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

This attribute, if set to a true value, will cause Octium::O::Folder to throw
an exception if the specified folder does not yet exist. If not set, 
Octium::O::Folder will attempt to create this folder and, if necessary, its 
parents.

Unless specified in the arguments to either B<new> or B<subfolder>, the
value will be false. The B<subfolder> routine resets the value to false,
and does not copy the value from the original object.

=back

=head1 OVERLOADING

Using an Octium::O::Folder object as a string will return the path() value.
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

 $folder = new Octium::O::Folder ('/Users');
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

Returns an Octium::O::Files::HastusASI 
object. The named arguments are:

=over

=item subfolder

An optional item representing the folder where the flat files are to be found:
either a string, or an array to a list of one or more strings.

If the empty string is provided, then the folder of the object itself is used.
Otherwise, a subfolder of the object's folder is used: either one specified
by the string or strings provided, or the default: 'hasi' for load_hasi.

=item db_folder

An optional item passed to Octium::O::Files::SQLite: the folder where the SQLite 
database will be stored.

=back

=item B<load_sqlite (I<default_subfolder>, I<database_class> , I<named_arguments>>

This method is used to do the work of the load_xml and load_hasi routines. 
The named arguments are the same as those methods. 

The default subfolder is a string or reference to a list of strings representing
subfolders of the folder of the current object.

The database class will be some perl class to be "require"d by this method,
probably composing the Octium::O::Files::SQLite role.

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
be saved in the folder represented by the Octium::O::Folder object.

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
        
In creating the Octium::O::Folder object, the must_exist attribute was given
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

=item Octium::O::Files::HastusASI

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
