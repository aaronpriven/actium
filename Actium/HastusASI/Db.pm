# Actium/HastusASI/Db.pm

# Routines for reading and processing Hastus Standard AVL files
# and storing in an SQLite database

# Subversion: $Id$

# this file should not be used in new programming. 
# Code using it should replace it with Actium::Files::HastusASI

# Legacy stage 3

use strict;
use warnings;

use 5.012;    # turns on features

package Actium::HastusASI::Db 0.001;

use 5.012;    # turns on features

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Constants;
use Actium::HastusASI::Columns (':ALL');
use Actium::Files qw/filename/;
use Actium::Term;
use Actium::Util qw(j jk);
use Carp;
use DBI;
use English '-no_match_vars';
use File::Glob qw(:glob);
use File::Spec;
use List::MoreUtils 0.22 (qw/any zip/);
use Readonly;

#use Text::Trim 1.02;

# set some constants
Readonly my $NO_PARENT                   => q{noparent};
Readonly my $DELIMITER                   => q{,};
Readonly my $DELIMITER_LENGTH            => length($DELIMITER);
Readonly my $DELIMITER_TEMPLATE_PAD      => 'x' x $DELIMITER_LENGTH;
Readonly my $STAT_MTIME                  => 9;
Readonly my $EXTRA_FIELDS_WHEN_REPEATING => 49;
Readonly my $MTIME_KEY                   => 'MTIME' . $KEY_SEPARATOR;
Readonly my $DIR_KEY                     => 'DIR' . $KEY_SEPARATOR;
Readonly my $FILESPEC_KEY                => 'FILESPEC' . $KEY_SEPARATOR;
Readonly my $DEFAULT_DBFILENAME                  => 'HastusASI.sqlite';
Readonly my $OCCASIONS_TO_DISPLAY        => 20;
Readonly my $AVERAGE_CHARS_PER_LINE      => 20;
Readonly my $DISPLAY_PERCENTAGE_FACTOR   => 100 / $OCCASIONS_TO_DISPLAY;

Readonly my $SQL_MTIME_TABLE_CREATE =>
'CREATE TABLE files ( files_id INTEGER PRIMARY KEY, filetype TEXT , mtimes TEXT )';
Readonly my $SQL_FETCH_MTIMES  => 'SELECT mtimes FROM files WHERE filetype = ?';
Readonly my $SQL_DELETE_MTIMES => 'DELETE FROM files WHERE filetype = ?';
Readonly my $SQL_INSERT_MTIMES =>
  'INSERT INTO files (filetype , mtimes) VALUES ( ? , ? )';
Readonly my $SQL_BEGIN => 'BEGIN EXCLUSIVE TRANSACTION';
Readonly my $SQL_END   => 'COMMIT';

######################################
### MOOSE ATTRIBUTES
######################################

has 'dir' => (
    is  => 'ro',
    isa => 'Str',
    required => '1',
);

has '_dbfilename' => (
    is  => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '_build_dbfilename',
);

has '_dbfileprefix' => (
    is  => 'ro',
    isa => 'Str',
);

has '_dbfilespec' => (
    is => 'ro' ,
    isa => 'Str' ,
    lazy => 1 ,
    builder => '_build_dbfilespec',
);

has 'dbh' => (
    reader => 'dbh',
    writer => '_set_dbh',
    isa    => 'DBI::db',
);

has '_mtimes_r' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Str]',
    handles => { '_mtimes' => 'get' },
);

has '_filespecs_r' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[Str]]',
    writer  => '_set_filespecs_r',
    handles => { '_filespecs_r_of' => 'get' },
);

sub _filespecs_of {
    my $self     = shift;
    my $filetype = shift;
    return @{ $self->_filespecs_r_of($filetype) };
}

has '_is_loaded_r' => (
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

######################################
### BUILDING AND DEMOLISHING THE OBJECT
######################################

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;
    my %attrs = ( dir => +shift ) ;
    my $dbfileprefix = shift;
    $attrs{_dbfileprefix} = $dbfileprefix if $dbfileprefix;
    return $class->$orig(\%attrs);
};

sub BUILD {
    my $self = shift;
    $self->_connect();
    $self->_build_filespecs_and_mtimes;
    return;
}

sub _connect {
    my $self    = shift;
    my $dbfilespec  = $self->_dbfilespec();
    my $dbfilename = $self->_dbfilename();
    my $existed = -e $dbfilespec;

    emit(
        $existed
        ? "Connecting to database $dbfilespec"
        : "Creating new database $dbfilespec"
    );

    my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfilespec", $EMPTY_STR, $EMPTY_STR,
        { RaiseError => 1 } );

    #$dbh->trace(1,"/tmp/dbitrace.log");

    if ( not $existed ) {
        emit 'Creating database tables';
        foreach ( $SQL_MTIME_TABLE_CREATE, table_create_queries(),
            table_index_queries() )
        {
            $dbh->do($_);
        }
        emit_done;
    }

    emit_done;

    return $self->_set_dbh($dbh);

} ## tidy end: sub _connect

