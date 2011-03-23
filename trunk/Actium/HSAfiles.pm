# Actium/HSAfiles.pm
# Routines for reading and processing Hastus Standard AVL files

# Subversion: $Id$

use strict;
use warnings;

package Actium::HSAfiles;

use 5.010;    # turns on features

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use Actium::Constants;
use Actium::Files qw/filename retrieve store/;
use Actium::Term;
use Actium::Util qw(jk);
use Carp;
use English '-no_match_vars';
use File::Glob qw(:glob);
use File::Spec;
use List::MoreUtils 0.22 (qw/any zip/);
use Text::Trim 1.02;

use Readonly;

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

#########################################
### ROWS, FIELD NAMES, AND LENGTHS
#########################################

my $FIELDS = <<'ENDNAMES'
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
# FIELDLENGTH FIELDNAME
# FIELDLENGTH FIELDNAME
# etc.

# Currently the FIELDLENGTHs are not used, because I cannot
# depend on them from signup to signup.

# FIELDNAME! - field is a key field
# FIELDNAME* - field is a final, repeating field
#   (contains more than one value)

#########################################
### PROCESS ROW DATA INTO HASHES
#########################################

# These all refer to a rowtype, except %rowtypes_of, which is of a filetype.

my ( %parent_of,              %children_of );
my ( %filetype_of,            %rowtypes_of );
my ( %fields_of,              %field_order_of );
my ( %fields_and_children_of, %fields_and_children_order_of );
my ( %key_fields_of,          %key_field_order_of );
my %has_repeating_final_field;

{                                                                # scoping

    local $INPUT_RECORD_SEPARATOR = $EMPTY_STR;    # paragraph mode

## nocritic (RequireCarping)
    open my $fields_h, '<', \$FIELDS
      or die "Can't open internal variable for reading: $OS_ERROR";
## usecritic

  ROW_TYPE:
    while (<$fields_h>) {
        my @entries = split;

        # get row type length and field type
        my ( $row_type, $file, $parent )
          = splice( @entries, 0, 3 );    ## no critic (ProhibitMagicNumbers)

        $filetype_of{$row_type} = $file;
        push @{ $rowtypes_of{$file} }, $row_type;

        # put field type length and field type into hashes
        #$fields_of{$row_type}[0] = $row_type;
        #$field_order_of{$row_type}{ROWTYPE} = 0;

        # is this a child?
        if ( $parent ne $NO_PARENT ) {
            $parent_of{$row_type} = $parent;
            push @{ $children_of{$parent} }, $row_type;
        }

        my $field_order = 0;

      FIELD:
        while (@entries) {

            # get items from entries
            my $field_length = shift @entries;    # ignored
            my $field        = shift @entries;

            # if it's a key field, put that in hashes
            if ( $field =~ /!\z/s ) {
                $field =~ s/!\z//s;
                push @{ $key_fields_of{$row_type} },      $field;
                push @{ $key_field_order_of{$row_type} }, $field_order;
            }

            # put field type and order into hashes
            $fields_of{$row_type}[$field_order] = $field;
            $field_order_of{$row_type}{$field} = $field_order;

            $field_order++;

        }    # FIELDS

        # if final field is repeating, save that
        if ( $fields_of{$row_type}[-1] =~ /\*\z/s ) {
            $fields_of{$row_type}[-1] =~ s/\*\z//s;    # remove * marker
            $has_repeating_final_field{$row_type} = 1;
        }
    }
    
    # now that we've loaded the entries, go through again and do
    # parents and children positions.
    # Couldn't do this earlier because the children weren't loaded yet
    
    foreach my $row_type (keys %filetype_of) {
        
        @{ $fields_and_children_of{$row_type} } = @{ $fields_of{$row_type} };
        %{ $fields_and_children_order_of{$row_type} } = 
           %{ $field_order_of{$row_type} };
           
        my $field_order = scalar @{$fields_of{$row_type}};

        foreach ( @{ $children_of{$row_type} } ) {
            push @{ $fields_and_children_of{$row_type} }, $_ . $KEY_SEPARATOR ;
            $fields_and_children_order_of{$row_type}{$_ . $KEY_SEPARATOR} 
               = $field_order++;
        }

    }    # ROW_TYPE

}    # scoping

