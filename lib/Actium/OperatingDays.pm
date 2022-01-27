package Actium::OperatingDays 0.019;
# Object representing the scheduled days (of a trip, or set of trips)

use Actium ('class');
use Actium::OperatingDays::Types( -types );
use Types::Standard(qw/Enum/);

# 1, 2, 3, 4 5, 6, 7 represent Monday through Sunday

# Holidaypolicy -
# 1-7 represent an agency policy that holidays have
# that schedule (never heard of one where it wasn't
# Saturday or Sunday, but whatever)
# 0 - indeterminate holidays
#     (agency doesn't have a rule about that)
# default is 7
# Stored here so we can mix and match different agencies'
# policies in the same output

##### CONSTRUCTION #####

const my $CHECK_FOR_INSTANCE => 'use_instance_not_new';

around BUILDARGS ($orig, $class : @args) {
    if ( $args[0] ne $CHECK_FOR_INSTANCE ) {
        croak "Attempt to create $class object "
          . 'using new() instead of instance()';
    }
    shift @args;
    $class->$orig(@args);
}

my %OF_SHORTCODE = ( DA => '1234567', WD => '12345', WE => '67', );

method instance ($class: $daycode! , :$holidaypolicy //= '7') {

    state %obj_cache;

    state $old_sd_carped;
    if ( $daycode =~ /\-[BDH]\z/ ) {
        if ( not $old_sd_carped ) {
            carp "Stripping old-style school code from day code";
            $old_sd_carped = 1;
        }
        $daycode =~ s/-[BDH]\z//;
    }

    state $seven_h_carped;
    if ( $daycode =~ /7H/ ) {
        if ( not $seven_h_carped ) {
            carp "Stripping old-style Sunday-and-holiday H from day code";
            $seven_h_carped = 1;
        }
        $daycode =~ s/7H/7/;
    }

    $daycode = $OF_SHORTCODE{$daycode} if exists $OF_SHORTCODE{$daycode};

    my $cachekey = "$daycode:$holidaypolicy";
    return $obj_cache{$cachekey} //= $class->new(
        $CHECK_FOR_INSTANCE,
        daycode       => $daycode,
        holidaypolicy => $holidaypolicy,
    );
}

has 'daycode' => (
    is       => 'ro',
    isa      => DayCode,
    required => 1,
    #    coerce   => 1,
);

has 'holidaypolicy' => (
    is       => 'ro',
    isa      => HolidayPolicy,
    required => 1,
);

has _show_holiday => (
    is      => 'ro',
    isa     => Enum [qw/H X 0/],
    lazy    => 1,
    builder => '_build_show_holiday',
);

method _build_show_holiday {
    my $holpol = $self->holidaypolicy;
    return '0' if $holpol eq '0' or $self->daycode eq '1234567';
    return 'H' if $self->daycode =~ /$holpol/;
    return 'X';
}

method count {
    my $daycode = $self->daycode;
    # my $count   = $daycode =~ tr/1-7//;
    my $count = length($daycode);
    return $count;
}

method as_string {
    my $holidaypolicy = $self->holidaypolicy;
    $holidaypolicy = $holidaypolicy eq '7' ? '' : ":" . $holidaypolicy;
    return $self->daycode . $holidaypolicy;
}

method unbundle ($class: Str $bundle) {
    my ( $daycode, $holidaypolicy ) = split /:/, $bundle;
    return $class->instance( $daycode, holidaypolicy => $holidaypolicy );
}

{
    no warnings('once');
    *sortable = \&daycode;
    *bundle   = \&as_string;
}

method _data_printer {
    my $class = Actium::blessed($self);
    return "$class=" . $self->as_string;
}

#### COMPARISON, UNION, INTERSECTION

method is_equal_to (Actium::OperatingDays $obj) {
    return $self == $obj;
    # relies on flyweight-ness
}

