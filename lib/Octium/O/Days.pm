package Octium::O::Days 0.012;
# Object representing the scheduled days (of a trip, or set of trips)

use Actium ('class');
use Octium;

use MooseX::Storage;    ### DEP ###
with Storage( traits => ['OnlyWhenBuilt'] );
with 'MooseX::Role::Flyweight';
# MooseX::Role::Flyweight ### DEP ###

use Octium::Types qw<DayCode SchoolDayCode>;
use List::Compare;      ### DEP ###

###################################
#### ENGLISH NAMES FOR DAYS CONSTANTS
###################################

const my @DAYLETTERS => qw(1 2 3 4 5 6 7 H W E D X);

# 1 = Monday, 2 = Tuesday, ... 7 = Sunday
# H = holidays, W = Weekdays, E = Weekends, D = Daily,
# X = every day except holidays

const my @SEVENDAYNAMES =>
  qw(Monday Tuesday Wednesday Thursday Friday Saturday Sunday);
const my @SEVENDAYPLURALS => ( map {"${_}s"} @SEVENDAYNAMES );
const my @SEVENDAYABBREVS => map { substr( $_, 0, 3 ) } @SEVENDAYNAMES;

###################################
#### ATTRIBUTES AND CONSTRUCTION
###################################

around BUILDARGS ($daycode, $schooldaycode) {
    return $self->$next( daycode => $daycode, schooldaycode => $schooldaycode );
}

has 'daycode' => (
    is          => 'ro',
    isa         => DayCode,
    required    => 1,
    initializer => '_initialize_daycode',
);

# New day codes have a character for each set of days that are used.
# 1 - 7 : Monday through Sunday (like in Hastus), and H - Holidays

sub _initialize_daycode {
    my $self    = shift;
    my $daycode = shift;
    my $set     = shift;

    $daycode =~ s/\D//g;
    # eliminate anything that's not a digit

    # TODO - add option to make it Saturdays-and-holidays
    #    instead of Sundays-and-holidays, or treat holidays as a separate
    #    schedule

    $daycode =~ s/7H?/7H/;    # make sure Sundays always includes holidays

    $set->($daycode);
}

has 'schooldaycode' => (
    is      => 'ro',
    isa     => SchoolDayCode,    # [BDH]
    default => 'B',
);
# D = school days only, H = school holidays only, B = both

sub instance_from_string {
    my $class  = shift;
    my $string = shift;
    my ( $daycode, $schooldaycode ) = split( /-/, $string );
    return $class->instance( $daycode, $schooldaycode );
}

has 'as_string' => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_as_string',
    lazy     => 1,
);

sub _build_as_string {
    my $self          = shift;
    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    return $self->daycode unless $schooldaycode;
    return $self->daycode . q{-} . $self->schooldaycode;
}

sub _data_printer {
    my $self  = shift;
    my $class = Octium::blessed($self);
    return "$class=" . $self->as_string;
}

sub as_sortable {
    my $self = shift;
    return $self->as_string;
}
# as_string not guaranteed to remain sortable in the future,
# so we put this stub in so that we can make a sortable version

has 'as_shortcode' => (
    is        => 'ro',
    init_arg  => 'undef',
    builder   => '_build_as_shortcode',
    lazy      => 1,
    predicate => '_has_shortcode',
);

sub _build_as_shortcode {
    my $self          = shift;
    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    my $shortcode = $daycode;

    for ($daycode) {
        if ( $_ eq '1234567H' ) {
            $shortcode = 'DA';
            next;
        }
        if ( $_ eq '12345' ) {
            $shortcode = 'WD';
            next;
        }
        if ( $_ eq '67H' ) {
            $shortcode = 'WE';
            next;
        }
    }

    if ( $shortcode eq 'WD' and $schooldaycode eq 'D' ) {
        $shortcode = 'SD';
    }
    elsif ( $schooldaycode ne 'B' ) {
        $shortcode .= "-$schooldaycode";
    }

    return $shortcode;

}    ## tidy end: sub _build_as_shortcode

sub _is_SD {
    my $self = shift;
    return 1 if ( $self->daycode eq '12345' and $self->schooldaycode eq 'D' );
    return;
}

sub _is_SH {
    my $self = shift;
    return 1 if ( $self->daycode eq '12345' and $self->schooldaycode eq 'H' );
    return;
}

const my @ADJECTIVES => ( @SEVENDAYNAMES, qw(Holiday Weekday Weekend Daily),
    "Daily except holidays" );
