package Actium::Types 0.012;
# vimcolor: #222222

use Actium;

# Type::Tiny ### DEP ###
# Type::Tiny types for Actium

use Type::Library
  -base,
  -declare => qw( Folder File CrierStatus CrierImportance Time Dir OctiumDir);
use Type::Utils -all;
use Types::Standard -types;

### Folders and files

class_type Folder, { class => 'Actium::Storage::Folder' };
class_type File,   { class => 'Actium::Storage::File' };

coerce Folder, from Str, via { Actium::Storage::Folder->new($_) };
coerce File,   from Str, via { Actium::Storage::File->new($_) };

### Time

class_type Time, { class => 'Actium::Time' };
coerce Time, from Str, via { Actium::Time->from_str($_) };
# can't coerce from a number because '515' could be a time number
# or a string representing 5:15 am

### Direction

class_type Dir,       { class => 'Actium::Dir' };
class_type OctiumDir, { class => 'Octium::O::Dir' };
coerce Dir,       from OctiumDir, via { Actium::Dir->instance( $_->dircode ) };
coerce Dir,       from Str,       via { Actium::Dir->instance($_) };
coerce OctiumDir, from Str,       via { Octium::O::Dir->instance($_) };

### Crier fields

declare CrierStatus,     as Int, where { -7 <= $_ and $_ <= 7 };
declare CrierImportance, as Int, where { 0 <= $_  and $_ <= 7 };

__END__

## no critic (ProhibitMagicNumbers)

use MooseX::Types -declare => [
    qw <DayCode     SchoolDayCode   DayStr
      DaySpec             ActiumDays  ActiumTime
      DirCode             ActiumDir
      ArrayRefOfTimeNums  TimeNum     _ArrayRefOfStrs ArrayRefOrTimeNum
      Str4                Str8
      ActiumSkedStopTime  ArrayRefOfActiumSkedStopTime
      CrierBullet          ARCrierBullets
      CrierTrailer
      >
];

# MooseX::Types ### DEP ###
# MooseX::Types::Moose ### DEP ###

use MooseX::Types::Moose qw/Str HashRef Int Maybe Any ArrayRef/;

use Unicode::GCString;    ### DEP ###

##################
### SCHEDULE DAYS

