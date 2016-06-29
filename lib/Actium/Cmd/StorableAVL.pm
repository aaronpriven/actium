#Actium/Cmd/StorableAVL.pm

# All the programs that use the 'avl.storable' file depend on this one.
# This shouild ultimately be replaced

package Actium::Cmd::StorableAVL 0.010;

use Actium::Preamble;

use Text::Trim;    ### DEP ###
use Storable();    ### DEP ###

# set some constants
const my $NO_PARENT        => q{top};
const my $DELIMITER        => q{,};
const my $DELIMITER_LENGTH => length($DELIMITER);

my %is_used;
my %is_a_parent;
my %parent_of;
my %field_names_of;
my %field_lengths_of;
my %field_positions_of;
my %has_repeating_final_field;
my %uses_key;
my %keys_of;
my %template_of;
my %data_of;

sub OPTIONS {
    return ('signup');
}

sub HELP {

    my $helptext = <<'EOF';
readavl reads the files transmitted in the Hastus AVL Standard Interface format,
as described in the Hastus 2006 documentation, and collects it in a structure
readable in perl. See "perldoc readavl" for more information.
EOF

    say $helptext;
    return;

}

sub START {
    
        my ( $class, $env ) = @_;
    my $signup = $env->signup;
    chdir $signup->path();

    say 'Reading from ', $signup->path();

    # set up row type hashes

    init_field_names();
    init_templates();

    my @files = glob('hasi/*');
    @files = grep { not( /\.dump/ix || /\.sqlite\z/ix ) } @files;

    unless (@files) {
        die 'No files found in ' . $signup->path;
    }

    # read rows
    read_files(@files);

    $signup->store( \%data_of, 'avl.storable' );
    
    return;

} ## tidy end: sub START

