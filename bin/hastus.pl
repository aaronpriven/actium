use warnings;
use strict;
use Carp;
use Fatal qw (open close);

# set some constants
use Readonly;
Readonly my $EMPTY_STR => q{};
Readonly my $CRLF => qq{\cM\cJ};
Readonly my $KEY_SEPARATOR => qq{\c]}; # control-]
# FileMaker uses this separator for repeating fields, so I do too
Readonly my $DELIMITER_LENGTH => 1;

my %fields_of;
my %template_of;
my %keys_of;
my %data_of;

init_field_names();
init_templates();

my $directory = '/Users/apriven/Desktop/actfall07b';

read_files(qw(NDE  STP));

exit;

read_files(qw(PLC  PLC));
read_files(qw(RTE  RTE));

read_files_parent (qw(PAT PAT TPS));
read_files_parent (qw(TRP TRP PTS));

sub read_files {
   my ($extension, $line_type) = @_;

	foreach my $filename (glob "$directory/*.$extension") {
	   open my $fh , "<" , $filename;
	   while (<$fh>) {
	      my @fields = unpack ($template_of{$line_type}, $_);
	      
	      my %value_of;
	      
	      for (0..$#fields) {
	         $value_of{$fields_of{$line_type}[$_]{NAME}} = $fields[$_];
	      }
	      
	      push @{$data_of{$line_type}}, \%value_of;
	      
	   }
	}
}

      
sub read_files_parent {

   my ($extension, $parent_line_type, $child_line_type) = @_;
   
   my $previous_parent = $EMPTY_STR;

	foreach my $filename (glob "$directory/*.$extension") {
	   open my $fh , "<" , $filename;
	   while (<$fh>) {
	   
	      my $this_line_type eq substr($_,0,3);
	      
	      if ($this_line_type eq $parent_line_type) {
	   
		      my @fields = unpack ($template_of{$line_type}, $_);
		      
		      my %value_of;
		      
		      for (0..$#fields) {
		         $value_of{$fields_of{$line_type}[$_]{NAME}} = $fields[$_];
		      }
		      
		      $previous_parent = \%value_of;
		      push @{$data_of{$line_type}}, $previous_parent;
		      
		   }
	      
	   }
	}



}




sub init_templates {

   FIELD_TYPE:
   for my $line_type (keys %fields_of) {
   
       $template_of{$line_type} = $EMPTY_STR;
       FIELD:
       my @template_pieces;
       for my $field_r ( @{$fields_of{$line_type}} ) {
          push @template_pieces, 'A' . $field_r->{LEN};
       }
       if ($line_type eq 'PPAT') {
          pop @template_pieces;
       }
       # don't add the last piece of PPAT -- we'll handle that separately
       # since there are 50 of those
       
       $template_of{$line_type} = join("x" , @template_pieces);

   }      

}


sub init_field_names {

	local $/ = $EMPTY_STR; # paragraph mode

	FIELD_TYPE:
	while (<DATA>) {
	   my @entries = split;
	   
	   # get field type length and field type
	   my $line_type_length = shift @entries;
	   my $line_type = shift @entries;
	   
	   # put field type length and field type into %fields_of
	   $fields_of{$line_type}[0] = {
	        NAME => $line_type ,
	        POS  => 0 ,
	        LEN  => $line_type_length,
	        };

	   my $position = $line_type_length + $DELIMITER_LENGTH;

      my $count = 1;
	   FIELDS:
	   while (@entries) {

	      # get items from entries
	      my $field_length = shift @entries;
	      my $field_name = shift @entries;
	      
	      # put field type, length, and position into %fields_of
	      $fields_of{$line_type}[$count] = {
	         NAME => $field_name,
	         POS  => $position ,
	         LEN  => $field_length,
	         };
	       
	       $count++;
	       $position = $position + $field_length + $DELIMITER_LENGTH;
	      
	   } # FIELDS
	   
	} # FIELD_TYPE
	
	%keys_of = (
	   STP  => [ qw(Identifier) ],
	   PLC  => [ qw(Identifier) ],
	   PPAT => [ qw(Route DirectionValue) ],
	   RTE  => [ qw(Identifier) ],
	   PAT  => [ qw(Route Identifier) ],
	   TRP  => [ qw(InternalNumber) ],
	);
	   

   return;
}

# length, then name
__DATA__
 3 STP 
 8 Identifier
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
 6 Identifier
 40 Description
 6 ReferencePlace
 6 District
 8 Number
20 AlternateName
10 XCoordinate
10 YCoordinate

 4 PPAT
 5 Route
10 Direction
 2 DirectionValue
 6 RouteMainPlacePatternDirection
 6 RouteMainPlacePatternPlace

 3 RTE
 5 Identifier
 5 PublicIdentifier
10 ServiceType
 2 ServiceTypeValue
10 ServiceMode
 2 ServiceModeValue

 3 PAT
 5 Route
 4 Identifier
10 Direction
 2 DirectionValue
 8 VehicleDisplay
 1 IsInService
 8 Via
40 ViaDescription

 3 TPS
 8 StopIdentifier
 6 Place
 8 VehicleDisplay
 1 IsATimingPoint
 1 IsRoutingPoint

 3 TRP
10 InternalNumber
 8 Number
 7 OperatingDays
 5 RouteForStatistics
 4 Pattern
15 Type
 2 TypeValue
 1 IsSpecial
 1 IsPublic

 3 PTS
 8 PassingTime
