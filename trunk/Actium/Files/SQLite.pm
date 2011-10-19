# Actium/Files/SQLite.pm

# Role for reading and processing flat files and storing in an SQLite database

# Subversion: $Id$

# Legacy stage 4

#The idea is that classes for different types of files (HastusASI,
#FileMaker Pro "Merge", FileMaker Pro "XML") will compose this role
#
#This role does several things:
#
#1) gets the filename of the database
#2) connects and disconnects from the database
#3) keeps track of which flat files have been loaded,
#   and what their mtimes are, so it knows whether to re-load or not
#4) Provides some SQL queries to fetch the data again
#   (not intended to be complete...)
#
#Each db_type (datbase type), has one or more filetypes,
#which has one or more tables (aka rowtypes).

use warnings;
use 5.012;    # turns on features

package Actium::Files::SQLite 0.001;

use Moose::Role;

use Actium::Constants;
use Actium::Term;

use Carp;
use DBI;
use English '-no_match_vars';
use File::Spec;
use List::MoreUtils('uniq');
use Readonly;

# set some constants
Readonly my $STAT_MTIME   => 9;
Readonly my $DB_EXTENSION => '.SQLite';

# Required methods in consuming classes:

requires(
    qw/db_type key_of_table columns_of_table tables
      _load _files_of_filetype _tables_of_filetype
      _filetype_of_table is_a_table/
);

# db_type is something like 'HastusASI' or 'FPMerge' or something, which
# determines the name of the database file.

# _files_of_filetype returns the appropriate files for that filetype,
# something like the equivalent of glob("*.$filetype") for HastusASI,
# or "$filetype.csv" for FPMerge

# _tables_of_filetype yields the different tables that go with filetype
# -- e.g., for HastusASI it would be 'PAT' , 'TPS' for filetype 'PAT'
# For FPmerge it would be just the name of the file ('Timepoints')

# _filetype_of_table yields the filetype to which a table belongs.
# For HastusASI "TPS" would yield "PAT", for example. For anything
# with one table per file, would just yield the table name.

# _load is the routine that actually loads the flat files into
# the database

# columns_of_table lists, of course, the columns of the table

# key_of_table is the key column, if any, of a particular table

# is_a_table returns true if the specified table is valid

######################################
### ATTRIBUTES
######################################

has 'flats_folder' => (
    is       => 'ro',
    isa      => 'Str',
    required => '1',
);

has 'db_folder' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_db_folder',
    lazy    => 1,
);

has 'db_filename' => (
    is      => 'ro',
    isa     => 'Str',
    builder => '_build_db_filename',
    lazy    => 1,
);

has '_db_filespec' => (
    is       => 'ro',
    init_arg => undef,
    isa      => 'Str',
    builder  => '_build_db_filespec',
    lazy     => 1,
);

has '_is_loaded_r' => (
    init_arg => undef,
    traits   => ['Hash'],
    is       => 'ro',
    writer   => '_set_is_loaded_r',
    isa      => 'HashRef[Bool]',
    default  => sub { {} },
    handles  => {
        '_is_loaded'     => 'get',
        '_set_loaded_to' => 'set',
    },
);

sub _mark_loaded {
    my $self     = shift;
    my $filetype = shift;
    $self->_set_loaded_to( $filetype, 1 );
    return;
}

has 'dbh' => (
    init_arg => undef,
    is       => 'ro',
    isa      => 'DBI::db',
    builder  => '_connect',
    lazy     => 1,
);

############################################
### BUILDING AND DEMOLISHING THE OBJECT
############################################

# allows a single "flats_folder" argument, or a hash or hashref with full
# attribute specifications
around BUILDARGS => sub {
    my $orig     = shift;
    my $class    = shift;
    my $first_argument = shift;
    my @rest     = @_;
    return $class->$orig( $first_argument, @rest ) if ( ref $first_argument or @rest );
    return $class->$orig( flats_folder => $first_argument );
};

sub _build_db_folder {

    # only run when no db folder is specified
    my $self = shift;
    return $self->flats_folder;
}

sub _build_db_filename {

    # only run when no db filename is specified
    my $self = shift;
    return $self->db_type . $DB_EXTENSION;
}

sub _build_db_filespec {
    my $self = shift;
    return File::Spec->catfile( $self->db_folder, $self->db_filename );
}