subtype DayCode, as Str, where {/\A1?2?3?4?5?6?7?H?\z/}, message {
    qq<"$_" is not a valid day code\n>
      . qq<  (one or more of the characters 1-7 plus H, in order>;
};
# It uses question marks instead of [1-7H]+ because
# the numbers have to be in order, and not repeated

enum( SchoolDayCode, [ 'B', 'D', 'H' ] );

subtype DaySpec, as ArrayRef, where {
    $#{$_} == 1
      and is_DayCode( $_->[0] )
      and is_SchoolDayCode( $_->[1] );
};

subtype DayStr, as Str, where {/\A1?2?3?4?5?6?7?H?-[BDH]\z/x}, message {
    qq<"$_" is not a valid day string\n>
      . qq<  (one or more of the characters 1-7 plus H, in order\n>
      . qq<  followed by a hyphen and B, D, or H>;
};

coerce DaySpec, from DayCode, via { [ $_, 'B' ] },;

coerce DaySpec, from DayStr, via { [ split( /-/, $_, 2 ) ] };

subtype ActiumDays, as class_type('Actium::Days');

coerce ActiumDays,
  from DaySpec, via { Actium::Days->instance( $_->@* ) },
  from DayCode, via { Actium::Days->instance( to_DaySpec($_)->@* ) },
  from DayStr,  via { Actium::Days->instance( to_DaySpec($_)->@* ) },
  ;

#########################
### SCHEDULE STOP TIMES

subtype ActiumSkedStopTime, as class_type('Actium::O::Sked::Stop::Time');

subtype ArrayRefOfActiumSkedStopTime, as ArrayRef [ActiumSkedStopTime];

#########################
### SCHEDULE DIRECTIONS

enum( DirCode, \@DIRCODES );

subtype ActiumDir, as class_type('Actium::Dir');

coerce( ActiumDir, from DirCode, via { Actium::Dir->instance($_) }, );

######################
## NOTIFY

subtype CrierBullet, as Str;

subtype CrierTrailer, as Str,
  #where { (Unicode::GCString::->new($_)->columns) == 1 },
  #message {"The trailer you provided ($_) is not exactly one column wide"},
  ;

subtype ARCrierBullets, as ArrayRef [CrierBullet];
coerce ARCrierBullets, from CrierBullet, via { [$_] };

######################
## SCHEDULE TIMES

subtype ActiumTime, as class_type('Actium::Time');
coerce ActiumTime, from Str, via { Actium::Time->from_str($_) };

const my $NOON_YESTERDAY => -$MINS_IN_12HRS;
const my $NOON_TOMORROW  => 3 * $MINS_IN_12HRS;

subtype TimeNum, as Maybe [Int], where {
    not defined($_) or ( $_ >= $NOON_YESTERDAY ) && ( $_ <= $NOON_TOMORROW )
},
  message {"Times must be on or after noon yesterday and before noon tomorrow"};

subtype ArrayRefOrTimeNum, as TimeNum | ArrayRef [TimeNum];

coerce TimeNum, from Str, via { Actium::Time->from_str($_)->timenum };

subtype ArrayRefOfTimeNums, as ArrayRef [ Maybe [TimeNum] ];

subtype _ArrayRefOfStrs, as ArrayRef [ Maybe [Str] ];
# _ArrayRefOfStrs only exists to make ArrayRefOfTimeNums
# and other coercions work.

# I think this is actually unnecessary, as coercing *from* a Moose built-in
# type may be OK, unlike coercing *to* a built-in, which is a no-no.
# But I'm not sure, and this is working, so...

coerce ArrayRefOfTimeNums, from _ArrayRefOfStrs, via {
    my @array = map { defined($_) ? to_TimeNum($_) : undef } @{$_};
    return ( \@array );
};

############################
### TIMEPOINT ABBREVIATIONS

subtype Str8, as Str, where { length == 8 },
  message {qq<The entry "$_" is not an eight-character-long string>};

subtype Str4, as Str, where { length == 4 },
  message {qq<The entry "$_" is not an four-character-long string>};

##########################
### CLASS AND ROLE TYPES

role_type 'Skedlike', { role => 'Actium::O::Skedlike' };

#########################
## FOLDERS / FILES

class_type 'Actium::Storage::Folder';

coerce 'Actium::Storage::Folder', from Str,
  via { require Actium::Storage::Folder; Actium::Storage::Folder::->new($_) };

coerce 'Actium::Storage::Folder', from ArrayRef [Str],
  via { require Actium::Storage::Folder; Actium::Storage::Folder::->new(@$_) };

class_type 'Actium::Storage::File';

coerce 'Actium::Storage::File', from Str,
  via { require Actium::Storage::File; Actium::Storage::File::->new($_) };

coerce 'Actium::Storage::File', from ArrayRef [Str],
  via { require Actium::Storage::File; Actium::Storage::File::->new(@$_) };

# note that the coercions neither create the folder,
# nor check to see that it already exists

1;
__END__

=head1 NAME

Actium::Types - Moose types for the Actium system

=head1 VERSION

This documentation refers to Actium::Types version 0.001

=head1 SYNOPSIS

 # in a Moose class
 package MyClass;
 use Moose;
 use Actium::Types qw(DayCode);
 
 has 'days' =>
    is => 'rw' ,
    isa => DayCode ,
 );
 # now the days attribute of MyClass is constrained to be a 
 # DayCode value
 
=head1 DESCRIPTION

This module is a library of types for use with Moose. See
L<MooseX::Types> and L<Moose::Manual::Types>.

=head1 TYPES

=head2 SCHEDULE DAYS

=over

=item B<DayCode>

This string represents scheduled days in a newer way, based on the way
Hastus stores them: 1 = Monday, 2 = Tuesday ... 7 = Sunday, and H =
holidays. They must be in order (e.g., "76" is invalid).

=item B<SchoolDayCode>

A character representing whether the scheduled days run during school
days ("D"), school holidays ("H"), or both ("B").

=item B<DayString>

=item B<DaySpec>

...


=back

=head2 SCHEDULE DIRECTIONS

=over

=item B<DirCode>

An enumeration of the elements of @Actium::DIRCODES.  See
L<Actium/Actium>. It can be coerced into  ActiumODir.

=item B<ActiumODir>

A type representing the Actium::Dir class.

=back

=head2 TIME NUMBERS AND STRINGS

=over

=item B<TimeNum>

A time number, suitable for use by L<Actium::Time>. The number of
minutes after midnight (or before, if negative), or undef. Coerces
strings into TimeNums using Actium::Time.

=item B<ArrayRefOrTimeNum>

A "union type" -- either an array reference, or a TimeNum.

=item B<ArrayRefOfTimeNums>

An array reference, which must refer to an array consisting solely of
TimeNums.

=back

=head2 TIMEPOINT ABBREVIATIONS

=over

=item B<Str4> and B<Str8>

A string of exactly four characters or eight characters. These are used
in  specifying timepoint abbreviations.

=back

=head1 DEPENDENCIES

=over

=item Actium

=item Moose

=item MooseX::Types

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011-2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

