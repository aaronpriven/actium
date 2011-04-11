# Actium/Files/HastusASI/Definition.pm

# Definition of Hastus ASI tables and file types

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::HastusASI::Definition 0.001;

use MooseX::Singleton;

use English ('-no_match_vars');

use Actium::Files::HastusASI::Filetype;
use Actium::Files::SQLite::Table;

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
  
=begin comment

 TABLE FILE PARENT
 COLUMNLENGTH COLUMNNAME
 COLUMNLENGTH COLUMNNAME
 etc.

 Currently the COLUMNLENGTHs are not used, because I cannot
 depend on them from signup to signup.

 COLUMNNAME! - column is a key column
 COLUMNNAME* - column is a final, repeating column
   (contains more than one value)


=end comment

=cut

sub _build_table_of_r {
 
=begin comment
 
The way this works is that it goes through each table in the above
DEFINITION string and builds little constructor-specifications for each
of the various attributes: id, filetype, parent , columns_r,
column_length_of_r, has_repeating_final_column, and key_components_r

As it goes through the subsquent tables, it goes back to the previous
ones when it finds a child table, and adds that ID to the children_r
attribute of the parent table

At the end, it creates a bunch of new little objects from the
constructor specs, and returns them to be found in the _table_of_r
attribute.

=end comment

=cut

    my $self = shift;

    my %table_spec_of;

    local $INPUT_RECORD_SEPARATOR = q{};    # paragraph mode

    open my $definition_h, '<', \$DEFINITION
      or die "Can't open internal variable for reading: $OS_ERROR";

  TABLE:
    while (<$definition_h>) {
        my @entries = split; # each word

        my %spec;

        # get row type length and column type
        my ( $table_id, $filetype, $parent )
          = splice( @entries, 0, 3 );    ## no critic (ProhibitMagicNumbers)

        $spec{filetype} = $filetype;
        $spec{id}       = $table_id;

        # is this a child?
        if ( $parent ne 'noparent' ) {
            $spec{parent} = $parent;
            push @{ $table_spec_of{$parent}{children_r} }, $table_id;
        }

      COLUMN:
        while (@entries) {

            # get items from entries
            my $column_length = shift @entries;
            my $column        = shift @entries;

            # if it's a key column, save that
            if ( $column =~ /!\z/s ) {
                $column =~ s/!\z//s;
                push @{ $spec{key_components_r} }, $column;
            }

            # save column type and length
            push @{ $spec{columns_r} }, $column;
            $spec{column_length_of_r}{$column} = $column_length;

        }

        # if final column is repeating, save that
        if ( $spec{columns_r}[-1] =~ /\*\z/s ) {
            $spec{columns_r}[-1] =~ s/\*\z//s;    # remove * marker
            $spec{has_repeating_final_column} = 1;
        }

        $table_spec_of{$table_id} = \%spec;

    } ## tidy end: while (<$definition_h>)

    close $definition_h
      or die "Can't close internal variable for reading: $OS_ERROR";

    my %tableobjs
      = map { $_ => Actium::Files::SQLite::Table->new( $table_spec_of{$_} ) }
      keys %table_spec_of;

    return \%tableobjs;

} ## tidy end: sub _build_table_of_r

sub _build_filetype_of_r {
    my $self      = shift;
    my %tableobjs = %{ $self->_table_of_r };
    my %tables_of;

    while ( my ( $table, $tableobj ) = each %tableobjs ) {
        my $filetype = $tableobj->filetype;
        push @{ $tables_of{$filetype} }, $table;
    }

    my %filetypeobj_of;
    foreach my $filetype ( keys %tables_of ) {
        $filetypeobj_of{$filetype} = Actium::Files::HastusASI::Filetype->new(
            id       => $filetype,
            tables_r => $tables_of{$filetype},
        );
    }

    return \%filetypeobj_of;

} ## tidy end: sub _build_filetype_of_r


################################
### ATTRIBUTES
################################

has '_table_of_r' => (
    init_arg => undef,
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Actium::Files::SQLite::Table]',
    builder  => '_build_table_of_r',
    lazy     => 1,
    handles  => {
        tables   => 'keys',
        _table_of => 'get',
        is_a_table => 'exists',
    },
);

has '_filetype_of_r' => (
    init_arg => undef,
    is       => 'ro',
    traits   => ['Hash'],
    isa      => 'HashRef[Actium::Files::HastusASI::Filetype]',
    builder  => '_build_filetype_of_r',
    lazy     => 1,
    handles  => {
        filetypes   => 'keys',
        _filetype_of => 'get',
    },

);