sub _connect {
    my $self        = shift;
    my $db_filespec = $self->_db_filespec();
    my $existed     = -e $db_filespec;

    my $db_filename = $self->db_filename;

    emit(
        $existed
        ? "Connecting to database $db_filename"
        : "Creating new database $db_filename"
    );

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_filespec",
        $EMPTY_STR, $EMPTY_STR, { RaiseError => 1, sqlite_unicode => 1 } );
    $dbh->do(
'CREATE TABLE files ( files_id INTEGER PRIMARY KEY, filetype TEXT , mtimes TEXT )'
    ) if not $existed;

    emit_done;

    return $dbh;

}    ## tidy end: sub _connect

# DBI does the same thing, so this disconnection routine is not needed here.

#sub DEMOLISH { }
#
#after DEMOLISH => sub {
#    my $self = shift;
#    my $dbh  = $self->dbh;
#    $dbh->disconnect();
#    return;
#};

#########################################
### GET MTIMES
#########################################

sub _current_mtimes {
    my $self  = shift;
    my @files = sort @_;

    my $mtimes = $EMPTY_STR;

    foreach my $file (@files) {
        my $filespec = $self->_flat_filespec($file);

        my @stat = stat($filespec);
        unless ( scalar @stat ) {
            emit_error;
            croak "Could not get file status for $filespec";
        }
        $mtimes .= "$file\t$stat[$STAT_MTIME]\t";
    }

    return $mtimes;
}

#########################################
### LOAD FLAT FILES (if necessary)
#########################################

sub ensure_loaded {
    my $self   = shift;
    my @tables = @_;

    # get filetypes from tables

    my @filetypes;
    foreach my $table (@tables) {
        $self->_check_table($table);
        push @filetypes, $self->_filetype_of_table($table);
    }

    foreach my $filetype (@filetypes) {
        next if ( $self->_is_loaded($filetype) );

        # If they're changed, read the flat files

        my @flats = $self->_files_of_filetype($filetype);

        my $dbh = $self->dbh();
        my ($stored_mtimes) = (
            $dbh->selectrow_array(
                'SELECT mtimes FROM files WHERE filetype = ?', {},
                $filetype
              )
              or $EMPTY_STR
        );

        my $current_mtimes = $self->_current_mtimes(@flats);
        if ( $stored_mtimes ne $current_mtimes ) {

            foreach my $table ( $self->_tables_of_filetype($filetype) ) {
                my $table_sth =
                  $dbh->table_info( undef, undef, $table, 'TABLE' );
                my $ary_ref = $table_sth->fetchrow_arrayref();
                $dbh->do("DROP TABLE $table") if $ary_ref;
            }

            $self->_load( $filetype, @flats );
            $dbh->do( 'DELETE FROM files WHERE filetype = ?', {}, $filetype )
              if $stored_mtimes;
            $dbh->do( 'INSERT INTO files (filetype , mtimes) VALUES ( ? , ? )',
                {}, $filetype, $current_mtimes );

        }

        # now that we've checked, mark them as loaded
        $self->_mark_loaded($filetype);

    }    ## tidy end: foreach my $filetype (@filetypes)

    return;

}    ## tidy end: sub ensure_loaded

sub _check_table {
    my ( $self, $table ) = @_;
    croak "Invalid table $table for database type " . $self->db_type()
      if not( $self->is_a_table($table) );
    return;
}

#########################################
### SQL -- PROVIDE ROWS TO CALLERS, OTHER SQL
#########################################

sub row {
    my ( $self, $table, $keyvalue ) = @_;
    my $key = $self->key_of_table($table);
    croak "Can't use row() on table $table with no key"
      unless $key;
    $self->ensure_loaded($table);
    my $dbh   = $self->dbh();
    my $query = "SELECT * FROM $table WHERE $key = ?";
    return $dbh->selectrow_hashref( $query, {}, $keyvalue );
}

sub each_row {
    my ( $self, $table ) = @_;
    return $self->each_row_where($table);
}

sub each_row_like {
    my ( $self, $table, $column, $like ) = @_;
    $self->_check_columns( $table, $column );
    return $self->each_row_where( $table,
        "WHERE $column LIKE ? ORDER BY $column", $like );
}

sub each_row_eq {
    my ( $self, $table, $column, $value ) = @_;
    $self->_check_columns( $table, $column );
    return $self->each_row_where( $table, "WHERE $column = ? ORDER BY $column",
        $value );
}

sub each_row_where {
    my ( $self, $table, $where, @bind_values ) = @_;

    $self->ensure_loaded($table);
    my $dbh = $self->dbh();

    my $query = "SELECT * FROM $table ";
    if ($where) {
        $query .= $where;
    }

    my $sth = $dbh->prepare($query);
    $sth->execute(@bind_values);

    return sub {
        my $result = $sth->fetchrow_hashref;
        $sth->finish() if not $result;
        return $result;
    };
}    ## tidy end: sub each_row_where

