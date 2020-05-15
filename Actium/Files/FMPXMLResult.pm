# Actium/Files/FMPXMLResult.pm

# Class for reading and processing FileMaker Pro FMPXMLRESULT XML exports
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

BEGIN {

    #use Devel::NYTProf;
    #DB::disable_profile();
}

use warnings;
use 5.012;    # turns on features

package Actium::Files::FMPXMLResult 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use POSIX ();

use Actium::Constants;
use Actium::Files;
use Actium::Files::SQLite::Table;
use Actium::Term;
use Actium::Util('jk');
use Readonly;
use File::Glob qw(:glob);
use Carp;
use English '-no_match_vars';
use Storable;
use DBI (':sql_types');
use XML::Twig;

Readonly my $EXTENSION => '.xml';

#requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype
#       _filetype_of_table is_a_table/
#);

use constant db_type => 'FileMaker';

# I think all the FileMaker exports will be the same database type

use constant parent_of_table => undef;

# TODO: Move to a configuration file of some kind
Readonly my %KEY_OF => (
    Cities        => 'Code',
    Colors        => 'ColorID',
    Lines         => 'Line',
    Neighborhoods => 'Neighborhood',
    Projects      => 'Project',
    SignTypes     => 'SignType',
    Signs         => 'SignID',
    SkedAdds      => 'SkedId',
    Skedidx       => 'SkedId',
    Timepoints    => 'Abbrev4',
    Stops         => 'PhoneID',
);

# Fields separated by slashes (/) will treated as composite keys, e.g.,
# 'Days/Direction" treated as a composite key of Days and Direction
# I'm not sure this will be used, but just in case...

# Just one table per filetype, and file and filetype have the same name
sub _tables_of_filetype {
    my $self  = shift;
    my $table = shift;
    return $table;
}

sub _filetype_of_table {
    my $self  = shift;
    my $table = shift;
    return $table;
}

sub _files_of_filetype {
    my $self  = shift;
    my $table = shift;
    return $table . $EXTENSION;
}

has table_r => (
    is       => 'bare',
    builder  => '_build_table_r',
    lazy     => 1,
    init_arg => undef,
    traits   => ['Hash'],
    isa      => 'HashRef[Bool]',
    handles  => {
        tables     => 'keys',
        is_a_table => 'get',
    },
);

sub _build_table_r {
    my $self         = shift;
    my $flats_folder = $self->flats_folder();

    emit 'Assembling list of filenames';

    my @all_files = bsd_glob( $self->_flat_filespec(qq<*$EXTENSION>),
        GLOB_NOCASE | GLOB_NOSORT );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak 'Error reading list of FileMaker Pro FMPXMLRESULT files in '
          . "folder $flats_folder: $OS_ERROR";
    }

    if ( not scalar @all_files ) {
        emit_error;
        croak
          "No FileMaker Pro FMPXMLRESULT files found in folder $flats_folder";
    }

    @all_files = map { Actium::Files::filename($_) } @all_files;

    my %tables;

    foreach my $file (@all_files) {
        my $table = $file;
        $table =~ s/$EXTENSION\z//sx;
        $tables{$table} = 1;
    }

    emit_done;

    return \%tables;

}    ## tidy end: sub _build_table_r

has '_table_obj_of_r' => (
    init_arg => undef,
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Actium::Files::SQLite::Table]',
    default  => sub { {} },
    handles  => {
        _table_obj_of     => 'get',
        _table_objs       => 'values',
        _set_table_obj_of => 'set',
    },
);

sub key_of_table {
    my $self  = shift;
    my $table = shift;
    $self->ensure_loaded($table);
    my $table_obj = $self->_table_obj_of($table);
    return $table_obj->key;
}

sub columns_of_table {
    my $self  = shift;
    my $table = shift;
    $self->ensure_loaded($table);
    my $table_obj = $self->_table_obj_of($table);
    return $table_obj->columns;
}

sub _stored_spec {
    my $self  = shift;
    my $table = shift;
    my $dbh   = $self->dbh;

    my ($spec) = (
        $dbh->selectrow_array( 'SELECT spec FROM tablespec WHERE tablename = ?',
            {}, $table )
          or $EMPTY_STR
    );

    return $spec;
}