sub read_files {

    local @ARGV = @_;
    # set up @ARGV for <>;

    # prepare $previous_of so we can add children to parents
    my %previous_of_r;

    local $/ = $CRLF;
    my $prevfile = "";

  ROW:
    while (<>) {
        chomp;

        # DEBUG - print filenames
        if ( $prevfile ne $ARGV ) {
            print "$ARGV\n";
            $prevfile = $ARGV;
        }

        # get row type - everything up to the first delimiter
        m/(.*?)$DELIMITER/x
          or die "Can't find delimiter in line $INPUT_LINE_NUMBER";
        my $row_type = $1;

        next ROW if ( not $is_used{$row_type} );

        #print $template_of{$row_type} , "\n";
        my @fields = unpack( $template_of{$row_type}, $_ );
        trim(@fields);
        my @field_names = @{ $field_names_of{$row_type} };

        my %this_row;

       # assign fields to hash, except 0th field  which is the same as $row_type

        if ( $has_repeating_final_field{$row_type} ) {

            my $final_field_idx = $#field_names;
            my $final_field     = $field_names[-1];

            # assign all but first (0th) and last field
            foreach my $field_idx ( 1 .. $final_field_idx - 1 ) {
                $this_row{ $field_names[$field_idx] }
                  = $fields[$field_idx];
            }

            # assign last field: array of remaining fields
            $this_row{$final_field}
              = [ grep { $_ ne $EMPTY_STR }
                  @fields[ $final_field_idx .. $#fields ] ];

        }

        else {    # no final repeating field

            # assign all but 0th field
            foreach my $field_idx ( 1 .. $#fields ) {
                $this_row{ $field_names[$field_idx] }
                  = $fields[$field_idx];
            }
        }

        my $parent_row_type = $parent_of{$row_type};

        # if there are key fields
        if ( $uses_key{$row_type} ) {

            # hash slice. Gets key fields of $this_row
            my $key
              = join( $KEY_SEPARATOR, @this_row{ @{ $keys_of{$row_type} } } );

            # save into parent's hash, or $data_of if no parent

            if ( $parent_row_type eq $NO_PARENT ) {
                $data_of{$row_type}{$key} = \%this_row;
            }
            else {
                $previous_of_r{$parent_row_type}{$row_type}{$key} = \%this_row;
            }

        }
        else {    # no key fields

            my $ref_to_save;
            # if there's only one field, and this isn't a parent row,
            if ( scalar( keys(%this_row) ) == 1
                and not( $is_a_parent{$row_type} ) )
            {
                # save the values only
                $ref_to_save = $this_row{ $field_names[1] };
            }
            else {
                # save the row
                $ref_to_save = \%this_row;
            }

            #$ref_to_save = \%this_row;

            # save thisrow to %data_of if no parent
            if ( $parent_row_type eq $NO_PARENT ) {
                push @{ $data_of{$row_type} }, $ref_to_save;

            }
            else {    # has a parent
                      # save to previous row's hash
                push @{ $previous_of_r{$parent_row_type}{$row_type} },
                  $ref_to_save;
            }
        } ## tidy end: else [ if ( $uses_key{$row_type...})]

        # save this row so that if it is the parent of something,
        # its child can be saved in the right place
        $previous_of_r{$row_type} = \%this_row;

    } ## tidy end: ROW: while (<>)
    continue {
        # resets line numbering for errors
        close ARGV if eof;
    }
    
    return;

} ## tidy end: sub read_files

sub init_templates {

    for my $row_type ( keys %field_names_of ) {

        $template_of{$row_type} = $EMPTY_STR;
        my @template_pieces;

      FIELD:
        for my $field_length ( @{ $field_lengths_of{$row_type} } ) {
            push @template_pieces, 'A' . $field_length;
        }
        # don't add the last piece of repeating fields --
        # we'll handle that separately
        if ( $has_repeating_final_field{$row_type} ) {
            my $final_piece = pop @template_pieces;
            $template_of{$row_type}
              = jointemplate(@template_pieces)
              . "x($final_piece"
              . q{x} x $DELIMITER_LENGTH . ')*';
        }
        else {
            $template_of{$row_type} = jointemplate(@template_pieces);
        }

    } ## tidy end: for my $row_type ( keys...)


   return;

} ## tidy end: sub init_templates

sub jointemplate {
    return join( "x" x $DELIMITER_LENGTH, @_ );
}

sub init_field_names {

    local $/ = $EMPTY_STR;    # paragraph mode

  ROW_TYPE:
    while (<DATA>) {
        my @entries = split;

        # get row type length and field type
        my ( $row_type_length, $row_type, $use_this, $parent )
          = splice( @entries, 0, 4 );

        # is this row type used, and if not, skip it
        $is_used{$row_type} = $use_this =~ /\A(?i)y/;
        next ROW_TYPE unless $is_used{$row_type};

        # put field type length and field type into hashes
        $field_names_of{$row_type}[0]     = $row_type;
        $field_positions_of{$row_type}[0] = 0;
        $field_lengths_of{$row_type}[0]   = $row_type_length;

        # is this a child?
        $parent_of{$row_type} = $parent;
        $is_a_parent{$parent} = 1;

        my $position = $row_type_length + $DELIMITER_LENGTH;

        my $count = 1;
      FIELDS:
        while (@entries) {
            # get items from entries
            my $field_length = shift @entries;
            my $field_name   = shift @entries;

            if ( $field_name =~ /!\z/ ) {
                $field_name =~ s/!\z//;
                push @{ $keys_of{$row_type} }, $field_name;
            }

            # put field type, length, and position into hashes
            $field_names_of{$row_type}[$count]     = $field_name;
            $field_positions_of{$row_type}[$count] = $position;
            $field_lengths_of{$row_type}[$count]   = $field_length;

            $count++;
            $position = $position + $field_length + $DELIMITER_LENGTH;

        }    # FIELDS

        # if final field is repeating, save that
        if ( $field_names_of{$row_type}[-1] =~ /\*\z/ ) {
            ;
            $field_names_of{$row_type}[-1] =~ s/\*\z//;    # remove * marker
            $has_repeating_final_field{$row_type} = 1;
        }

        # if row type has a key, save that too
        $uses_key{$row_type} = exists $keys_of{$row_type};

    }    # FIELD_TYPE

    return;
} ## tidy end: sub init_field_names

=head1 NAME

readavl - read AVL files in the Hastus AVL Standard Interface format.

=head1 DESCRIPTION

readavl reads the files transmitted in the Hastus AVL Standard Interface format,
as described in the Hastus 2006 documentation, and collects it in a structure
readable in perl.

=head1 KNOWN ISSUES

Generally ignores the delimiters and treats the data as fixed-width, but 
uses the delimiter to determine the record type.

As of Summer 2013, the RouteMainPlacePatternDirection field in the PPAT record
has apparently been changed to 10 characters instead of 6. (I assume this has
to do with a Hastus upgrade.) Using this program on old records will need to
have it changed back again.

=head1 AUTHOR

Aaron Priven

=cut

1;

__DATA__
 3 CAL
 n top
 8 StartDate 
 8 EndDate 
 8 SchedulingUnit 
 8 ScheduleSet

 3 DAT
 n CAL
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

 3 STP
 y top
 5 Identifier!
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

 3 PLC
 y top
 6 Identifier!
 40 Description
 6 ReferencePlace
 6 District
 8 Number
20 AlternateName
10 XCoordinate
10 YCoordinate

 4 PPAT
 y top
 5 Route!
10 Direction
 2 DirectionValue!
10 RouteMainPlacePatternDirection
 6 RouteMainPlacePatternPlace*

 3 DIS
 n top
 8 StartStop!
 8 EndStop!
 8 Distance

 3 SHA
 n DIS
10 XCoordinate
10 YCoordinate

 3 RTE
 y top
 5 Identifier!
 5 PublicIdentifier
10 ServiceType
 2 ServiceTypeValue
10 ServiceMode
 2 ServiceModeValue

 3 PAT
 y top
 5 Route!
 4 Identifier!
10 Direction
 2 DirectionValue
 8 VehicleDisplay
 1 IsInService
 8 Via
40 ViaDescription

 3 TPS
 y PAT
 5 StopIdentifier
 6 Place
 8 VehicleDisplay
 1 IsATimingPoint
 1 IsRoutingPoint

 3 VDC
 y top
 8 Identifier!
 8 AlternateCode
40 Message1
40 Message2
40 Message3
40 Message4

 3 VSC
 n top
 8 Name!
10 ScheduleType
 2 ScheduleTypeValue!
 2 Scenario!
 8 Booking!
 8 SchedulingUnit
40 Description

 3 BLK
 n VSC
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

 3 TIN
 n BLK
10 InternalNumber

 3 TRP
 y top
10 InternalNumber!
 8 Number
 7 OperatingDays
 5 RouteForStatistics
 4 Pattern
15 Type
 2 TypeValue
 1 IsSpecial
 1 IsPublic

 3 PTS
 y TRP
 8 PassingTime

 3 CSC
 n top
 8 Name!
10 ScheduleType
 2 ScheduleTypeValue!
 2 Scenario!
 8 Booking!
 8 SchedulingUnit
40 Description

 3 PCE
 n CSC
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

 3 ASG
 n top
 8 EffectiveStartWeek
 6 Division

 3 RAS
 n ASG
 8 RosterSetIdentifier!
 6 RosterIdentifier!
10 PositionIdentifier!
 4 SequenceInWeek!
 8 CurrentDate
10 DutyInternalNumber
 8 EmployeeIdentifier

 3 EMP
 n top
 8 Identifier!
20 Fullname
 8 DisplayIdentfier

 3 DWP
 n top
 3 DutyNumber!
 8 BlockNumber!
 8 EmployeeDisplayIdentifier
 6 StartPlace
 5 StartTime
 6 ReportPlace
 5 ReportTime
 6 EndPlace
 5 EndTIme
 6 ClearPlace
 5 ClearTime