sub _build_filespecs_and_mtimes {
    my $self = shift;
    my $dir  = $self->dir();

    emit 'Assembling lists of filenames and modification times';

    my @all_filespecs = bsd_glob( $self->_make_filespec(q<*>), GLOB_NOCASE );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak
"Error reading list of filenames in Hastus AVL Standard directory $dir: $OS_ERROR";
    }

    if ( not scalar @all_filespecs ) {
        emit_error;
        croak "No files found in Hastus AVL Standard directory $dir";
    }

    my %filespecs_of;
    my %mtime_of;
    foreach my $filetype ( filetypes() ) {
        my @filespecs = grep ( {/\.$filetype/sx} @all_filespecs );
        $mtime_of{$filetype}
          = jk( sort map { $self->_get_mtime($_) } @filespecs );
        $filespecs_of{$filetype} = \@filespecs;
    }

    emit_done;

    $self->_set_filespecs_r( \%filespecs_of );
    $self->_set_mtimes_r( \%mtime_of );

    return;
} ## tidy end: sub _build_filespecs_and_mtimes

sub _get_mtime {
    my $self     = shift;
    my $filespec = shift;
    my @stat     = stat($filespec);
    unless ( scalar @stat ) {
        emit_error;
        croak "Could not get file status for $filespec";
    }
    my $file = filename($filespec);
    return jk( $file, $stat[$STAT_MTIME] );
}

sub DEMOLISH {
    my $self = shift;
    my $dbh  = $self->dbh;
    $dbh->disconnect();
    return;
}

#########################################
### LOAD FLAT FILES (if necessary)
#########################################

sub load {
    my ( $self, @rowtypes ) = @_;
    $self->_ensure_loaded($_) foreach @rowtypes;
}

sub _ensure_loaded {
    my $self    = shift;
    my $rowtype = shift;

    my $filetype = filetype($rowtype);

    if ( not defined $filetype ) {
        emit_error;
        $rowtype //= 'undef';
        croak "Tried to read nonexistent rowtype $rowtype";
    }

    return if ( $self->_is_loaded($filetype) );

    # If they're changed, read the flat files

    my $dbh = $self->dbh();
    my ($stored_mtimes) = (
             $dbh->selectrow_array( $SQL_FETCH_MTIMES, {}, $filetype )
          or $EMPTY_STR
    );

    if ( $stored_mtimes ne $self->_mtimes($filetype) ) {
        
        # erase data of filetype
        
        $self->_put_flats_in_db($filetype);
    }

    # now that we've checked, mark them as loaded
    $self->_mark_loaded($filetype);

    return;

} ## tidy end: sub _ensure_loaded

sub _put_flats_in_db {
    my $self     = shift;
    my $filetype = shift;
    my $dbh      = $self->dbh();

    my @filespecs = $self->_filespecs_of($filetype);

    local $INPUT_RECORD_SEPARATOR = $CRLF;

    emit "Reading HastusASI $filetype files";

    my ( %sth_of, %parent_of );
    foreach my $rowtype ( rowtypes_of($filetype) ) {
        $dbh->do("DELETE FROM $rowtype");
        $sth_of{$rowtype}    = $dbh->prepare( table_insert_query($rowtype) );
        $parent_of{$rowtype} = parent($rowtype);
    }

    my $sequence = 0;
    $dbh->do($SQL_BEGIN);

  FILE:
    foreach my $file (@filespecs) {

        my $fn = filename($file);

        my $size                = -s $file;
        my $display_after_lines = int(
            $size / ( 2 * $OCCASIONS_TO_DISPLAY * $AVERAGE_CHARS_PER_LINE ) );

        my $result = open my $fh, '<', $file;
        if ( not $result ) {
            emit_error;
            croak "Can't open $file for reading: $OS_ERROR";
        }

        my %template_of = $self->_build_templates( $fh, $filetype, $file );

        my $count    = 0;
        my $fraction = 0;
        my %previous_seq_of;

        emit_over "$fn: 0%";

      ROW:
        while (<$fh>) {

            $count++;
            $sequence++;

            #if ( not( $count % 3000 ) ) {
            #    $dbh->do($SQL_END);
            #    $dbh->do($SQL_BEGIN);
            #}
            if ( not( $count % $display_after_lines ) ) {
                my $newfraction
                  = int( tell($fh) / $size * $OCCASIONS_TO_DISPLAY );
                if ( $fraction != $newfraction ) {
                    $fraction = $newfraction;

                    #emit_over "${fraction}0%";
                    emit_over( "$fn: ", $fraction * $DISPLAY_PERCENTAGE_FACTOR,
                        '%' );
                }
            }

            my ( $rowtype, $_ ) = split( /$DELIMITER/sx, $_, 2 );
            unless ( filetype($rowtype) eq $filetype ) {
                carp "Incorrect row type $rowtype in file $file, "
                  . "row $INPUT_LINE_NUMBER:\n$_\n";
                set_term_pos(0);
                next ROW;
            }

            $previous_seq_of{$rowtype} = $sequence;

            my @columns = unpack( $template_of{$rowtype}, $_ );
            s/\A\s+//s foreach @columns;

            if ( has_repeating_final_column($rowtype) ) {
                my @finals = splice( @columns, scalar( columns($rowtype) ) );
                push @columns, jk( grep { $_ ne $EMPTY_STR } @finals );
            }

            my $parent = $parent_of{$rowtype};
            if ($parent) {
                unshift @columns, $previous_seq_of{$parent};
            }

            if ( key_exists($rowtype) ) {
                push @columns, jk( @columns[ key_column_order($rowtype) ] );
            }

            $sth_of{$rowtype}->execute( $sequence, @columns );

        }    # ROW
        if ( not close $fh ) {
            emit_error;
            croak "Can't close $file for reading: $OS_ERROR";
        }

        emit_over "$fn: 100%";

    }    # FILE

    $dbh->do( $SQL_DELETE_MTIMES, {}, $filetype );
    $dbh->do( $SQL_INSERT_MTIMES, {}, $filetype, $self->_mtimes($filetype) );

    $dbh->do($SQL_END);

    emit_done;

    return;

} ## tidy end: sub _put_flats_in_db