# _load required by SQLite roe
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my $table    = $filetype;
    my $file     = $self->_flat_filespec(shift);
    my $dbh      = $self->dbh();

    $dbh->do(
        'CREATE TABLE IF NOT EXISTS tablespec ( tablename TEXT , spec TEXT )');
    my $storedspec = $self->_stored_spec($table);
    $dbh->do( 'DELETE FROM tablespec WHERE tablename = ?', {}, $table )
      if $storedspec;

    emit "Reading FileMaker FMPXMLESULT $filetype";
    emit_over '0% ';

    #DB::enable_profile();

    $self->_load_xml_parser( $filetype, $file );

    #DB::disable_profile();

    emit_over '100% ';
    emit_done;

    return;

}    ## tidy end: sub _load

sub _insert_spec {
    my $self       = shift;
    my $table      = shift;
    my $serialized = shift;
    my $dbh        = $self->dbh;

    my $tablespec_sth =
      $dbh->prepare('INSERT INTO tablespec (tablename, spec) VALUES ( ? , ? )');
    $tablespec_sth->bind_param( 1, $table );
    $tablespec_sth->bind_param( 2, $serialized, SQL_BLOB );
    $tablespec_sth->execute;
    $tablespec_sth->finish;
}

with 'Actium::Files::SQLite';

after 'ensure_loaded' => sub {
    my $self   = shift;
    my @tables = @_;

    foreach my $table (@tables) {
        my $spec_r    = Storable::thaw( $self->_stored_spec($table) );
        my $table_obj = Actium::Files::SQLite::Table->new($spec_r);
        $self->_set_table_obj_of( $table, $table_obj );
    }
    return;

};

# XML::Twig version is nicer... but XML::Parser is 5x faster

#sub _load_xml_twig {
#    my $self     = shift;
#    my $filetype = shift;
#    my $file     = shift;
#    my $table    = $filetype;
#    my $dbh      = $self->dbh();
#
#    my $record_count = 0;
#
#    my (
#        $table_obj, $records_to_import, $emit_increment,
#        $next_emit, $insert_sth,        $has_composite_key,
#    );
#
#    # These callback definitions are inside '_load_' so they have access
#    # to lexical variables
#
#    my $resultset_callback = sub {
#        my $twig = shift;
#        my $elt  = shift;
#        $records_to_import = $elt->att('FOUND');
#        $emit_increment    = POSIX::ceil( $records_to_import / 25 );
#        $next_emit         = $emit_increment;
#        return;
#    };
#
#    my $metadata_callback = sub {
#        my $twig     = shift;
#        my $metadata = shift;
#        my %spec     = (
#            id               => $table,
#            filetype         => $filetype,
#            key_components_r => [ split( m{/}s, $KEY_OF{$table} ) ],
#        );
#
#        my $idx = 0;
#
#        foreach my $field ( $metadata->children('FIELD') ) {
#            my $name = $field->att('NAME');
#            push @{ $spec{columns_r} }, $name;
#            $spec{column_repetitions_of_r}{$name} = $field->att('MAXREPEAT');
#            $spec{column_type_of_r}{$name}        = $field->att('TYPE');
#        }
#
#        $twig->purge;
#
#        $table_obj = Actium::Files::SQLite::Table->new( \%spec );
#        $self->_set_table_obj_of( $table, $table_obj );
#        $has_composite_key = $table_obj->has_composite_key;
#
#        $dbh->do( $table_obj->sql_createcmd );
#        my $idxcmd = $table_obj->sql_idxcmd;
#        $dbh->do($idxcmd) if $idxcmd;
#
#        my $serialized = Storable::freeze( \%spec );
#
#        $self->_insert_spec( $table, $serialized );
#
#        $insert_sth = $dbh->prepare( $table_obj->sql_insertcmd );
#
#        return;
#    };
#
#    my $row_callback = sub {
#        my $twig = shift;
#        my $row  = shift;
#
#        my @values =
#          map { join( $KEY_SEPARATOR, $_->children_text ) } $row->children;
#
#        if ($has_composite_key) {
#            push @values, jk( @values[ @{ $table_obj->key_components_idxs } ] );
#        }
#
#        $insert_sth->execute( ++$record_count, @values );
#
#        if ( $record_count >= $next_emit ) {
#            $next_emit = $record_count + $emit_increment;
#            emit_over(
#                sprintf( '%2d%%', $record_count / $records_to_import * 100 ) );
#
#            #$twig->purge;
#        }
#
#        $twig->purge;
#
#        return;
#
#    };
#
#    my $twig = XML::Twig->new(
#        twig_roots => { METADATA => 1, RESULTSET => 1 },
#        start_tag_handlers => { RESULTSET => $resultset_callback },
#        twig_handlers      => {
#            METADATA => $metadata_callback,
#            ROW      => $row_callback,
#        }
#    );
#
#    $self->begin_transaction;
#
#    $twig->parsefile($file);
#
#    # all the actual stuff that happens is in the handlers
#
#    $self->end_transaction;
#
#    $twig->purge;
#
#}