######################################
### TABLE AND FILETYPE METHODS
######################################

# I am not sure how to delegate methods to an object which is not itself
# an attribute, but which is referred to by an attribute.
# so, I've written these all out.

sub key_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->key;
}

sub columns_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->columns;
}

sub tables_of_filetype {
    my $self     = shift;
    my $filetype = shift;
    return $self->_filetype_of($filetype)->tables;
}

sub filetype_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->filetype;
}

sub parent_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->parent;
}

sub has_repeating_final_column {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->has_repeating_final_column;
}

sub has_composite_key {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->has_composite_key;
}

sub create_query_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->sql_createcmd;
}

sub insert_query_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->sql_insertcmd;
}

sub index_query_of_table {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->sql_idxcmd;
}

sub key_components_idxs {
    my $self  = shift;
    my $table = shift;
    return $self->_table_of($table)->key_components_idxs;
}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__

=head1 NAME

Actium::Files::HastusASI::Definition - singleton object/class for Hastus AVL 
Standard Interface 

=head1 NOTE

This documentation is intended for maintainers of the Actium system, not
users of it. Run "perldoc Actium" for general information on the Actium system.

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Files::HastusASI::Definition;
 my $definition = Actium::Files::HastusASI::Definition->instance;
 
 my @tables = $defintion->tables;
 
=head1 DESCRIPTION

Actium::Files::HastusASI::Definition is a singleton class containing data
about the definition of Hastus ASI files. It builds the data from an embedded
string and creates the objects when necessary.

It is private to the L<Actium::Files::HastusASI|Actium::Files::HastusASI> 
module. 

=head1 METHODS

=over

=item B<instance>

Use the B<instance> class method to obtain the object: 
C<<Actium::Files::HastusASI::Definition->instance>>. (This is unlike
standard Moose classes and most other perl classes, which create
a constructor called "new".)

=item B<tables>

Returns a list of the identifiers for each table. See L<I<id> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/id>.

=item B<is_a_table(I<table>)>

Returns true if the specified table is a valid table (that is, is a member
of the above list).

=item B<filetypes>

Returns a list of the identifiers for each filetype. 
See L<I<id> in
Actium::Files::HastusASI::Filetype|Actium::Files::HastusASI::Filetype/id>.

=item B<key_of_table (I<table_id>)>

Returns the key column of the specified table.
See L<I<key> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/key>.

=item B<columns_of_table (I<table_id>)>

Returns a list of the columns of the specified table.
See L<I<columns> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/columns>.

=item B<tables_of_filetype (I<filetype_id>)>

Returns a list of the tables of the specified filetype.
See L<I<tables> in
Actium::Files::HastusASI::Filetype|Actium::Files::HastusASI::Filetype/tables>.

=item B<filetype_of_table (I<table_id>)>

Returns the filetype of the specified table.
See L<I<filetype> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/filetype>.

=item B<parent_of_table (I<table_id>)>

Returns the parent of the specified table, if any.
See L<I<parent> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/parent>.

=item B<has_repeating_final_column (I<table_id>)>

Returns a boolean value representing whether the final column has repeated
values (instead of just one value). 
See L<I<has_repeating_final_column> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/has_repeating_final_column>.

=item B<has_composite_key (I<table_id>)>

Returns whether the key column is a composite of two or more other columns.
See L<I<has_composite_key> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/has_composite_key>.

=item B<create_query_of_table (I<table_id>)>

Returns the SQLite command creating this table.
See L<I<sql_createcmd> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/sql_createcmd>.

=item B<insert_query_of_table (I<table_id>)>

Returns the SQLite command inserting a row of this table into the database.
See L<I<sql_insertcmd> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/sql_insertcmd>.

=item B<index_query_of_table (I<table_id>)>

Returns the SQLite command creating the index of the specified table based on the key
column.
See L<I<sql_idxcmd> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/sql_idxcmd>.

=item B<key_components_idxs (I<table_id>)>

Returns the column indexes (what order they are in the columns) of 
the components that make up the key of the specified table.
See L<I<key_components_idxs> in
Actium::Files::SQLite::Table|Actium::Files::SQLite::Table/key_components_idxs>.

=back

=head1 DIAGNOSTICS

=over

=item * Can't open internal variable for reading
=item * Can't close internal variable for reading

Perl was unable to open, or close, the variable that holds the definition 
entries (which it opens as a file). An unlikely error.

=back
      
=head1 DEPENDENCIES

=over

=item perl 5.012

=item MooseX::Singleton

=item Moose

=item Actium::Files::HastusASI::Filetype

=item Actium::Files::SQLite::Table

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
