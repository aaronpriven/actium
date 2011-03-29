# Actium/Db/SQLite.pm

# Role for reading and processing flat files and storing in an SQLite database

# Subversion: $Id$

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
#
#Each dbtype (datbase type), has one or more filetypes,
#which has one or more tables (aka rowtypes).

use warnings;
use 5.012;    # turns on features

package Actium::Db::SQLite 0.001;

use Moose::Role;
use MooseX::SemiAffordanceAccessor;

use Actium::Constants;
use Actium::Files qw/filename/;
use Actium::Term;
use Actium::Util qw(jk);
use Actium::Options (qw/add_option option/);
use Carp;
use DBI;
use English '-no_match_vars';
use File::Glob qw(:glob);
use File::Spec;
use Readonly;

add_option( 'db_folder', 'Directory where temporary databases are stored' );

# set some constants
Readonly my $STAT_MTIME   => 9;
Readonly my $DB_EXTENSION => '.SQLite';

# Required methods in consuming classes:

requires(
    qw/db_type key_of_table columns_of_table 
       _load _files_of_filetype _tables_of_filetype/
);

# db_type is something like 'HastusASI' or 'FPMerge' or something, which
# determines the name of the database file.

# _files_of_filetype returns the appropriate files for that filetype,
# something like the equivalent of glob("*.$filetype") for HastusASI,
# or "$filetype.csv" for FPMerge

# _tables_of_filetype yields the different tables that go with filetype
# -- e.g., for HastusDB it would be 'PAT' , 'TPS' for filetype 'PAT'
# For FPmerge it would be just the name of the file ('Timepoints')

# _load is the routine that actually loads the flat files into
# the database

# columns_of_table lists, of course, the columns of the table

# key_of_table is the key column, if any, of a particular table

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
    is      => 'ro',
    init_arg => undef,
    isa     => 'Str',
    builder => '_build_db_filespec',
    lazy    => 1,
);

has '_is_loaded_r' => (
    init_arg => undef,
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Bool]',
    default => sub { {} },
    handles => {
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
    is      => 'ro',
    isa     => 'DBI::db',
    builder => '_connect',
    lazy    => 1,
);

############################################
### BUILDING AND DEMOLISHING THE OBJECT
############################################

around BUILDARGS => sub {
    my $orig     = shift;
    my $class    = shift;
    my $argument = shift;
    return $class->$orig( $argument, @_ ) if ( ref $argument or @_ );
    return $class->$orig( flats_folder => $argument );
};

sub _build_db_folder {
    # only run when no db folder is specified
    my $option_db_folder = option('db_folder');
    return $option_db_folder if $option_db_folder;
    my $self = shift;
    return $self->flats_folder;
}

sub _build_db_filename {
    my $self = shift;
    return $self->dbtype . $DB_EXTENSION;
}

sub _build_db_filespec {
    my $self = shift;
    return File::Spec->catfile( $self->db_folder, $self->db_filename );
}

sub _connect {
    my $self        = shift;
    my $db_filespec = $self->_db_filespec();
    my $db_filename = $self->db_filename();
    my $existed     = -e $db_filespec;

    emit(
        $existed
        ? "Connecting to database $db_filespec"
        : "Creating new database $db_filespec"
    );

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_filespec",
        $EMPTY_STR, $EMPTY_STR, { RaiseError => 1 } );
    $dbh->do(
'CREATE TABLE files ( files_id INTEGER PRIMARY KEY, filetype TEXT , mtimes TEXT )'
    ) if not $existed;

    emit_done;

    return $dbh;

} ## tidy end: sub _connect

sub DEMOLISH { }

after DEMOLISH => sub {
    my $self = shift;
    my $dbh  = $self->dbh;
    $dbh->disconnect();
    return;
};

#########################################
### GET MTIMES
#########################################

sub current_mtimes {
    my $self  = shift;
    my @files = sort @_;

    my $mtimes = $EMPTY_STR;

    foreach my $file (@files) {
        my $filespec = $self->flat_filespec($file);

        my @stat = stat($filespec);
        unless ( scalar @stat ) {
            emit_error;
            croak "Could not get file status for $filespec";
        }
        $mtimes .= jk( $file, $stat[$STAT_MTIME] );
    }

    return $mtimes;
}

#########################################
### LOAD FLAT FILES (if necessary)
#########################################

sub ensure_loaded {
    my $self      = shift;
    my @filetypes = @_;

    foreach my $filetype (@filetypes) {
        next if ( $self->_is_loaded($filetype) );

        # If they're changed, read the flat files

        my @flats = $self->files_of_filetype($filetype);

        my $dbh = $self->dbh();
        my ($stored_mtimes) = (
            $dbh->selectrow_array(
                'SELECT mtimes FROM files WHERE filetype = ?', {},
                $filetype
              )
              or $EMPTY_STR
        );

        my $current_mtimes = $self->current_mtimes(@flats);
        if ( $stored_mtimes ne $current_mtimes ) {

            foreach my $table ( $self->tables_of_filetype($filetype) ) {
                my $table_sth
                  = $dbh->table_info( undef, undef, $table, 'TABLE' );
                my $ary_ref = $table_sth->fetchrow_arrayref();
                $dbh->do( 'DROP TABLE ?', {}, $table ) if $ary_ref;
            }

            $self->_load( $filetype, @flats);
            $dbh->do( 'DELETE FROM files WHERE filetype = ?', {}, $filetype )
              if $stored_mtimes;
            $dbh->do( 'INSERT INTO files (filetype , mtimes) VALUES ( ? , ? )',
                {}, $filetype, $current_mtimes );

        }

        # now that we've checked, mark them as loaded
        $self->_mark_loaded($filetype);

    } ## tidy end: foreach my $filetype (@filetypes)

    return;

} ## tidy end: sub ensure_loaded

#########################################
### SQL -- PROVIDE ROWS TO CALLERS, OTHER SQL
#########################################

sub each_row_like {
    my ( $self, $table, $column, $match ) = @_;
    $self->_check_column( $table, $column );
    return $self->each_row_where( $table,
        "WHERE $column LIKE ? ORDER BY $column", $match );
}

sub each_row_eq {
    my ( $self, $table, $column, $value ) = @_;
    $self->_check_column( $table, $column );
    return $self->each_row_where( $table, "WHERE $column = ? ORDER BY $column",
        $value );
}

sub each_row {
    my ( $self, $table ) = @_;
    return $self->each_row_where($table);
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
} ## tidy end: sub each_row_where

sub _check_column {
    my ( $self, $table, $column ) = @_;
    my @columns = $self->columns_of_table($table);
    croak "Invalid column $column for table $table"
      if not $column ~~ @columns;
    return;
}

sub row {
    my ( $self, $table, $key ) = @_;
    my $keycolumn = $self->key_of_table($table);
    $self->ensure_loaded($table);
    my $dbh   = $self->dbh();
    my $query = "SELECT * FROM $table WHERE $keycolumn = ?";
    return $dbh->selectrow_hashref( $query, {}, $key );
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

sub flat_filespec {
    my $self         = shift;
    my $flats_folder = $self->flats_folder;
    my @files        = @_;
    return wantarray
      ? map { File::Spec->catfile( $flats_folder, $_ ) } @files
      : File::Spec->catfile( $flats_folder, $files[0] );
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
