# Actium/Types.pm
# Moose types for Actium

# Subversion: $Id$

use strict;
use warnings;

package Actium::Types;

use 5.010;    # turns on features

our $VERSION = '0.001';
$VERSION = eval $VERSION;

## no critic (ProhibitMagicNumbers)

use MooseX::Types -declare => [
    qw <Schedule_Day 
      ArrayRefOfTimeNums _ArrayRefOfStrs ArrayRefOrTimeNum
      TimeNum Str4 Str8> # StrOrArrayRef
];

use MooseX::Types::Moose qw/Str HashRef Int Maybe Any ArrayRef/;

use Actium::Time;
use Actium::Constants;

enum( Schedule_Day, (@SCHEDULE_DAYS) );

subtype Str8, as Str, where { length == 8 },
  message {qq<The entry "$_" is not an eight-character-long string>};

subtype Str4, as Str, where { length == 8 },
  message {qq<The entry "$_" is not an four-character-long string>};
  
#subtype StrOrArrayRef, as Str|ArrayRef;

## Time numbers
subtype TimeNum, as Maybe[Int];

subtype ArrayRefOrTimeNum, as TimeNum|ArrayRef[TimeNum];

coerce TimeNum, from Str, via { Actium::Time::timenum($_) };

subtype ArrayRefOfTimeNums, as ArrayRef[Maybe[TimeNum]];

subtype _ArrayRefOfStrs, as ArrayRef[Str];
# _ArrayRefOfStrs only exists to make ArrayRefOfTimeNums coercion work

coerce ArrayRefOfTimeNums, from _ArrayRefOfStrs, via {
    my @array = map { to_TimeNum ($_) } @{$_} ;
    return (\@array);
};

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
 use Actium::Types qw(Schedule_Day);
 
 has 'days' =>
    is => 'rw' ,
    isa => Schedule_Day ,
 );
 # now the days attribute of MyClass is constrained to be a 
 # Schedule_Day value
 
=head1 DESCRIPTION

This module is a library of types for use with Moose. See L<MooseX::Types> and
L<Moose::Manual::Types>.

=head1 TYPES

=over

=item B<Schedule_Day>

An enumeration of @Actium::Constants::SCHEDULE_DAYS. See L<Actium::Constants>.

=item B<Str4> and B<Str8>

A string of exactly four characters or eight characters. These are used in specifying
timepoint abbreviations.

=item B<TimeNum>

A time number, suitable for use by L<Actium::Time>. The number of minutes after
midnight (or before, if negative), or undef.
Coerces strings into TimeNums using Actium::Time::timenum().

=item B<ArrayRefOrTimeNum>

A "union type" -- either an array reference, or a TimeNum.

=item B<ArrayRefOfTimeNums>

An array reference, which must refer to an array consisting solely of TimeNums.

=back

=head1 DEPENDENCIES

=over

=item *
Actium::Constants

=item *

Moose

=item *
MooseX::Types

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2009 

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
