# Actium/Files/HastusASI.pm

# Class for reading and processing Hastus Standard AVL files
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Actium::Constants;
use Actium::Files;
use Actium::Term;
use Actium::Util qw(j jk);
use Carp;
use DBI;
use English '-no_match_vars';
use File::Glob qw(:glob);
use File::Spec;
use Readonly;

use Actium::Files::HastusASI::Definition ('definition_objects'); 

# set some constants
Readonly my $NO_PARENT                   => 'noparent';
Readonly my $DELIMITER                   => q{,};
Readonly my $DELIMITER_LENGTH            => length($DELIMITER);
Readonly my $DELIMITER_TEMPLATE_PAD      => 'x' x $DELIMITER_LENGTH;
Readonly my $STAT_MTIME                  => 9;
Readonly my $EXTRA_FIELDS_WHEN_REPEATING => 49;
Readonly my $OCCASIONS_TO_DISPLAY        => 20;
Readonly my $AVERAGE_CHARS_PER_LINE      => 20;
Readonly my $DISPLAY_PERCENTAGE_FACTOR   => 100 / $OCCASIONS_TO_DISPLAY;

with 'Actium::Db::SQLite';

my (%tables, %filetypes) = definition_objects();

{    # scoping for these definition variables

    my ( %parent_of,        %children_of );
    my ( %filetype_of,      %tables_of );
    my ( %columns_of,       %column_order_of );
    my ( %keycolumn_of,     %has_multiple_keycolumns );
    my ( %key_columns_of,   %key_column_order_of );
    my ( %sql_insertcmd_of, %sql_createcmd_of, %sql_idxcmd_of );
    my (%has_repeating_final_column);

    # these are processed when file is read
    
    # TODO - change these methods to be delegations to table methods

#########################################
### CLASS METHODS FROM DEFINIITION
#########################################
# (actually, the methods just ignore their invocant)

    # db_type required by SQLite role
    sub db_type () {'HastusASI'}

    # keycolumn_of_table required by SQLite role
    sub keycolumn_of_table {
        my $self  = shift;
        my $table = shift;
        return $keycolumn_of{$table};
    }

    # columns_of_table required by SQLite role
    sub columns_of_table {
        my $self  = shift;
        my $table = shift;
        return @{ $columns_of{$table} };
    }

    # _tables_of_filetype required by SQLite role
    sub _tables_of_filetype {
        my $self     = shift;
        my $filetype = shift;
        return @{ $tables_of{$filetype} };
    }

    sub _filetypes {
        my $self = shift;
        return keys %tables_of;
    }

    sub _filetype_of_table {
        my $self  = shift;
        my $table = shift;
        return $filetype_of{$table};
    }

    sub parent_of_table {
        my $self  = shift;
        my $table = shift;
        return $parent_of{$table};
    }

    sub _has_repeating_final_column {
        my $self  = shift;
        my $table = shift;
        return $has_repeating_final_column{$table};
    }

    sub _has_multiple_keycolumns {
        my $self  = shift;
        my $table = shift;
        return $has_multiple_keycolumns{$table};
    }

    sub _create_query_of_table {
        my $self  = shift;
        my $table = shift;
        return $sql_createcmd_of{$table};
    }

    sub _insert_query_of_table {
        my $self  = shift;
        my $table = shift;
        return $sql_insertcmd_of{$table};
    }

    sub _index_query_of_table {
        my $self  = shift;
        my $table = shift;
        return $sql_idxcmd_of{$table};
    }

    #sub key_columns {
    #    my $self = shift;
    #    my $table = shift;
    #    return unless $key_columns_of{$table};
    #    return @{ $key_columns_of{$table} };
    #}

    sub _key_column_order_of_table {
        my $self  = shift;
        my $table = shift;
        return @{ $key_column_order_of{$table} };
    }

}    # end scoping of definition variables

######################################
### FILES LIST
######################################

has '_files_of_filetype_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    handles => { '_files_of_filetype_r' => 'get' },
    builder => '_build_files_list',
);

# _files_of_filetype required by SQLite role
sub _files_of_filetype {
    my $self     = shift;
    my $filetype = shift;
    my $files_r  = $self->_files_of_filetype_r($filetype);
    return @{$files_r};
}

sub _build_files_list {
    my $self         = shift;
    my $flats_folder = $self->flats_folder();

    emit 'Assembling lists of filenames';

    my @all_files
      = bsd_glob( $self->_flat_filespec(q<*>), GLOB_NOCASE | GLOB_NOSORT );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak 'Error reading list of filenames in Hastus AVL Standard '
          . "folder $flats_folder: $OS_ERROR";
    }

    if ( not scalar @all_files ) {
        emit_error;
        croak "No files found in Hastus AVL Standard folder $flats_folder";
    }

    @all_files = map { Actium::Files::filename($_) } @all_files;

    my %files_of;
    foreach my $filetype ( $self->_filetypes() ) {
        my @files = grep ( {/\.$filetype/sx} @all_files );
        $files_of{$filetype} = \@files;
    }

    emit_done;

    return \%files_of;

} ## tidy end: sub _build_files_list

