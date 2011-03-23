# Actium/Files/HastusASI.pm

# Routines for reading and processing Hastus Standard AVL files
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

#########################################
### DEFINITION
#########################################

my $DEFINITION = <<'ENDNAMES'
 CAL CAL noparent
 8 StartDate 
 8 EndDate 
 8 SchedulingUnit 
 8 ScheduleSet

 DAT CAL CAL
 8 Date!
 8 SchedulingUnit!
 8 CrewScheduleName
10 CrewScheduleType
 2 CrewScheduleTypeValue
 2 CrewScheduleScenario
 6 CrewScheduleBooking
 8 VehicleScheduleName
10 VehicleScheduleType
 2 VehicleScheduleTypeValue
 2 VehicleScheduleScenario
 6 VehicleScheduleBooking

 STP NDE noparent
 8 Identifier!
50 Description 
 6 Place
10 XCoordinate
10 YCoordinate
50 IntersectingStreetAtSegmentBeginning
50 IntersectingStreetAtSegmentEnd
 5 DistanceToIntersection
 4 SegmentOffset
 6 District
 8 Zone
 1 IsPublic
 5 DistanceFromIntersectionAtBeginning
 5 DistanceFromIntersectionAtEnd

 PLC PLC noparent
 6 Identifier!
 40 Description
 6 ReferencePlace
 6 District
 8 Number
20 AlternateName
10 XCoordinate
10 YCoordinate

 PPAT PPAT noparent
 5 Route!
10 Direction
 2 DirectionValue!
 6 RouteMainPlacePatternDirection
 6 RouteMainPlacePatternPlace*

 DIS NET noparent
 8 StartStop!
 8 EndStop!
 8 Distance

 SHA NET DIS
10 XCoordinate
10 YCoordinate

 RTE RTE noparent
 5 Identifier!
 5 PublicIdentifier
10 ServiceType
 2 ServiceTypeValue
10 ServiceMode
 2 ServiceModeValue

 PAT PAT noparent
 5 Route!
 4 Identifier!
10 Direction
 2 DirectionValue
 8 VehicleDisplay
 1 IsInService
 8 Via
40 ViaDescription

 TPS PAT PAT
 5 StopIdentifier
 6 Place
 8 VehicleDisplay
 1 IsATimingPoint
 1 IsRoutingPoint

 VDC VDC noparent
 8 Identifier!
 8 AlternateCode
40 Message1
40 Message2
40 Message3
40 Message4

 VSC BLK noparent
 8 Name!
10 ScheduleType
 2 ScheduleTypeValue!
 2 Scenario!
 8 Booking!
 8 SchedulingUnit
40 Description

 BLK BLK VSC
 8 Number!
10 InternalNumber
 7 OperatingDays!
 6 StartPlace
 5 StartTime!
 6 InServiceStartPlace
 5 InServiceStartTime
 6 InServiceEndPlace
 5 InServiceEndTime
 6 EndPlace
 5 EndTime
 4 VehicleGroup
 4 VehicleType
 8 VehicleNumber

 TIN BLK BLK
10 InternalNumber

 TRP TRP noparent
10 InternalNumber!
 8 Number
 7 OperatingDays
 5 RouteForStatistics
 4 Pattern
15 Type
 2 TypeValue
 1 IsSpecial
 1 IsPublic

 PTS TRP TRP
 8 PassingTime

 CSC CRW noparent
 8 Name!
10 ScheduleType
 2 ScheduleTypeValue!
 2 Scenario!
 8 Booking!
 8 SchedulingUnit
40 Description

 PCE CRW CSC
 8 DutyIdentifier!
10 InternalNumber
 7 DutyOperatingDays
10 BlockInternalNumber
 5 Position!
 6 ReportPlace
 5 ReportTime
 6 StartPlace
 5 StartTime
 6 EndPlace
 5 EndTime
 6 ClearPlace
 5 ClearTime

 ASG RAS noparent
 8 EffectiveStartWeek
 6 Division

 RAS RAS ASG
 8 RosterSetIdentifier!
 6 RosterIdentifier!
10 PositionIdentifier!
 4 SequenceInWeek!
 8 CurrentDate
10 DutyInternalNumber
 8 EmployeeIdentifier

 EMP EMP noparent
 8 Identifier!
