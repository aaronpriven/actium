# Actium/HastusASI/Columns.pm

# Information about the columns in Hastus AVL Standard Interface files

# Subversion: $Id$

# this file should not be used in new programming. 
# Code using it should replace it with Actium::Files::HastusASI

# Legacy stage 3

use strict;
use warnings;

package Actium::HastusASI::Columns;

use 5.010;    # turns on features

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Actium::Constants;
use English '-no_match_vars';
use Readonly;

#use Exporter qw( import );
#our @EXPORT_OK = qw(
#  rowtypes filetypes filetype parent
#  has_repeating_final_column columns
#  table_create_query table_insert_query
#  table_create_queries
#  rowtypes_of
#  key_columns key_column_order
#);
#our %EXPORT_TAGS = ( all => \@EXPORT_OK );

use Perl6::Export::Attrs;

Readonly my $NO_PARENT => q{noparent};

#########################################
### ROWS, COLUMN NAMES, AND LENGTHS
#########################################

my $COLUMNS = <<'ENDNAMES'
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

# ROWTYPE FILE PARENT
# COLUMNLENGTH COLUMNNAME
# COLUMNLENGTH COLUMNNAME
# etc.

# Currently the COLUMNLENGTHs are not used, because I cannot
# depend on them from signup to signup.

# COLUMNNAME! - column is a key column
# COLUMNNAME* - column is a final, repeating column
#   (contains more than one value)

#########################################
### PROCESS ROW DATA INTO HASHES
#########################################

# These all refer to a rowtype, except %rowtypes_of, which is of a filetype.

my ( %parent_of,        %children_of );
my ( %filetype_of,      %rowtypes_of );
my ( %columns_of,       %column_order_of );
my ( %key_columns_of,   %key_column_order_of );
my ( %sql_insertcmd_of, %sql_createcmd_of, %sql_idxcmd_of );
my (%has_repeating_final_column);

{    # scoping

    local $INPUT_RECORD_SEPARATOR = $EMPTY_STR;    # paragraph mode

    open my $columns_h, '<', \$COLUMNS
      or die "Can't open internal variable for reading: $OS_ERROR";

  ROW_TYPE:
    while (<$columns_h>) {
        my @entries = split;

        # get row type length and column type
        my ( $row_type, $file, $parent )
          = splice( @entries, 0, 3 );    ## no critic (ProhibitMagicNumbers)

        $filetype_of{$row_type} = $file;
        push @{ $rowtypes_of{$file} }, $row_type;

        # is this a child?
        if ( $parent ne $NO_PARENT ) {
            $parent_of{$row_type} = $parent;
            push @{ $children_of{$parent} }, $row_type;
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
                push @{ $key_columns_of{$row_type} },      $column;
                push @{ $key_column_order_of{$row_type} }, $column_order;
            }

            # put column type and order into hashes
            $columns_of{$row_type}[$column_order] = $column;
            $column_order_of{$row_type}{$column} = $column_order;

            $column_order++;

        } ## tidy end: while (@entries)

        # if final column is repeating, save that
        if ( $columns_of{$row_type}[-1] =~ /\*\z/s ) {
            $columns_of{$row_type}[-1] =~ s/\*\z//s;    # remove * marker
            $has_repeating_final_column{$row_type} = 1;
        }
    } ## tidy end: while (<$columns_h>)

    # CREATE SQL COMMANDS
    foreach my $row_type ( keys %filetype_of ) {

        my @create_columns = @{ $columns_of{$row_type} };
        my $parent         = $parent_of{$row_type};
        if ($parent) {
            unshift @create_columns, "${parent}_id INTEGER";
        }

        if ( $key_columns_of{$row_type} ) {
            push @create_columns, "${row_type}_key";
            $sql_idxcmd_of{$row_type}
              = "CREATE INDEX idx_${row_type}_key ON $row_type (${row_type}_key)";
        }

        unshift @create_columns, "${row_type}_id INTEGER PRIMARY KEY";

        $sql_createcmd_of{$row_type}
          = "CREATE TABLE $row_type (" . join( q{,}, @create_columns ) . q{)};

        $sql_insertcmd_of{$row_type} = "INSERT INTO $row_type VALUES ("
          . join( q{,}, ('?') x @create_columns ) . ')';

    } ## tidy end: foreach my $row_type ( keys...)

}    # scoping

#########################################
### FUNCTIONS
#########################################

sub rowtypes : Export {
    return keys %filetype_of;
}

sub rowtypes_of : Export {
    my $filetype = shift;
    return @{ $rowtypes_of{$filetype} };
}

sub filetypes : Export {
    return keys %rowtypes_of;
}

sub filetype : Export {
    my $rowtype = shift;
    return $filetype_of{$rowtype};
}

sub parent : Export {
    my $rowtype = shift;
    return $parent_of{$rowtype};
}

sub key_exists : Export {
    my $rowtype = shift;
    return exists $key_columns_of{$rowtype};
}

sub has_repeating_final_column : Export {
    my $rowtype = shift;
    return $has_repeating_final_column{$rowtype};
}

sub columns : Export {
    my $rowtype = shift;
    return @{ $columns_of{$rowtype} };
}

sub table_create_query : Export(:SQL) {
    my $rowtype = shift;
    return $sql_createcmd_of{$rowtype};
}

sub table_insert_query : Export(:SQL) {
    my $rowtype = shift;
    return $sql_insertcmd_of{$rowtype};
}

sub table_create_queries : Export(:SQL) {
    my $rowtype = shift;
    return values %sql_createcmd_of;
}

sub table_index_queries : Export(:SQL) {
    my $rowtype = shift;
    return values %sql_idxcmd_of;
}

sub key_columns : Export {
    my $rowtype = shift;
    return unless $key_columns_of{$rowtype};
    return @{ $key_columns_of{$rowtype} };
}

sub key_column_order : Export {
    my $rowtype = shift;
    return @{ $key_column_order_of{$rowtype} };
}
1;