#########################################
### LOAD FLAT FILES (if necessary)
#########################################

# _load required by SQLite role
sub _load {
    my $self     = shift;
    my $filetype = shift;
    my @files    = @_;
    my $dbh      = $self->dbh();

    local $INPUT_RECORD_SEPARATOR = $CRLF;

    emit "Reading HastusASI $filetype files";

    my ( %sth_of, %parent_of, %key_column_order_of, %has_multiple_keycolumns,
        %has_repeating_final_column );
    foreach my $table ( $self->_tables_of_filetype($filetype) ) {

        my @queries = (
            $self->_create_query_of_table($table),
            $self->_index_query_of_table($table),
        );
        $dbh->do($_) foreach @queries;

        $sth_of{$table}    = $dbh->prepare( $self->insert_query_of_table($table) );
        $parent_of{$table} = $self->parent_of_table($table);
        $has_multiple_keycolumns{$table}
          = $self->_has_multiple_keycolumns($table);
        $has_repeating_final_column{$table}
          = $self->_has_repeating_final_column($table);
        $key_column_order_of{$table}
          = $self->_key_column_order_of_table($table);

    }

    my $sequence = 0;
    $self->begin_transaction;

  FILE:
    foreach my $file (@files) {

        my $filespec = $self->flat_filespec($file);

        my $size                = -s $filespec;
        my $display_after_lines = int(
            $size / ( 2 * $OCCASIONS_TO_DISPLAY * $AVERAGE_CHARS_PER_LINE ) );

        my $result = open my $fh, '<', $filespec;
        if ( not $result ) {
            emit_error;
            croak "Can't open $filespec for reading: $OS_ERROR";
        }

        my %template_of = $self->_build_templates( $fh, $filetype, $filespec );

        my $count    = 0;
        my $fraction = 0;
        my %previous_seq_of;

        emit_over "$file: 0%";

      ROW:
        while (<$fh>) {

            $count++;
            $sequence++;

            if ( not( $count % $display_after_lines ) ) {
                my $newfraction
                  = int( tell($fh) / $size * $OCCASIONS_TO_DISPLAY );
                if ( $fraction != $newfraction ) {
                    $fraction = $newfraction;

                    #emit_over "${fraction}0%";
                    emit_over( "$file: ",
                        $fraction * $DISPLAY_PERCENTAGE_FACTOR, '%' );
                }
            }

            my ( $table, $_ ) = split( /$DELIMITER/sx, $_, 2 );
            unless ( _filetype_of_table($table) eq $filetype ) {
                carp "Incorrect row type $table in file $filespec, "
                  . "row $INPUT_LINE_NUMBER:\n$_\n";
                set_term_pos(0);
                next ROW;
            }

            $previous_seq_of{$table} = $sequence;

            my @columns = unpack( $template_of{$table}, $_ );
            s/\A\s+//s foreach @columns;

            if ( $has_repeating_final_column{$table} ) {
                my @finals = splice( @columns, scalar( columns($table) ) );
                push @columns, jk( grep { $_ ne $EMPTY_STR } @finals );
            }

            my $parent = $parent_of{$table};
            if ($parent) {
                unshift @columns, $previous_seq_of{$parent};
            }

            if ( $has_multiple_keycolumns{$table} ) {
                push @columns,
                  jk( @columns[ @{ $key_column_order_of{$table} } ] );
            }

            $sth_of{$table}->execute( $sequence, @columns );

        }    # ROW
        if ( not close $fh ) {
            emit_error;
            croak "Can't close $filespec for reading: $OS_ERROR";
        }

        emit_over "$file: 100%";

    }    # FILE

    $self->end_transaction;

    emit_done;

    return;

} ## tidy end: sub _load

sub _build_templates {
    my ( $self, $fh, $filetype, $filespec ) = @_;

    my %template_of;

    # determine number of columns
    foreach my $table ( $self->tables_of_filetype($filetype) ) {
        my $numcolumns = scalar( columns($table) ) + 1;    # add one for table
        $numcolumns += $EXTRA_FIELDS_WHEN_REPEATING
          if $self->has_repeating_final_column($table);

        while ( not $template_of{$table} ) {
            my $line = <$fh>;
            last unless $line;
            chomp $line;
            my @columns = split( /$DELIMITER/sx, $line );
            if ( @columns == $numcolumns ) {
                $template_of{$table} = join( $DELIMITER_TEMPLATE_PAD,
                    map { 'A' . length } @columns[ 1 .. $#columns ] );
            }

        }
        if ( not $template_of{$table} ) {
            emit_error;
            croak "Unable to determine columns of $table in $filespec\n"
              . "(never found a line with the right number)";
        }

        if ( not seek $fh, 0, 0 ) {
            emit_error;
            croak
              "Couldn't return seek position to top of $filespec: $OS_ERROR";
        }

    } ## tidy end: foreach my $table ( $self->tables_of_filetype...)

    return %template_of;

} ## tidy end: sub _build_templates

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;
