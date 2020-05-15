# Actium/Files/HastusASI/Definition.pm

# Definition of Hastus ASI tables and file types

# Subversion: $Id$

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Definition 0.001;

use English ('-no_match_vars');
use Actium::Constants;

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

#my ( %parent_of,        %children_of );
#my ( %filetype_of,      %tables_of );
#my ( %columns_of,       %column_order_of );
#my ( %keycolumn_of,     %has_multiple_keycolumns );
#my ( %key_columns_of,   %key_column_order_of );
#my ( %sql_insertcmd_of, %sql_createcmd_of, %sql_idxcmd_of );
#my (%has_repeating_final_column);

# these are processed when file is read

# READ DEFINITION

sub definition {
 
my %table;
my %filetype;

local $INPUT_RECORD_SEPARATOR = $EMPTY_STR;    # paragraph mode

open my $definition_h, '<', \$DEFINITION
  or die "Can't open internal variable for reading: $OS_ERROR";

TABLE:
while (<$definition_h>) {
    my @entries = split;
    
    my %thistable;
    
    # get row type length and column type
    my ( $table, $filetype, $parent )
      = splice( @entries, 0, 3 );    ## no critic (ProhibitMagicNumbers)
      
    $thistable{filetype} = $filetype;
    push @{$filetype{$filetype}{tables_r}} , $table;
    
    # is this a child?
    if ( $parent ne 'noparent' ) {
        $thistable{parent} = $parent;
        push @{ $table{$parent}{children_r} }, $table;
    }
    else {
        $thistable{parent} = undef;
    }
     
    my $column_order = 0;

  COLUMN:
    while (@entries) {

        # get items from entries
        my $column_length = shift @entries;
        my $column        = shift @entries;
        
        $thistable{column_length} = $column_length;

        # if it's a key column, put that in hashes
        if ( $column =~ /!\z/s ) {
            $column =~ s/!\z//s;
            push @{ $thistable{key_columns_r}  },      $column;
            push @{ $thistable{key_column_order_r} }, $column_order;
        }

        # save column type and order
        push @{$thistable{columns_r}} , $column;
        $thistable{column_order_r}{$column} = $column_order;
        
        $column_order++;

    } ## tidy end: while (@entries)

    # if there's a key, save name of key. If only one column is used
    # as the key, save that name. Otherwise, create a new column called
    # TABLE_key (e.g., PAT_key, BLK_key, etc.)

    given ( scalar @{ $thistable{key_columns_r} } ) {
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

}

1;
