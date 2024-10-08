package Octium::Types 0.012;

# Moose types for Actium
use Actium;
use Octium;
use Moose::Util::TypeConstraints;

const my $MINS_IN_12HRS => ( 12 * 60 );

## no critic (ProhibitMagicNumbers)

use MooseX::Types -declare => [
    qw <DayCode     SchoolDayCode   DayStr
      DaySpec             ActiumDays  ActiumTime
      ArrayRefOfTimeNums  TimeNum     _ArrayRefOfStrs ArrayRefOrTimeNum
      ActiumSkedStopTime  ArrayRefOfActiumSkedStopTime
      ActiumFolderLike
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

subtype ActiumDays, as class_type('Octium::Days');

coerce ActiumDays,
  from DaySpec, via { Octium::Days->instance( $_->@* ) },
  from DayCode, via { Octium::Days->instance( to_DaySpec($_)->@* ) },
  from DayStr,  via { Octium::Days->instance( to_DaySpec($_)->@* ) },
  ;

#########################
### SCHEDULE STOP TIMES

subtype ActiumSkedStopTime, as class_type('Octium::Sked::Stop::Time');

subtype ArrayRefOfActiumSkedStopTime, as ArrayRef [ActiumSkedStopTime];

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

##########################
### CLASS AND ROLE TYPES

role_type 'Skedlike', { role => 'Octium::Skedlike' };

#########################
## FOLDER

duck_type ActiumFolderLike, [qw[ path ]];    # maybe make a folderlike role...

coerce ActiumFolderLike, from Str, via( \&_make_actium_o_folder ),
  from ArrayRef [Str], via \&_make_actium_o_folder;

sub _make_actium_o_folder {
    require Octium::Folder;
    Octium::Folder::->new($_);
}

1;
__END__

=head1 NAME

Octium::Types - Moose types for the Actium system

=head1 VERSION

This documentation refers to Octium::Types version 0.001

=head1 SYNOPSIS

 # in a Moose class
 package MyClass;
 use Moose;
 use Octium::Types qw(DayCode);
 
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

