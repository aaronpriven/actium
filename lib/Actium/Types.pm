# Actium/Types.pm
# Moose types for Actium

# legacy status 4

use strict;
use warnings;

package Actium::Types 0.010;

use 5.016;    # turns on features

## no critic (ProhibitMagicNumbers)

use MooseX::Types -declare => [
    qw <TransitInfoDays   DayCode     SchoolDayCode
      DaySpec             ActiumDays
      HastusDirCode       DirCode     ActiumDir
      ArrayRefOfTimeNums  TimeNum     _ArrayRefOfStrs ArrayRefOrTimeNum TimeNum
      Str4                Str8
      ActiumSkedStopTime  ArrayRefOfActiumSkedStopTime
      ActiumFolderLike
      CrierBullet          ARCrierBullets
      CrierTrailer
      >
];

# MooseX::Types ### DEP ###
# MooseX::Types::Moose ### DEP ###

use MooseX::Types::Moose qw/Str HashRef Int Maybe Any ArrayRef/;

use Actium::Time;
use Actium::Constants;
use Unicode::GCString; ### DEP ###

##################
### SCHEDULE DAYS

subtype DayCode, as Str, where {/\A1?2?3?4?5?6?7?H?\z/}, message {
    qq<"$_" is not a valid day code\n>
      . qq<  (one or more of the characters 1-7 plus H, in order>;
};
# It uses question marks instead of [1-7H]+ because
# the numbers have to be in order, and not repeated

enum( TransitInfoDays, [ values %TRANSITINFO_DAYS_OF ] );

coerce DayCode, from TransitInfoDays, via { $DAYS_FROM_TRANSITINFO{$_} };

enum( SchoolDayCode, [ 'B', 'D', 'H' ] );

subtype DaySpec, as ArrayRef, where {
    $#{$_} == 1
      and is_DayCode( $_->[0] )
      and is_SchoolDayCode( $_->[1] );
};

coerce DaySpec, from DayCode, via { [ $_, 'B' ] },
  from TransitInfoDays, via { [ to_DayCode($_), 'B' ] };

subtype ActiumDays, as class_type('Actium::O::Days');

coerce ActiumDays,
  from DaySpec,         via { Actium::O::Days->instance($_) },
  from DayCode,         via { Actium::O::Days->instance( to_DaySpec($_) ) },
  from TransitInfoDays, via { Actium::O::Days->instance( to_DaySpec($_) ) },
  ;

#########################
### SCHEDULE STOP TIMES

subtype ActiumSkedStopTime, as class_type('Actium::O::Sked::Stop::Time');

subtype ArrayRefOfActiumSkedStopTime, as ArrayRef [ActiumSkedStopTime];

#########################
### SCHEDULE DIRECTIONS

enum( DirCode, \@DIRCODES );

subtype HastusDirCode, as Int, where { $_ >= 0 and $_ <= $#DIRCODES };

coerce DirCode, from HastusDirCode, via { $DIRCODES[ $HASTUS_DIRS[$_] ] };

subtype ActiumDir, as class_type('Actium::O::Dir');

coerce( ActiumDir,
    from HastusDirCode,
    via               { Actium::O::Dir->new( to_DirCode($_) ) },
    from DirCode, via { Actium::O::Dir->new($_) },
);

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

subtype TimeNum, as Maybe [Int];

subtype ArrayRefOrTimeNum, as TimeNum | ArrayRef [TimeNum];

coerce TimeNum, from Str, via { Actium::Time::timenum($_) };

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
## FOLDER

duck_type ActiumFolderLike, [qw[ path ]];    # maybe make a folderlike role...

coerce ActiumFolderLike, from Str, via( \&_make_actium_o_folder ),
  from ArrayRef [Str], via \&_make_actium_o_folder;

sub _make_actium_o_folder {
    require Actium::O::Folder;
    Actium::O::Folder::->new($_);
}

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

This module is a library of types for use with Moose. See L<MooseX::Types> and
L<Moose::Manual::Types>.

=head1 TYPES

=head2 SCHEDULE DAYS

=over

=item B<TransitInfoDays>

An enumeration of the values of %Actium::Constants::TRANSITINFO_DAYS_OF. 
See L<Actium::Constants/Actium::Constants>. Can be coerced into a DayCode.

=item B<DayCode>

This string represents scheduled days in a newer way, based on the way Hastus
stores them: 1 = Monday, 2 = Tuesday ... 7 = Sunday, and H = holidays.
They must be in order (e.g., "76" is invalid).

=item B<SchoolDayCode>

A character representing whether the scheduled days run during school days
("D"), school holidays ("H"), or both ("B").

=back

=head2 SCHEDULE DIRECTIONS

=over

=item B<HastusDirCode>

A number from 0 to 13, representing the various direction codes used in the 
Hastus AVL Standard Interface. It can be coerced into DirCode or ActiumODir.

=item B<DirCode>

An enumeration of the elements of @Actium::Constants::DIRCODES. 
See L<Actium::Constants/Actium::Constants>. It can be coerced into 
ActiumODir.

=item B<ActiumODir>

A type representing the Actium::O::Dir class.

=back

=head2 TIME NUMBERS AND STRINGS

=over

=item B<TimeNum>

A time number, suitable for use by L<Actium::Time>. The number of minutes after
midnight (or before, if negative), or undef.
Coerces strings into TimeNums using Actium::Time::timenum().

=item B<ArrayRefOrTimeNum>

A "union type" -- either an array reference, or a TimeNum.

=item B<ArrayRefOfTimeNums>

An array reference, which must refer to an array consisting solely of TimeNums.

=back

=head2 TIMEPOINT ABBREVIATIONS

=over

=item B<Str4> and B<Str8>

A string of exactly four characters or eight characters. These are used in 
specifying timepoint abbreviations.

=back

=head1 DEPENDENCIES

=over

=item Actium::Constants

=item Actium::Time

=item Moose

=item MooseX::Types

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