sub _load_xml_parser {
    my $self     = shift;
    my $filetype = shift;
    my $file     = shift;
    my $table    = $filetype;
    my $dbh      = $self->dbh();

    my $data_buffer;
    my @row_buffer;
    my $first_data_in_col;    # don't add KEY_SEPARATOR
    my $current_tag;

    my (
        $table_obj, $records_to_import, $emit_increment,
        $next_emit, $insert_sth,        $has_composite_key,
    );

    my %spec = (
        id               => $table,
        filetype         => $filetype,
        key_components_r => [ split( m{/}s, $KEY_OF{$table} ) ],
    );

    my $record_count = 0;

=begin

(Start of METADATA)
Start of FIELD - store attributes in column info
(End of FIELD)
End of METADATA - save column info (create SQL table, etc.)

START OF RESULTSET - store number of records returned
(START OF ROW)
Start of COL - set "beginning of COL" flag. Clear data_buffer.

Start of DATA - unless if "beginning of COL" flag is set, add key separator to
                data_buffer. Unset "beginning of COL" flag.
CHARS - Add chars to buffer
(End of DATA)
End of COL - Move buffer to row_buffer
End of ROW - Save row_buffer into SQL

=end

=cut

    my $start = sub {
        #my $expat   = shift;
        my $element = $_[1];

        if ( $element eq 'DATA' ) {
            if ( not $first_data_in_col ) {
                $data_buffer = "$data_buffer\c]";
            }
            else {
                $first_data_in_col = 0;
            }
        }
        elsif ( $element eq 'COL' ) {
            $first_data_in_col = 1;
            $data_buffer       = q{};
        }
        elsif ( $element eq 'FIELD' ) {
            my %attr = @_;

            my $name = $attr{NAME};
            push @{ $spec{columns_r} }, $name;
            $spec{column_repetitions_of_r}{$name} = $attr{MAXREPEAT};
            $spec{column_type_of_r}{$name}        = $attr{TYPE};
        }
        elsif ( $element eq 'RESULTSET' ) {
            my %attr = @_;

            $records_to_import = $attr{FOUND};
            $emit_increment    = POSIX::ceil( $records_to_import / 25 );
            $next_emit         = $emit_increment;

        }

        return;
    };

    my $end = sub {
        #my $expat   = shift;
        my $element = $_[1];
        return if $element eq 'DATA';

        if ( $element eq 'COL' ) {
            push @row_buffer, $data_buffer;
            $data_buffer = {};
        }
        elsif ( $element eq 'ROW' ) {

            if ($has_composite_key) {
                push @row_buffer,
                  jk( @row_buffer[ @{ $table_obj->key_components_idxs } ] );
            }

            $insert_sth->execute( ++$record_count, @row_buffer );

            if ( $record_count >= $next_emit ) {
                $next_emit = $record_count + $emit_increment;
                emit_over(
                    sprintf(
                        '%2d%%', $record_count / $records_to_import * 100
                    )
                );

            }

            @row_buffer = ();
        }
        elsif ( $element eq 'METADATA' ) {
            $table_obj = Actium::Files::SQLite::Table->new( \%spec );
            $self->_set_table_obj_of( $table, $table_obj );
            $has_composite_key = $table_obj->has_composite_key;

            $dbh->do( $table_obj->sql_createcmd );
            my $idxcmd = $table_obj->sql_idxcmd;
            $dbh->do($idxcmd) if $idxcmd;

            my $serialized = Storable::freeze( \%spec );

            $self->_insert_spec( $table, $serialized );

            $insert_sth = $dbh->prepare( $table_obj->sql_insertcmd );

        }

        return;
    };

    my $char = sub {
        #my $expat  = shift;
        #my $string = shift;
        my $string = $_[1];
        $data_buffer = $data_buffer . $string;
        return;
    };

    my $parser =
      XML::Parser->new(
        Handlers => { Start => $start, End => $end, Char => $char, } );
    $self->begin_transaction;

    $parser->parsefile($file);

    $self->end_transaction;

}

1;