func _verify_union_or_intersection ($invocant, @objs) {

    # invoke either as class method or as object method
    my $class;
    if ( Actium::blessed($invocant) ) {
        $class = Actium::blessed($invocant);
        unshift @objs, $invocant;
    }
    else {
        $class = $invocant;
    }

    my @holpols = Actium::uniq sort map { $_->holidaypolicy } @objs;
    croak 'Attempt to create union of '
      . $class
      . ' objects with different holiday policies'
      if @holpols != 1;

    return $class, $holpols[0], @objs;
}

method union ($invocant: Actium::OperatingDays @passed_objs) {

    my ( $class, $holidaypolicy, @objs )
      = _verify_union_or_intersection( $invocant, @passed_objs );

    my $return_daycode = '';

    foreach my $obj (@objs) {

        my $daycode = $obj->daycode;
        next if $daycode eq $return_daycode;

        $return_daycode = join(
            $EMPTY,
            (   Actium::uniq(
                    ( sort ( split //, $return_daycode . $daycode ) )
                )
            )
        );

    }

    return $class->instance(
        daycode       => $return_daycode,
        holidaypolicy => $holidaypolicy
    );

}

method intersection ($invocant: Actium::OperatingDays @passed_objs) {

    my ( $class, $holidaypolicy, @objs )
      = _verify_union_or_intersection( $invocant, @passed_objs );

    my $isect_object   = shift @objs;
    my $return_daycode = $isect_object->daycode;

    foreach my $obj (@objs) {
        my $daycode = $obj->daycode;
        next if $daycode eq $return_daycode;

        my @days       = split //, $daycode;
        my @isect_days = split //, $return_daycode;

        my $lc = List::Compare->new(
            {   lists       => [ \@days, \@isect_days ],
                accelerated => 1,
            }
        );

        my @intersection = $lc->get_intersection;
        return unless @intersection;

        $return_daycode = join( '', @intersection );

    }

    return $class->instance(
        daycode       => $return_daycode,
        holidaypolicy => $holidaypolicy
    );

}

method is_a_superset_of ( $obj) {

    my $seldays = $self->daycode;
    my $objdays = $obj->daycode;

    return 1 if index( $seldays, $objdays ) ne -1;
    # quick test for majority of cases where original days are found in
    # order, but doesn't work where e.g. is '12345' a superset of '135'

    my @seldays = split( //, $seldays );
    my @objdays = split( //, $objdays );
    my $lc      = List::Compare->new(
        {   lists       => [ \@seldays, \@objdays ],
            unsorted    => 1,
            accelerated => 1,
        }
    );

    return $lc->is_RsubsetL;
}

#### PRESENTATION FORMS

const my @FORMS => qw/shortcode full specdayletter/;

for my $form (@FORMS) {
    has "as_$form" => (
        is       => 'ro',
        init_arg => 'undef',
        builder  => "_build_as_$form",
        lazy     => 1,
    );
}

method _build_as_shortcode {

    my $daycode = $self->daycode;

    return
        $daycode eq '1234567' ? 'DA'
      : $daycode eq '12345'   ? 'WD'
      : $daycode eq '67'      ? 'WE'
      :                         $daycode;
}

const my @NAMES =>
  qw(ZeroDay Mondays Tuesdays Wednesdays Thursdays Fridays Saturdays Sundays);

method _build_as_full {
    my $daycode = $self->daycode;
    return 'Every day' if $daycode eq '1234567';

    require Set::IntSpan;    ### DEP ###

    my $set   = Set::IntSpan->new( [ split //, $daycode ] );
    my @spans = $set->spans;
    my @texts;
    foreach my $span (@spans) {
        my ( $low, $high ) = $span->@*;
        if ( $low == $high ) {
            push @texts, $NAMES[$low];
        }
        elsif ( $high - $low > 2 ) {    # has 4 days or more,
            push @texts, $NAMES[$low] . ' through ' . $NAMES[$high];
        }
        else {
            push @texts, @NAMES[ $low .. $high ];
        }

    }

    my $holiday = $self->_show_holiday;

    if ( $holiday eq 'H' ) {
        push @texts, 'holidays';
    }

    my $result = Actium::joinseries( items => \@texts );

    if ( $holiday eq 'X' ) {
        if ( @texts == 1 and $texts[0] !~ /through/ ) {
            $result .= ' except holidays';
        }
        else {
            $result .= ', except holidays';
        }
    }

    return $result;

}

const my %SPECDAYLETTER_OF => (
    qw(
      1 M
      2 T
      3 W
      4 Th
      5 F
      6 S
      7 Su
      )
);

method _build_as_specdayletter {

    my $daycode = $self->daycode;

    my $result
      = $daycode eq '1234'    ? 'XF'
      : $daycode eq '1235'    ? 'XTh'
      : $daycode eq '1245'    ? 'XW'
      : $daycode eq '1345'    ? 'XT'
      : $daycode eq '2345'    ? 'XM'
      : $daycode eq '12345'   ? 'WD'
      : $daycode eq '1234567' ? 'DA'
      :   join( '', map { $SPECDAYLETTER_OF{$_} } split( //, $daycode ) );

    $result .= 'Hol' if $self->_show_holiday eq 'H';

    return $result;

}

method specday_and_specdayletter ($tripdays: $skeddays) {

    my $tripdaycode = $tripdays->daycode;
    my $skeddaycode = $skeddays->daycode;
    return if $tripdaycode eq $skeddaycode;

    my $isect = $tripdays->intersection($skeddays);
    return unless $isect;

    return $isect->as_specdayletter, $isect->as_full . ' only';

}

Actium::immut();

1;

__END__

=head1 NAME

Actium::OperatingDays - Object for holding scheduled days

=head1 VERSION

This documentation refers to version 0.019

=head1 SYNOPSIS

 use Actium::OperatingDays;

 my $days = Actium::OperatingDays->instance ('12345');

 say $days->as_full; # "Monday through Friday"
 say $days->as_shortcode; # "WD"

=head1 DESCRIPTION

This class is used for objects storing scheduled day information.  Trips, or
timetables, are assigned to particular scheduled days. Almost all the time this
is either usually weekdays, Saturdays, or Sundays, and there's often a policy
that says holidays run either Saturday or Sunday schedules.  However, there are
cases where schedules are combined (Saturday and Sunday running the same
schedules), and others where there are exceptions, where trips run only a few
weekdays (e.g., Mondays, Wednesdays, and Fridays).

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These
objects are immutable.

=head1 CLASS METHODS

=over

=item B<< Actium::OperatingDays->instance(I<daycode> [, holidaypolicy => I<holidaypolicy>) ]>>

The object is constructed using "Actium::OperatingDays->instance".

The ->instance method accepts a day specification as a string,
containing any or all of the digits 1 through 7, in order. If a
1 is present, it operates on Mondays; if 2, it operates on Tuesdays;
and so on through 7 for Sundays.

For backward compatibility, it will accept, but strip off, trailing school day
codes ("-B", "-D" , "-H") or a letter H after the number 7 (indicating the old
way of showing the holidays). It will issue a warning the first time it sees
these.

There are three short codes it will accept going forward:

   DA  is short for  1234667
   WD  is short for  12345
   WE  is short for  67

These are for convenience only; any other days should be specified with the
full list of days.

The constructor also accepts an optional holiday policy argument, which must
be, a single digit from 0 through 7.  A 0 indicates that there is no holiday
policy and no mention should be made of holidays. If it is 1 through 7, it
indicates that holidays should be mentioned along with that day's schedule
(e.g., "Thursdays and holidays") -- 1 for Monday, 2 for Tuesday, etc.). If not
given, it uses 7, for Sunday.

=item B<< Actium::OperatingDays->new() >>

B<< Do not use this method. >>

This method is used internally by Actium::OperatingDays to create a new object
and insert it into the cache used by instance(). There should never be
a reason to create more than one method with the same arguments.

=item B<< Actium::OperatingDays->unbundle (I<string>) >>

This is an alternative constructor. It uses a single string, rather
than the separate daycode and schooldaycode, to construct an object and
return it.

The only way to guarantee a valid string is by using the I<as_string> object
method (or I<bundle>, which is an alias). The format of the string is internal
and not guaranteed to remain the same across versions of Actium::OperatingDays.
The purpose of this is to allow a single string to contain day information
without requiring it to have all the object overhead.

=back

=head1 CLASS OR OBJECT METHODS

=over

=item B<< Actium::OperatingDays->union(I<days> , ... >>)

=item B<< $obj->union (I<days> , ... >>)

Another constructor. It takes one or more Actium::OperatingDays objects and
returns a new object representing the union of those objects. For example, if
passed an object representing Saturday and an object representing Sunday,  will
return an object representing both Saturday and Sunday.

If holiday policies for the different objects are not identical, it will throw an exception.

=item B<< Actium::OperatingDays->intersection(I<days> , ... >>)

=item B<< $obj->intersection (I<days> , ... >>)

Another constructor. It takes one or more Actium::OperatingDays objects and
returns a new object representing the intersection of those objects. For
example, if passed an object representing Monday through Friday and another
representing Friday, Saturday, and Sunday, will return an object representing
Friday.

If the objects have no days in common, will return nothing.

If holiday policies for the different objects are not identical, it will throw an exception.

=back

=head1 OBJECT METHODS

=over

=item B<< $obj->daycode >>

Returns the day specification: a string with one or more of the
characters 1 through 7, indicating operation on Monday through Sunday.

=item B<< $obj->count >>

Returns the number of days of the week this object represents (in other words,
if it's five days a week, it would be 5; three days a week, would be 3; etc.).

=item B<< $obj->holidaypolicy >>

Returns one character: the digit 0, indicating that there is no holiday policy,
or 1 through 7, indicating that the schedule for that day is operated on
holidays.

=item B<< $obj->as_sortable >>

Currently an alias for C<daycode>, but guaranteed to return a version that can
be sorted using perl's cmp operator to be in order.

=item B<< $obj->as_string >>
=item B<< $obj->bundle >>

Returns a version of the day code and holiday policy that can be used to
create a new object using B<unbundle>.

=item B<< $obj->is_equal_to($other_obj) >>

Returns true if the passed object is the same as the invoked object. The object
must be completely identical (the same instance).

=item B<< $obj->is_a_superset_of($other_obj) >>

Returns true if the passed object is a superset of the invoked object (in other
words, if the passed object contains all the days of the invoked object).

=item B<< $obj->as_full >>

This returns a string containing English text describing the days.

The general form is "Days, Days and Days,"  but a set of four or more days in a
row are given as "Days through Days", and if all days are shown, will return
"Every day."

May be followed by "except holidays" or "and holidays," as appropriate.

=item B<< $obj->as_shortcode >>

This returns the day code, except that the following day codes are changed to
their abbreviations:

   1234667  will return  DA
   12345    will return  WD
   67       will return  WE

=item B<< $obj->as_specdayletter >>

Returns a short version of the days suitable for inclusion on a schedule.
Normally it is a combination of short day abbreviations ( M, T, W, Th, F, S,
Su), but there are a number of exceptions for sets of weekdays.  It will
include 'Hol' if holidays should be shown.

=item B<< $trip_days_obj->specday_and_specdayletter($schedule_days_object) >>

This method checks an Actium::OperatingDays object representing an individual
trip against an Actium::OperatingDays object representing a whole schedule.

If there is no intersection between the two day objects, or if they are the
same, nothing is returned.

Otherwise, it returns two things. The first is the as_specdayletter value, and
the as_full value with "only" tacked on at the end. This is the letter used for
notes in a timetable, and the description that should be used afterwards.

=back

=head1 DEPENDENCIES

=over

=item *

Moose

=item *

Actium

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it
under  the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