#########################################
### PUBLIC METHODS
#########################################

sub new {
    my $class = shift;
    my $dir   = shift;
    my $self  = { $DIR_KEY => $dir };
    bless $self, $class;
    $self->_get_filespecs_and_mtimes();
    return $self;
}

sub iterator {
    my ( $self, $rowtype, $match ) = @_;
    my $filedata_r = $self->_read($rowtype);

    my @list;
    if ($match) {
        ## no critic (RequireDotMatchAnything)
        @list = sort grep ( {/$match/} keys %{$filedata_r} );
        ## use critic
    }
    else {
        @list = sort keys %{$filedata_r};
    }

    return sub {
        my $key = shift @list;
        return unless $key;
        my $row = $self->_rowhash( $rowtype, $filedata_r->{$key} );
        return wantarray ? ( $key, $row ) : $row;
    };
} ## #tidy# end sub iterator

sub fetch {
    my ( $self, $rowtype, $key ) = @_;
    $self->_read($rowtype);
    my $filedata_r = $self->_read($rowtype);

    if ( $filedata_r->{$key} ) {
        return $self->_rowhash( $filedata_r->{$key} );
    }

    return;

}

sub fieldnames {
    my $self = shift;
    my $rowtype = shift;
    return @{ $fields_of{$rowtype} };
}
    

#########################################
### PRIVATE METHODS
#########################################

sub _rowhash {

    # turns a row into a hash whose keys are fieldnames
    # and whose values are the values

    # unless there's only one field in the row, in which case,
    # it doesn't

    my $self    = shift;
    my $rowtype = shift;
    my $row_r   = shift;

    return $row_r if @{ $fields_and_children_of{$rowtype} } == 1;

    # doesn't add field names for rows of only one field.

    my %hash = zip( @{ $fields_and_children_of{$rowtype} }, @{$row_r} );

    foreach my $childtype ( @{ $children_of{$rowtype} } ) {
        my $childkey = $childtype . $KEY_SEPARATOR ;
        my @childrenhashes;
        foreach my $childrow ( @{$hash{$childkey}} ) {
           push @childrenhashes, $self->_rowhash( $childtype, $childrow );
        }
        $hash{$childkey} = \@childrenhashes;
    }    # recursive... neato

    return \%hash;
} ## #tidy# end sub _rowhash

### READ

sub _read {
    my $self    = shift;
    my $rowtype = shift;

    if ( not exists $filetype_of{$rowtype} ) {
        emit_error;
        croak "Tried to read nonexistent rowtype $rowtype";
    }

    my $filetype = $filetype_of{$rowtype};
    return if exists( $self->{$filetype} );    # already read

    if ( exists $parent_of{$rowtype} ) {
        my $parent = $parent_of{$rowtype};
        while ( exists $parent_of{$parent} ) {
            $parent = $parent_of{$parent};
        }
        emit_error;
        croak "Tried to read child rowtype $rowtype "
          . "(please access it through parent rowtype $parent)";
    }

    emit "Loading Hastus Standard AVL data ($rowtype from $filetype)";

    my ( $result, $filedata_r ) = $self->_read_cache($filetype);

    if ( !$result ) {

        # failed to load from cache
        $filedata_r = $self->_read_hsas($filetype);
        $self->_write_cache( $filetype, $filedata_r );
    }

    delete $filedata_r->{$MTIME_KEY};
    $self->{$filetype} = $filedata_r;
    emit_done;
    return $self->{$filetype};

} ## #tidy# end sub _read

sub _read_cache {
    my $self         = shift;
    my $filetype     = shift;
    my $storablefile = $self->_storablefile($filetype);

    emit "Looking for $filetype cache. Is it present?";

    if ( not -e $storablefile ) {
        emit_no;
        return 0;
    }

    emit_yes;

    emit "Loading cache of $filetype";
    my $filedata_r = retrieve($storablefile);
    emit_ok;

    emit "Checking to see if $filetype cache is up-to-date";

    my %cached_mtime_of = %{ $filedata_r->{$MTIME_KEY} };
    my %mtime_of        = $self->_mtime_of($filetype);

    if (join( $KEY_SEPARATOR, sort keys %cached_mtime_of ) ne
        join( $KEY_SEPARATOR, sort keys %mtime_of ) )
    {
        emit_no { -reason => 'Different files in directory from cache' };
        return 0;
    }

    if (any { our $_; $cached_mtime_of{$_} != $mtime_of{$_} }
        keys %mtime_of
      )
    {
        emit_no { -reason => 'Files modified since cache written' };
        return 0;
    }

    emit_yes;

    return 1, $filedata_r;

} ## #tidy# end sub _read_cache