#sub all_in_columns_key {
#    my $self    = shift;
#    my $table   = shift;
#    my @columns = @_;
#    
#    $self->ensure_loaded($table);
#    $self->_check_columns($table, @columns);
#    
#    my $key = $self->key_of_table($table);
#    unshift @columns, $key;
#    @columns = uniq(@columns);
#    
#    my $dbh = $self->dbh;
#
#    #my %column_index_of = map { $columns[$_] => $_ } ( 0 .. $#columns );
#
#    my $selection_cmd =
#      "SELECT " . join( q{ , }, @columns ) . " FROM $table";
#      
#    my $rows_r = $dbh->selectall_hashref($selection_cmd, $key);
#    return $rows_r;
#
#}

sub all_in_columns_key {
    my $self    = shift;
    
    my $firstarg = shift;
    
    my ($table, @columns, $where, @bind_values); 
    
    if ( ref($table) eq 'HASH' ) {
        $table   = $firstarg->{TABLE} ;
        @columns = @{$firstarg->{COLUMNS}};
        $where = $firstarg->{WHERE} ;
        
        my $bindval_r = $firstarg->{BIND_VALUES};
        @bind_values = @{$bindval_r}
           if defined $bindval_r;
        
    }
    else {
       $table = $firstarg;
       @columns = @_;
    }
    
    $self->ensure_loaded($table);
    $self->_check_columns($table, @columns);
    
    my $key = $self->key_of_table($table);
    unshift @columns, $key;
    @columns = uniq(@columns);
    
    my $dbh = $self->dbh;

    #my %column_index_of = map { $columns[$_] => $_ } ( 0 .. $#columns );

    my $selection_cmd =
      "SELECT " . join( q{ , }, @columns ) . " FROM $table" ;
     
    $selection_cmd .= " WHERE $where" if defined $where;
      
    my $rows_r = $dbh->selectall_hashref($selection_cmd, $key, {} , @bind_values);
    return $rows_r;

}

sub _check_columns {
    my ( $self, $table, @input_columns ) = @_;
    my @columns = $self->columns_of_table($table);
    foreach my $input (@input_columns) {
        croak "Invalid column $input for table $table"
          if not $input ~~ @columns;
    }
    return;
}

sub begin_transaction {
    my $self = shift;
    my $dbh  = $self->dbh;
    return $dbh->do('BEGIN EXCLUSIVE TRANSACTION');
}

sub end_transaction {
    my $self = shift;
    my $dbh  = $self->dbh;
    return $dbh->do('COMMIT');
}

###############################
### UTILITY
###############################

sub _flat_filespec {
    my $self         = shift;
    my $flats_folder = $self->flats_folder;
    my @files        = @_;
    return wantarray
      ? map { File::Spec->catfile( $flats_folder, $_ ) } @files
      : File::Spec->catfile( $flats_folder, $files[0] );
}

1;

__END__

head1 NAME

Actium::Files::SQLite - role for reading flat files and storing the data
in an SQLite database

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Files::RoleComposer;
            
 my $db = Actium::Files::RoleComposer->new(
     flats_folder => $flats_folder,
     db_folder    => $cache,
     db_filename  => $db_filename,
 );
      
 $row_hr = $db->row('Column' , 'Keyvalue');
 $othervalue = $row_hr->{OtherValue};
   
=head1 DESCRIPTION

Actium::Files::SQLite is a role for storing data from flat files
in an SQLite database, using L<DBI|DBI> and L<DBD::SQLite|DBD::SQLite>.

The SQLite database acts as a cache, allowing quicker access
to the flat files than would be possible otherwise.  When the timestamps
on the files change, or (depending on the consuming class) when the names
of the files themselves change, the files are re-loaded and stored into
the SQLite database.

A class consumes this role if it knows about a particular set of
file (for example, Hastus Standard AVL files, or FileMaker Pro
"Merge" files).

While much of the scut work of creating and populating the database
is performed in this module, and some convenience methods are
provided for reading the data, it is not intended that using
this module will make it unnecessary to interact with the DBI object 
directly. The I<dbh()> method is provided for accessing the database handle, 
and users should be familiar with using DBI to fetch data.

=head1 OBJECT CREATION

=head2 CONSTRUCTOR

The constructor is provided by Moose and is called "new". 

=over

=item B<new ($flats_folder)>

=item B<new (I<attributes hash...>)>

=back