20 Fullname
 8 DisplayIdentfier

 DWP CRW noparent
 3 DutyNumber!
 8 BlockNumber!
 8 EmployeeDisplayIdentifier
 6 StartPlace
 5 StartTime
 6 ReportPlace
 5 ReportTime
 6 EndPlace
 5 EndTime
 6 ClearPlace
 5 ClearTime
         
ENDNAMES
  ;

# TABLE FILE PARENT
# COLUMNLENGTH COLUMNNAME
# COLUMNLENGTH COLUMNNAME
# etc.

# Currently the COLUMNLENGTHs are not used, because I cannot
# depend on them from signup to signup.

# COLUMNNAME! - column is a key column
# COLUMNNAME* - column is a final, repeating column
#   (contains more than one value)

#########################################
### PROCESS DEFINITION INTO HASHES
#########################################

# These all refer to a table, except %tables_of, which is of a filetype.

{    # scoping for these definition variables

    my ( %parent_of,        %children_of );
    my ( %filetype_of,      %tables_of );
    my ( %columns_of,       %column_order_of );
    my ( %keycolumn_of,     %has_multiple_keycolumns );
    my ( %key_columns_of,   %key_column_order_of );
    my ( %sql_insertcmd_of, %sql_createcmd_of, %sql_idxcmd_of );
    my (%has_repeating_final_column);

    # these are processed when file is read

    # READ DEFINITION

    local $INPUT_RECORD_SEPARATOR = $EMPTY_STR;    # paragraph mode

    open my $definition_h, '<', \$DEFINITION
      or die "Can't open internal variable for reading: $OS_ERROR";

  TABLE:
    while (<$definition_h>) {
        my @entries = split;

        # get row type length and column type
        my ( $table, $filetype, $parent )
          = splice( @entries, 0, 3 );    ## no critic (ProhibitMagicNumbers)

        $filetype_of{$table} = $filetype;
        push @{ $tables_of{$filetype} }, $table;

        # is this a child?
        if ( $parent ne $NO_PARENT ) {
            $parent_of{$table} = $parent;
            push @{ $children_of{$parent} }, $table;
        }

        my $column_order = 0;

      COLUMN:
        while (@entries) {

            # get items from entries
            my $column_length = shift @entries;    # ignored
            my $column        = shift @entries;

            # if it's a key column, put that in hashes
            if ( $column =~ /!\z/s ) {
                $column =~ s/!\z//s;
                push @{ $key_columns_of{$table} },      $column;
                push @{ $key_column_order_of{$table} }, $column_order;
            }

            # put column type and order into hashes
            $columns_of{$table}[$column_order] = $column;
            $column_order_of{$table}{$column} = $column_order;

            $column_order++;

        } ## tidy end: while (@entries)

        # if there's a key, save name of key. If only one column is used
        # as the key, save that name. Otherwise, create a new column called
        # TABLE_key (e.g., PAT_key, BLK_key, etc.)

        given ( scalar @{ $key_columns_of{$table} } ) {
            when (0) {
                # do nothing
            }
            when (1) {
                $keycolumn_of{$table}            = $key_columns_of{$table}[0];
                $has_multiple_keycolumns{$table} = 0;
            }
            default {
                $has_multiple_keycolumns{$table} = 1;
                $keycolumn_of{$table}            = "${table}_key";
            }
        }

        # if final column is repeating, save that
        if ( $columns_of{$table}[-1] =~ /\*\z/s ) {
            $columns_of{$table}[-1] =~ s/\*\z//s;    # remove * marker
            $has_repeating_final_column{$table} = 1;
        }
    } ## tidy end: while (<$definition_h>)

    ## CREATE SQL COMMANDS

    foreach my $table ( keys %filetype_of ) {

        my @create_columns = @{ $columns_of{$table} };
        my $parent         = $parent_of{$table};
        if ($parent) {
            unshift @create_columns, "${parent}_id INTEGER";
        }

        my $key = $keycolumn_of{$table};

        if ($key) {
            push @create_columns, $key
              if $has_multiple_keycolumns{$table};
            $sql_idxcmd_of{$table}
              = "CREATE INDEX idx_${table}_key ON $table ($key)";
        }

        unshift @create_columns, "${table}_id INTEGER PRIMARY KEY";

        $sql_createcmd_of{$table}
          = "CREATE TABLE $table (" . join( q{,}, @create_columns ) . q{)};

        $sql_insertcmd_of{$table} = "INSERT INTO $table VALUES ("
          . join( q{,}, ('?') x @create_columns ) . ')';

    } ## tidy end: foreach my $table ( keys %filetype_of)

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