sub _build_templates {
    my ( $self, $fh, $filetype, $file ) = @_;

    my %template_of;

    # determine number of columns
    foreach my $rowtype ( rowtypes_of($filetype) ) {
        my $numcolumns = scalar( columns($rowtype) ) + 1;  # add one for rowtype
        $numcolumns += $EXTRA_FIELDS_WHEN_REPEATING
          if has_repeating_final_column($rowtype);

        while ( not $template_of{$rowtype} ) {
            my $line = <$fh>;
            last unless $line;
            chomp $line;
            my @columns = split( /$DELIMITER/sx, $line );
            if ( @columns == $numcolumns ) {
                $template_of{$rowtype} = join( $DELIMITER_TEMPLATE_PAD,
                    map { 'A' . length } @columns[ 1 .. $#columns ] );
            }

        }
        if ( not $template_of{$rowtype} ) {
            emit_error;
            croak
"Unable to determine columns of $rowtype (never found a line with the right number)";
        }

        if ( not seek $fh, 0, 0 ) {
            emit_error;
            croak "Couldn't return seek position to top of $file: $OS_ERROR";
        }

    } ## tidy end: foreach my $rowtype ( rowtypes_of...)

    return %template_of;

} ## tidy end: sub _build_templates

#########################################
### PROVIDE ROWS TO CALLERS
#########################################

sub each_row_like {
    my ( $self, $rowtype, $column, $match ) = @_;
    $self->_check_column( $rowtype, $column );
    return $self->each_row_where( $rowtype,
        "WHERE $column LIKE ? ORDER BY $column", $match );
}

sub each_row_eq {
    my ( $self, $rowtype, $column, $value ) = @_;
    $self->_check_column( $rowtype, $column );
    return $self->each_row_where( $rowtype,
        "WHERE $column = ? ORDER BY $column", $value );
}

sub each_row {
    my ( $self, $rowtype ) = @_;
    return $self->each_row_where($rowtype);
}

sub each_row_where {
    my ( $self, $rowtype, $where, @bind_values ) = @_;

    $self->_ensure_loaded($rowtype);
    my $dbh = $self->dbh();

    my $query = "SELECT * FROM $rowtype ";
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
    my ( $self, $rowtype, $column ) = @_;
    return if $column eq "${rowtype}_id";
    return if $column eq "${rowtype}_key" and key_exists($rowtype);

    my $parent = parent($rowtype);
    return if $parent and $column eq "${parent}_id";

    my @columns = columns($rowtype);
    croak "Invalid column $column for rowtype $rowtype"
      if not $column ~~ @columns;
    return;
}

sub row {
    my ( $self, $rowtype, $key ) = @_;
    $self->_ensure_loaded($rowtype);
    my $dbh   = $self->dbh();
    my $query = "SELECT * FROM $rowtype WHERE ${rowtype}_key = ?";
    return $dbh->selectrow_hashref( $query, {}, $key );
}

sub columnnames {
    my $self    = shift;
    my $rowtype = shift;
    return columns($rowtype);
}

sub has_key {
    my $self    = shift;
    my $rowtype = shift;
    return key_exists($rowtype);
}

#########################################
### UTILITY METHODS
#########################################

sub _make_filespec {
    my $self     = shift;
    my $filename = shift;
    return File::Spec->catfile( $self->dir(), $filename );
}

sub _build_dbfilename {
    my $self = shift;
    my $dbfilename = $self->_dbfileprefix() || $EMPTY_STR;
    
    if (not ( $dbfilename =~ /\.db\z/ or $dbfilename =~ /\.sqlite/ ) ) {
       $dbfilename .= $DEFAULT_DBFILENAME;
    }
    
}

sub _build_dbfilespec {
    my $self = shift;
    my $dbfilename = $self->_dbfilename();
    my ($volume, $path, $filename) = File::Spec->splitpath($dbfilename);
    
    if ($volume or $path) {
        return $dbfilename;
    }
    return $self->_make_filespec( $filename);
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