sub _read_hsas {
    my ( $self, $filetype ) = @_;

    my @hsas = $self->_filespecs_of($filetype);
    my %hsadata;

    local $INPUT_RECORD_SEPARATOR = $CRLF;
    
    emit "Reading HSA files";
    
  FILE:
    foreach my $file (@hsas) {
        
        emit "Reading " . filename($file);
        
        my $size = -s $file;
        
        my $result = open my $fh, '<', $file;
        if ( not $result ) {
            emit_error;
            croak "Can't open $file for reading: $OS_ERROR";
        }
        
        my %template_of = $self->_build_templates( $fh, $filetype, $file );

        my %previous_row_of;
        my $previous_key = 0;
        
        my $count = 0;
        my $tenths = 0;

      ROW:
        while (<$fh>) {
            chomp;
            
            
        $count++;
        if ($count % 100) {
           my $newtenths = int( tell($fh) / $size * 10);
           if ($tenths != $newtenths) {
               $tenths = $newtenths;
               emit_over "${tenths}0%";
           }
        }
            
            my ( $rowtype, $_ ) = split( /$DELIMITER/sx, $_, 2 );
            unless ( $filetype_of{$rowtype} eq $filetype ) {
                carp
"Incorrect row type $rowtype in file $file, row $INPUT_LINE_NUMBER:\n$_\n";
                set_term_pos(0);
                next ROW;
            }

            my @fields = unpack( $template_of{$rowtype}, $_ );
            trim(@fields);

            if ( $has_repeating_final_field{$rowtype} ) {
                my @finals = splice( @fields, $#{ $fields_of{$rowtype} } );
                @finals = map { $_ ne $EMPTY_STR } @finals;
                push @fields, \@finals;
            }

            my $row;
            if ( @{ $fields_and_children_of{$rowtype} } == 1 ) {
                $row = $fields[0];
            }
            else {
                $row = \@fields;
            }

            $previous_row_of{$rowtype} = $row;

            my $parent = $parent_of{$rowtype};
            if ( $parent ) {
                my $order
                  = $fields_and_children_order_of{$parent}{ $rowtype . $KEY_SEPARATOR };
                push @{ $previous_row_of{$parent}[$order] }, $row;
                next ROW;
            }

            my $key;
            if ( $key_fields_of{$rowtype} ) {
                $key = jk(
                #$key = jk( $rowtype,
                    map { $fields[$_] } @{ $key_field_order_of{$rowtype} } );
            }
            else {
                $key = $previous_key++;
            }

            $hsadata{$key} = $row;

        }    # ROW

        if ( not close $fh ) {
            emit_error;
            croak "Can't close $file for reading: $OS_ERROR";
        }
        
        emit_ok;

    }    # FILE
    
    emit_done;

    return \%hsadata;

} ## #tidy# end sub _read_hsas

sub _build_templates {
    my ( $self, $fh, $filetype, $file ) = @_;

    my %template_of;

    # determine number of columns
    foreach my $rowtype ( @{ $rowtypes_of{$filetype} } ) {
        my $numfields
          = scalar @{ $fields_of{$rowtype} } + 1;    # add one for rowtype
        $numfields += $EXTRA_FIELDS_WHEN_REPEATING
          if $has_repeating_final_field{$rowtype};

        while ( not $template_of{$rowtype} ) {
            my $line = <$fh>;
            chomp $line;
            my @fields = split( /$DELIMITER/sx, $line );
            if ( @fields == $numfields ) {
                $template_of{$rowtype} = join( $DELIMITER_TEMPLATE_PAD,
                    map { 'A' . length } @fields[1..$#fields] );
            }

        }
        if ( not $template_of{$rowtype} ) {
            emit_error;
            croak
"Unable to determine fields of $rowtype (never found a line with the right number)";
        }

        if ( not seek $fh, 0, 0 ) {
            emit_error;
            croak "Couldn't return seek position to top of $file: $OS_ERROR";
        }

    } ## #tidy# end foreach my $rowtype ( @{ $rowtypes_of...})

    return %template_of;

} ## #tidy# end sub _build_templates

sub _write_cache {
    my $self       = shift;
    my $filetype   = shift;
    my $filedata_r = shift;
    my @filespecs  = $self->_filespecs_of($filetype);
    my $mtime_of_r = $self->_mtime_of($filetype);

    emit "Writing .$filetype cache";

    $filedata_r->{$MTIME_KEY} = $mtime_of_r;

    my $storablefile = $self->_storablefile($filetype);
    my $result = store( $filedata_r, $storablefile );

    emit_done;
    return;
} ## #tidy# end sub _write_cache

###  FILENAMES, FILESPECS, MTIMES, ETC.

sub _get_filespecs_and_mtimes {
    my $self = shift;
    my $dir  = $self->_dir();

    emit 'Assembling lists of filenames and modification times';

    my @filespecs = bsd_glob( $self->_filespec(q<*>), GLOB_NOCASE );

    if (File::Glob::GLOB_ERROR) {
        emit_error;
        croak
"Error reading list of filenames in Hastus Standard AVL directory $dir: $OS_ERROR";
    }

    if ( not scalar @filespecs ) {
        emit_error;
        croak "No files found in Hastus Standard AVL directory $dir";
    }

    foreach my $filetype ( keys(%rowtypes_of) ) {
        my %mtime_of;
        my @these = grep ( {/\.$filetype/sx} @filespecs );
        $self->{$FILESPEC_KEY}{$filetype} = \@these;

        foreach my $filespec (@these) {
            my @stat = stat($filespec);
            unless ( scalar @stat ) {
                emit_error;
                croak "Could not get file status for $filespec";
            }
            my $file = filename($filespec);
            $mtime_of{$file} = $stat[$STAT_MTIME];
        }
        $self->{$MTIME_KEY}{$filetype} = \%mtime_of;
    }

    emit_ok;

    return;
} ## #tidy# end sub _get_filespecs_and_mtimes

sub _filespecs_of {
    my $self     = shift;
    my $filetype = shift;
    return wantarray
      ? @{ $self->{$FILESPEC_KEY}{$filetype} }
      : $self->{$FILESPEC_KEY}{$filetype};
}

sub _mtime_of {
    my $self     = shift;
    my $filetype = shift;
    return wantarray
      ? %{ $self->{$MTIME_KEY}{$filetype} }
      : $self->{$MTIME_KEY}{$filetype};
}

sub _dir {
    my $self = shift;
    return $self->{$DIR_KEY};
}

sub _filespec {
    my $self     = shift;
    my $filename = shift;
    return File::Spec->catfile( $self->_dir(), $filename );
}

sub _storablefile {
    my $self     = shift;
    my $filetype = shift;
    return $self->_filespec("$filetype.storable");
}

1;

__END__

=head1 NAME

Actium::HSAfiles - routines to read and process Hastus Standard AVL files

=head1 VERSION

This documentation refers to Actium::HSAfiles version 0.001

=head1 SYNOPSIS

 # using raw filespecs
 use Actium::HSAfiles;
 my $hsa = Actium::HSAfiles->new ('/Actium/signups/f09/hsa');

 # using signup routines from Actium::Signup

 use Actium::Signup;
 use Actium::HSAfiles;
 $hsadir = Actium::Signup->new('hsa');
 my $hsa = Actium::HSAfiles->new ($hsadir->get_dir());

 # once object exists, use it

 my $row = $hsa->fetch('STP', '1002710');
 say $row->{'1002710'}{Description};
 # displays stop description of stop 1002710

 my $nextrow = $hsa->iterator('STP');
 while (my ($key, $thisrow) = $nextrow->() ) {
     say "Stop # $key: " , $thisrow->{Description};
 }
 # displays descriptions of every stop
 
 use Actium::Constants;
 my $nextmatchingrow = $hsa->iterator('PAT' , qr/^40$KEY_SEPARATOR/);
 while (my $thisrow = $nextmatchingrow->() ) {
     say $thisrow->{ViaDescription};
 }
 # displays via descriptions of every pattern for Line 40
 
=head1 DESCRIPTION

Actium::HSAfiles consists of routines to read files 
in the Hastus AVL Standard Interface format,
which is described in the Hastus 2006 documentation.  

In order to minimize time loading and processing the data,
the routines read the files only when the data is requested (although 
that data is stored for future accesses).  Also, the
data is parsed from the original Hastus Standard AVL files only once --
the first time the data is read, it stores a cache of the data on disk so
that the next time it need read only the cache. It updates the cache whenever 
the last modified dates of the Hastus Standard AVL files change or when 
the Hastus Standard AVL files are added or removed. 

=head1 METHODS

=over

=item B<< $obj = Actium::HSAfiles->new(filespec) >>

B<new()> is a class method which creates a new HSAfiles object. It has one parameter:
the file specification of the directory containing HSA files.

=item B<< $obj->fetch(rowtype , key) >>

This object method returns data from a row of the HSA file. rowtype must be one of the
parent rows; child rows are accessed through the parent row. Returns a false value
if the row with the specified key is not found.

=item B<< $obj->iterator(rowtype [, match]) >>

This object method returns a reference to an iterator subroutine. Each time the
iterator subroutine is invoked, it returns the next row from the HSA files, until 
it has run out of rows, after which it returns a false value.

In list context, the iterator returns the key and the full data for that row; 
in scalar context, it returns only the data, not the key.

For example:

 my $next = $hsa->iterator('STP');
 while (my $row = $next->() ) {
     say "Stop #" , $row->{'Identifier'} , 
        " is " , $row->{'Description'};
 }
 
This will display all the stop ID numbers followed by their descriptions.

You can choose to fetch only those rows whose keys match a regular expression by
supplying that regular expression to the iterator constructor. 

 my $next_line_40_pattern = $hsa->iterator('PAT' , qr/^40/);
 
=item B<< $obj->fieldnames(rowtype) >>

Returns the field names from the specified row type, in order.

=back

=head1 DATA STRUCTURE

=head2 KEYS USED IN FETCH AND ITERATOR MATCHES

The key fields are identified in the Hastus 2006 documentation 
(they are shown as shaded boxes).
Where more than one key field is given in the Hastus 2006 documentation, 
the key is returned as the value of each of the key fields, separated by the
key separator (see L<Actium::Constants/$KEY_SEPARATOR>). For example, a pattern whose
route is 75 and whose identifier is 1002 would have a key of 
"75\c]1002" (assuming $KEY_SEPARATOR remains "\c]").

=head2 ROWS RETURNED

Each row is returned as a hash using the field names as keys. 
(The names used are from the 'XML element' entry for each record in the Hastus 
AVL Standard Interface documentation.) 

So a PLC (places) row might be returned as 
{ Identifier => '105A', Description => '105TH AVE. & ACALANES DR.' , 
ReferencePlace => '', ...} and so forth. White space is removed from the beginning and 
ending of the values.

If a field can have multiple values (for example, the field RouteMainPlacePatternPlace
in PPAT rows) then the value is a reference to an array of the values.

Each row with a child row (for example, PAT rows, which have child TPS rows) have 
an additional entry in the hash for that type of child row.
The key is the name of the child row followed
by the key separator (see L<Actium::Constants/$KEY_SEPARATOR>).

For child rows with only one field (e.g, TIN has only InternalNumber, and PTS has only
PassingTime), the value is a reference to an array of values for that field.

For child rows with more than one field, the value is a reference to a hash of that
child row's field names and values.

So, for example:

 $plcrow = $hsa->fetch('PLC' , '14BD');
 say $plcrow->{Description}; # '14TH ST. & BROADWAY'
 
 $trprow = $hsa->fetch('TRP' , '2695504');
 say $trprow->{Route}; # 'G', meaning Line G
 say $trprow->{"PTS$KEY_SEPARATOR"}[0]; 
 # '0510p', the first passing time for line G
 
 $vscrow = $hsa->fetch
    ('VSC', join($KEY_SEPARATOR , qw/System 0 01 OCT10/ ) );
    
 say $vscrow->{Description};
 # "MVS for Oct 8/30/10"
 
 my $blockkey = join($KEY_SEPARATOR, qw/801001 12345 1051b/};
 say $vscrow->{"BLK$KEY_SEPARATOR"}{$blockkey}{StartPlace};
 # "D6", the start place for that block
 
 say $vscrow->{"BLK$KEY_SEPARATOR"}{$blockkey}{"TIN$KEY_SEPARATOR"}[0];
 # 2700642, the first internal trip number for that block
 
Of course, most of the time the keys won't be given as literals.

=head1 DIAGNOSTICS

=head2 FATAL ERRORS

=over

=item Can't open internal variable for reading

An input-output error occurred when reading the field names. This is an unlikely error
as the field names are stored in memory.

=item Tried to read nonexistent rowtype $rowtype

The user passed a rowtype to fetch() or iterator() that this module doesn't
know about. 

=item Tried to read child rowtype $rowtype (please access it through parent rowtype $parent)

The user passed a rowtype to fetch() or iterator() that is a child row. All rows
that are children of parent rows need to be accessed via that parent row.

=item "Can't open $file for reading";
=item "Can't close $file for reading";

An input/output error occurred opening or closing an HSA file.

=item "Unable to determine fields of $rowtype (never found a line with the right number)"

This routine searched through the whole file and never found a line with the right
number of fields for that row.

This requires a bit of explanation. 
HSA rows are specified in the HSA documentation as fixed-width records, with
a delimiter -- practically always a comma -- inserted between each pair of fields. 
The comma is not treated specially; it's just there to make the 
files easier to read. There is no escaping mechanism where the comma,
if found in real data, is somehow marked as not being a real delimiter.
A program that naively treats an HSA file as a typical comma-separated values file (CSV)
will yield incorrect results for each line where the data includes a comma.

Unfortunately, some people have written custom HSA export routines that replace a
standard field (such as the stop identifier) with another field (a shorter stop
identifier, intended for public use), with a different length. So a program that 
uses the field lengths to determine where each field is 
will break when provided with this custom HSA export.

What is constant, however, is that the number of fields is the same, and there
will always be a comma between two fields. There will always be I<at minimum> that
number of commas, and no fewer. There may, however, be more.

So what this program does is go through each HSA file and look for rows that have
the proper number of commas for the number of fields. If it has more commas than that,
then one of those commas is part of the data, but if it has the right number for
the number of fields, then we can use the positions of each comma to determine the
positions of the beginning and end of each field. 

It is, however, conceivable that no record will have the right number of commas --
either because every record has a comma in the data, or more likely, because the
file is corrupt. In that event, this program cannot determine where the field locations
are within this row, and the program will fail with this error.

=item  "Couldn't return seek position to top of $file";

After searching through the file for a row with the right number of fields 
for each rowtype, the program received an input/ouptut error when trying to move
the next-line pointer back to the top of the file.

=item "Error reading list of filenames in Hastus Standard AVL directory $dir"

An error occurred attempting to assemble the list of filenames (using "glob"). Probably
a directory name was given that was incorrect.
 
=item  "No files found in Hastus Standard AVL directory $dir";

No HSA files were found in the directory. Perhaps you forgot to populate it.

=item  "Could not get file status for $filespec";

An input/output error occurred trying to read the file status
(including modification time) for the specified file.

=back

=head2 WARNINGS

=over

=item Storable returned error retrieving $storablefile
In attempting to retrieve the stored data in the cache, 
the Storable routine returned an error.  This program will continue as though
the file were not present.

=item Storable returned error storing $storablefile

In attempting to save the stored data in the cache, 
the Storable routine returned an error.  This program will continue.

=item Different files in directory from cache
=item Files modified since cache written

The files in the hsa directory are different, or newer, than the ones used
to create the most recent cache. The cache will be rebuilt.

=item Incorrect row type $rowtype in file $file, row $INPUT_LINE_NUMBER

An unrecognized row type was found in this file. (It is probably not an HSA file.)
This row will be skipped.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.010

=item *

Actium::Constants

=item *

Actium::Term

=item *

List::MoreUtils, version 0.22

=item *

Text::Trim, version 1.02

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