If only one argument is provided, it is used as the flats_folder
attribute. Otherwise, the constructor expects to see a hash or hash
reference, with attribute names as the keys and attribute values as 
the values.

=head2 ATTRIBUTES

=over 

=item B<flats_folder>

The folder on disk where the flat files are located.
This is required to be specified in the object creator.

=item B<db_folder>

The folder on disk where the database is to be stored. Defaults to 
the value of I<flats_folder>.

=item B<db_filename>

The filename (not path) of the database.  Defaults to the value of the 
L<B<db_type>|/db_type> method concatenated with ".SQLite": something like 
"HastusASI.SQLite" or "FPMerge.SQLite" .

=back

=head1 METHODS

=head2 Methods that must be provided by the consuming class

=over

=item B<db_type>

This method should return a string (such as 'HastusASI' or 'FPMerge') which
gives information on the type of data being stored. This is used, for example,
as part of the default filename.

=item B<columns_of_table(I<table>)>

This method returns a list of the data columns of a particular
table.  

These are the columns that come in from the data, and will not include any 
other columns. There will always be an additional column called "${table}_id"
that is a serial number for the row, and there may be an additional column
called "${table}_key" if the key for the row is a composite key. (This can be
determined by testing whether $db->key_of_table{$table} is equal to 
"${table}_key".)

=item B<key_of_table(I<table>)>

This method returns the name of the key column, if any, associated
with is table. It can be a regular column that comes from the data,
or a composite key column which is created by the consuming class.

=back

=head2 Methods in Actium::Files::SQLite

=over

=item B<ensure_loaded(I<table>, ...)>

Ensures that the flat files for one or more tables are loaded into
the database.

The first time B<ensure_loaded> is called (in this run of the
program) for each type of file, then B<ensure_loaded> will check
to see if it needs to be loaded.  Only if the files' modification
times have been altered, or the names or quantities of files are
different, I<ensure_loaded> will have the consuming class reload
the files.  Otherwise it will read the data from the last time the
database was populated from the flat files.

=item B<dbh()>

Provides the database handle associated with this database. See
L<DBI|DBI> for information on the database handle.

It is strongly recommended that B<ensure_loaded> be called for any
table before the database handle is used to read it.

=item B<row(I<table>, I<keyvalue>)>

Fetches the row of the table where the value of the key column is the
specified value.  (DBI will be happy to provide the "first" row if there
is more than one row with that value, but which row is first is undefined.
It is recommended for use only on rows with unique values in the key.) 

The row is provided as a hash reference, where the keys are the
column names and the values are the values for this row.

=item B<each_row(I<table>)>

=item B<each_row_eq(I<table>, I<column>, I<value>)>

=item B<each_row_like(I<table>, I<column>, I<match>)>

=item B<each_row_where(I<table>, I<column>, I<where>, I<match> ...)>

The each_row routines return an subroutine reference allowing iteration 
through each row. Intended for use in C<while> loops:

 my $eachtable = each_row("table");
 while ($row_hr = $eachtable->() ) {
    do_something_with_value($row_hr->{SomeColumn});
 }

The rows are provided as hash references, where the keys are the
column names and the values are the values for this row.

each_row provides every row in the table.

each_row_eq provides every row where the column specified is equal to the
value specified.

each_row_like provides every row where the column specified matches
the SQLite LIKE pattern matching characters. ("%" matches a sequence
of zero or more characters, and "_" matches any single character.
See L<the SQLite documentation on
LIKE|http://www.sqlite.org/lang_expr.html#like> for details.)

each_row_where is more flexible, allowing the user to specify any
L<SQLite WHERE clause|http://www.sqlite.org/lang_select.html#whereclause>.
It accepts multiple values for matching.

=item B<begin_transaction>

=item B<end_transaction>

Tell the database that an exclusive transaction is beginning
and ending, respectively.  Make sure that I<end_transaction> is run 
before the database is disconnected.

=back

=head1 DIAGNOSTICS

=over

=item Could not get file status for $filespec

The program could not read the modification time of the file.
Probably an error with the file system of some kind.

=item Can't use row() on table $table with no key

Another module called the B<row> method, specifying a table with 
no key. This is not valid.

=item Invalid column $column for table $table

A request specified a column that was not found in the specified table.

=item Invalid table $table for database type $db_type

A request specified a table that was not found for the specified database type.

=back

=head1 DEPENDENCIES

=over 

=item perl 5.012

=item DBI

=item DBD::SQLite

=item Moose::Role

=item Actium::Constants

=item Actium::Term

=back

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