const my %ADJECTIVE_OF => Actium::mesh( @DAYLETTERS, @ADJECTIVES );
const my %ADJECTIVE_SCHOOL_OF => (
    B => $EMPTY,
    D => ' (except school holidays)',
    H => ' (except school days)',
);

sub as_adjectives {

    my $self = shift;

    my $as_string = $self->as_string;

    state $cache_r;
    return $cache_r->{$as_string} if $cache_r->{$as_string};

    my $daycode = $self->daycode;
    $daycode =~ s/1234567H/D/;    # every day
    $daycode =~ s/1234567/X/;     # every day except holidays
    $daycode =~ s/12345/W/;       # weekdays
    $daycode =~ s/67/E/;          # weekends

    my $schooldaycode = $self->schooldaycode;

    my @as_adjectives = map { $ADJECTIVE_OF{$_} } split( //, $daycode );

    my $results
      = Actium::joinseries( items => \@as_adjectives )
      . $ADJECTIVE_SCHOOL_OF{$schooldaycode};

    return $cache_r->{$as_string} = $results;

}    ## tidy end: sub as_adjectives

const my @PLURALS => (
    @SEVENDAYPLURALS, 'holidays', 'Monday through Friday',
    'Weekends', 'Every day', "Every day except holidays"
);

const my %PLURAL_OF => Actium::mesh( @DAYLETTERS, @PLURALS );
const my %PLURAL_SCHOOL_OF => (
    B => $EMPTY,
    D => ' (School days only)',
    H => ' (School holidays only)',
);

# TODO: all these methods with caches should be turned into attributes
# with lazy builders

sub as_plurals {

    my $self      = shift;
    my $as_string = $self->as_string;

    state $cache_r;
    return $cache_r->{$as_string} if $cache_r->{$as_string};

    my $daycode    = $self->daycode;
    my $seriescode = $daycode;
    $seriescode =~ s/1234567H/D/;    # every day
    $seriescode =~ s/1234567/X/;     # every day except holidays
    $seriescode =~ s/12345/W/;       # weekdays
        # $seriescode =~ s/67/E/;  # weekends intentionally omitted

    my $schooldaycode = $self->schooldaycode;

    my @as_plurals = map { $PLURAL_OF{$_} } split( //, $seriescode );
    my $results = Actium::joinseries( items => @as_plurals );

    if ( $PLURAL_SCHOOL_OF{$schooldaycode} ) {
        $results .= $PLURAL_SCHOOL_OF{$schooldaycode};
    }
    else {
        $results .= ' except holidays' unless $daycode =~ /H/;
    }

    return $cache_r->{$as_string} = ucfirst($results);

}    ## tidy end: sub as_plurals
const my @ABBREVS =>
  ( @SEVENDAYABBREVS, qw(Hol Weekday Weekend), 'Daily', "Daily except Hol" );

const my %ABBREV_OF => Actium::mesh( @DAYLETTERS, @ABBREVS );
const my %ABBREV_SCHOOL_OF => (
    B => $EMPTY,
    D => ' (Sch days)',
    H => ' (Sch hols)',
);

sub as_abbrevs {

    my $self      = shift;
    my $as_string = $self->as_string;

    state $cache_r;
    return $cache_r->{$as_string} if $cache_r->{$as_string};

    my $daycode = $self->daycode;
    $daycode =~ s/1234567H/D/;    # every day
    $daycode =~ s/1234567/X/;     # every day except holidays
    $daycode =~ s/12345/W/;       # weekdays
        # $daycode =~ s/67/E/;        # weekends intentionally omitted

    my $schooldaycode = $self->schooldaycode;

    my @as_abbrevs = map { $ABBREV_OF{$_} } split( //, $daycode );

    if ( scalar @as_abbrevs > 1 ) {
        $as_abbrevs[-1] = "& $as_abbrevs[-1]";
    }
    my $results
      = join( $SPACE, @as_abbrevs ) . $ABBREV_SCHOOL_OF{$schooldaycode};

    return $cache_r->{$as_string} = $results;

}    ## tidy end: sub as_abbrevs

for my $attr (qw/specday specdayletter/) {

    has "as_$attr" => (
        is        => 'ro',
        isa       => 'Str',
        lazy      => 1,
        builder   => "_build_as_$attr",
        predicate => "_has_$attr",
    );

}

sub _build_as_specday {
    my $self = shift;

    my $specday = $EMPTY;

    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    if ( $schooldaycode eq 'D' ) {
        $specday = 'School day ';
    }
    elsif ( $schooldaycode eq 'H' ) {
        $specday = 'School holiday ';
    }

    my @as_plurals = map { $PLURAL_OF{$_} } split( //, $daycode );

    last_cry()->text("$daycode gives blank as_plurals in specday")
      if not @as_plurals;

    $specday .= Actium::joinseries( items => @as_plurals ) . ' only';

    return $specday;
}    ## tidy end: sub _build_as_specday

const my %SPECDAYLETTER_OF => (
    qw(
      1 M
      2 T
      3 W
      4 Th
      5 F
      6 S
      7 Su
      H Hol
      )
);

sub _build_as_specdayletter {
    my $self = shift;

    my $schspecdayletter;

    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    if ( $schooldaycode eq 'D' ) {
        $schspecdayletter = 'SD';
    }
    elsif ( $schooldaycode eq 'H' ) {
        $schspecdayletter = 'SH';
    }

    my $specdayletter;

    if ( $daycode eq '1234' ) {
        $specdayletter = 'XF';
    }
    elsif ( $daycode eq '1235' ) {
        $specdayletter = 'XTh';
    }
    elsif ( $daycode eq '1245' ) {
        $specdayletter = 'XW';
    }
    elsif ( $daycode eq '1345' ) {
        $specdayletter = 'XT';
    }
    elsif ( $daycode eq '2345' ) {
        $specdayletter = 'XM';
    }
    else {
        my @as_specdayletters
          = map { $SPECDAYLETTER_OF{$_} } split( //, $daycode );
        $specdayletter = Actium::joinempty(@as_specdayletters);
    }

    if ($schspecdayletter) {
        $specdayletter .= "-$schspecdayletter";
    }
    return $specdayletter;

}    ## tidy end: sub _build_as_specdayletter

sub specday_and_specdayletter {

    my $tripdays = shift;
    my $skeddays = shift;

    my $tripdaycode = $tripdays->daycode;
    my $skeddaycode = $skeddays->daycode;
    my $tripsch     = $tripdays->schooldaycode;
    my $skedsch     = $skeddays->schooldaycode;

    if ( $tripdaycode eq $skeddaycode ) {
        # if the only difference is in the schools
        return
          unless $skedsch eq 'B' and ( $tripsch eq 'D' or $tripsch eq 'H' );
        # either no difference or invalid intersection, otherwise
        return ( SD => 'School days only' ) if $tripsch eq 'D';
        return ( SH => 'School holidays only' );
    }

    my $isect = $tripdays->intersection($skeddays);
    return unless $isect;

    # if the sched days school code isn't 'B', then it must
    # be the same as the trip day code (otherwise no intersection)
    if ( $skedsch ne 'B' ) {
        my $class = Octium::blessed($tripdays);
        $isect = $class->new( $isect->daycode, 'B' );
    }

    return $isect->as_specdayletter, $isect->as_specday;

}    ## tidy end: sub specday_and_specdayletter

{
    no warnings 'redefine';
    # Otherwise it conflicts with Moose::Util::TypeConstraints::union()

    sub union {
        # take multiple day objects and return the union of them
        # e.g., take one representing Saturday and one representing
        # Sunday and turn it into one representing both Saturday and Sunday

        my ( $class, @objs );

        if ( Octium::blessed( $_[0] ) ) {
            @objs  = @_;
            $class = Octium::blessed( $objs[0] );
        }
        else {
            $class = shift;
            @objs  = @_;
        }

        my $union_obj           = shift @objs;
        my $union_daycode       = $union_obj->daycode;
        my $union_schooldaycode = $union_obj->schooldaycode;

        foreach my $obj (@objs) {

            my $daycode       = $obj->daycode;
            my $schooldaycode = $obj->schooldaycode;

            next
              if $daycode eq $union_daycode
              and $schooldaycode eq $union_schooldaycode;

            if ( $schooldaycode ne $union_schooldaycode ) {
                $union_schooldaycode = 'B';
            }

            if ( $daycode ne $union_daycode ) {

                $union_daycode = join(
                    $EMPTY,
                    (   Octium::uniq(
                            ( sort ( split //, $union_daycode . $daycode ) )
                        )
                    )
                );

            }

            $union_obj
              = $class->instance( $union_daycode, $union_schooldaycode );

        }    ## tidy end: foreach my $obj (@objs)

        return $union_obj;

    }    ## tidy end: sub union

}

sub intersection {

    my $invocant = shift;
    my @objs     = @_;

    my $class;
    if ( Octium::blessed($invocant) ) {
        unshift @objs, $invocant;
        $class = Octium::blessed($invocant);
    }

    my $isect_obj           = shift @objs;
    my $isect_daycode       = $isect_obj->daycode;
    my $isect_schooldaycode = $isect_obj->schooldaycode;

    foreach my $obj (@objs) {

        my $daycode       = $obj->daycode;
        my $schooldaycode = $obj->schooldaycode;

        next
          if $daycode eq $isect_daycode
          and $schooldaycode eq $isect_schooldaycode;
        # they're identical

        if ( $schooldaycode ne $isect_schooldaycode ) {
            my @schooldays = sort ( $schooldaycode, $isect_schooldaycode );
            my $schoolday_combo = join( $EMPTY, @schooldays );
            if ( $schoolday_combo eq 'DH' ) {
                return;
            }
            elsif ( $schoolday_combo eq 'BD' ) {
                $isect_schooldaycode = 'D';
            }
            else {
                $isect_schooldaycode = 'H';
            }
        }

        if ( $daycode ne $isect_daycode ) {

            my @days       = split //, $daycode;
            my @isect_days = split //, $isect_daycode;

            my $lc = List::Compare->new(
                {   lists       => [ \@days, \@isect_days ],
                    accelerated => 1,
                }
            );

            my @intersection = $lc->get_intersection;
            return unless @intersection;

            $isect_daycode = join( $EMPTY, @intersection );

        }

        $isect_obj = $class->instance( $isect_daycode, $isect_schooldaycode );

    }    ## tidy end: foreach my $obj (@objs)

    return $isect_obj;

}    ## tidy end: sub intersection

sub is_a_superset_of {
    my $self = shift;
    my $obj  = shift;

    my $selfsch = $self->schooldaycode;
    my $objsch  = $obj->schooldaycode;

    return 0 unless $selfsch eq 'B' or $selfsch eq $objsch;

    my $seldays = $self->daycode;
    my $objdays = $obj->daycode;

    return 1 if index( $seldays, $objdays ) ne -1;

    my @seldays = split( //, $seldays );
    my @objdays = split( //, $objdays );
    my $lc      = List::Compare->new(
        {   lists       => [ \@seldays, \@objdays ],
            unsorted    => 1,
            accelerated => 1,
        }
    );

    return $lc->is_RsubsetL;
}    ## tidy end: sub is_a_superset_of

sub is_equal_to {

    my $self = shift;
    my $obj  = shift;

    return 1 if $self == $obj;
    # relies on flyweight-ness

    return 0;

}

const my %TRANSITINFO_DAYS_OF => (
    qw(
      1234567H DA
      123457H  WU
      123456   WA
      12345    WD
      1        MY
      2        TY
      3        WY
      4        TH
      5        FY
      6        SA
      56       FS
      7H       SU
      67H      WE
      24       TT
      25       TF
      35       WF
      123      MX
      135      MZ
      1245     XW
      1235     XH
      1234     XF
      45       HF
      )
);

sub as_transitinfo {
    my $self    = shift;
    my $daycode = $self->daycode;
    if ( exists $TRANSITINFO_DAYS_OF{$daycode} ) {
        return $TRANSITINFO_DAYS_OF{$daycode};
    }
    return $daycode;
}

Actium::immut();

1;

__END__

=head1 NAME

Octium::O::Days - Object for holding scheduled days

=head1 VERSION

This documentation refers to version 0.010

=head1 SYNOPSIS

 use Octium::O::Days;
 
 my $days = Octium::O::Days->instance ('135');
 
 say $days->as_plurals; # "Mondays, Wednesdays, and Fridays"
 say $days->as_adjectives; # "Monday, Wednesday, and Friday"
 say $days->as_abbrevs; # "Mon Wed & Fri"
 
=head1 DESCRIPTION

This class is used for objects storing scheduled day information. 
Trips, or timetables, are assigned to particular scheduled days. Almost
all the time this is either usually weekdays, Saturdays,  or
Sundays-and-Holidays.  However, there are lots of exceptions. Some
trips run only school days, while others run only school holidays. 
Some trips run only a few weekdays (e.g., Mondays, Wednesdays, and
Fridays).

This uses "flyweight" objects, meaning that it returns the same object
every time you pass particular arguments to construct it.  These
objects are immutable.

=head1 CLASS METHODS

=over

=item B<< Octium::O::Days->instance(I<daycode> , I<schooldaycode>) >>

The object is constructed using "Octium::O::Days->instance".

The ->instance method accepts a day specification as a string,
containing any or all of the numbers 1 through 7 and optionally H. If a
1 is present, it operates on Mondays; if 2, it operates on Tuesdays;
and so on through 7 for Sundays.  (7 is used instead of 0 for two
reasons: because Hastus provides it in this way, and because 0 is false
in perl and it's convenient to allow simple truth tests.)  The H, if
present, is used to indicate holidays. However, at this time the system
will add an H to any 7 specified.

The constructor also accepts a school days flag, a single character. If
specified, "D" indicates that it operates school days only, and "H"
that  it operates school holidays only. The default is "B", which
indicates that  operation on both school days and school holidays.
(This is regardless of whether school normally operates on that day --
weekend trips will  still have "B" as the school day flag, unless there
is a situation where some school service is operated on a Saturday.)

=item B<< Octium::O::Days->new(I<daycode> , I<schooldaycode>) >>

B<< Do not use this method. >>

This method is used internally by Octium::O::Days to create a new
object and insert it into the cache used by instance(). There should
never be a reason to create more than one method with the same
arguments.

=item B<< Octium::O::Days->instance_from_string (I<string>) >>

This is an alternative constructor. It uses a single string, rather
than the separate daycode and schooldaycode, to construct an object and
return it.

The only way to get a valid string is by using the I<as_string> object
method. The format of the string is internal and not guaranteed to
remain the same across versions of Octium::O::Days. The purpose of this
is to allow a single string to contain day information without
requiring it to have all the object overhead.

=item B<< Octium::O::Days->union(I<days_obj> , ... >>

Another constructor. It takes one or more Octium::O::Days objects and 
returns a new object representing the union of those objects. For
example, if passed an object representing Saturday and an object
representing Sunday,  will return an object representing both Saturday
and Sunday.

If the school day codes of the passed objects are identical, it will
use that code. Otherwise it will use "B".

=back

=head1 OBJECT METHODS

=over

=item B<< $obj->daycode >>

Returns the day specification: a string with one or more of the
characters 1 through 7, indicating operation on Monday through Sunday,
and the character H, indicating operation on holidays.

=item B<< $obj->schooldaycode >>

Returns one character. "D" indicates operation school days only. "H"
indicates operation school holidays only. "B" indicates operation on
both types of days. (Service on days when school service does not
operate is also indicated  by "B".)

=item B<< $obj->as_sortable >>

Returns a version of the day code / schoolday code that can be sorted
using  perl's cmp operator to be in order.

=item B<< $obj->as_string >>

Returns a version of the day code / schoolday code that can be used to
create a new object using B<instance_from_string>.

=item B<< $obj->as_adjectives >>

This returns a string containing English text describing the days in a
form intended for use to describe service: "This is <x> service."

The form is "Day, Day and Day" . The days used are as follows:

 Monday     Thursday   Sunday    Weekend
 Tuesday    Friday     Holiday   Daily
 Wednesday  Saturday   Weekday
 
May be followed by "(except school holidays)" or "(except school
days)".

=item B<< $obj->as_plurals >>

This returns a string containing English text describing the days in a
form intended for use as nouns: "This service runs <x>."

The form is "Days, Days and Days" . The days used are as follows:

 Mondays     Thursdays   Sundays    Every day
 Tuesdays    Fridays     Holidays
 Wednesdays  Saturdays   
 
"Monday through Friday" is given instead of "Weekdays."

(Saturdays and Sundays are not combined into weekends here.)

May be followed by "(School days only)" or "(School holidays only)".

=item B<< $obj->as_abbrevs >>

This returns a string containing English text describing the days in as
 brief a form as possible, for tables or other places with little
space.

The form is "Day Day & Day" . The days used are as follows:

 Mon     Thu    Sun       Daily
 Tue     Fri    Hol
 Wed     Sat    Weekday
 
May be followed by "(Sch days)" or "(Sch hols)".

=back

=head1 BUGS AND LIMITATIONS

Holidays are hard-coded to always go with Sundays. At the very least 
holidays should be allowed to go with Saturdays, since some agencies
run a Saturday rather than Sunday schedule on holidays.

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

