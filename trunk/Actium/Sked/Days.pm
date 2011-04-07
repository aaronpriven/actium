# Actium/Sked/Days.pm

# Object representing the scheduled days (of a trip, or set of trips)

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::Sked::Days 0.001;

use Moose;
use MooseX::StrictConstructor;

use Actium::Types qw<DayCode SchoolDayCode>;
use Actium::Util qw<positional joinseries>;
use Actium::Constants;

use Carp;
use Readonly;
use List::MoreUtils ('mesh');

use Data::Dumper;

###################################
#### ENGLISH NAMES FOR DAYS CONSTANTS
###################################

Readonly my @DAYLETTERS => qw(1 2 3 4 5 6 7 H W E D X);

# 1 = Monday, 2 = Tuesday, ... 7 = Sunday
# H = holidays, W = Weekdays, E = Weekends, D = Daily,
# X = every day except holidays

Readonly my @SEVENDAYNAMES =>
  qw(Monday Tuesday Wednesday Thursday Friday Saturday Sunday);
Readonly my @SEVENDAYPLURALS => ( map {"${_}s"} @SEVENDAYNAMES );
Readonly my @SEVENDAYABBREVS => map { substr( $_, 0, 3 ) } @SEVENDAYNAMES;

###################################
#### ATTRIBUTES AND CONSTRUCTION
###################################

around BUILDARGS => sub {
    return positional( \@_, 'daycode', 'schooldaycode' );
};

has 'daycode' => (
    is          => 'ro',
    isa         => DayCode,
    required    => 1,
    initializer => '_initialize_daycode',
    coerce => 1,
);

# New day codes have a character for each set of days that are used.
# 1 - 7 : Monday through Sunday (like in Hastus), and H - Holidays

sub _initialize_daycode {
    my $self    = shift;
    my $daycode = shift;
    my $set     = shift;
    
    #$daycode = $DAYS_FROM_TRANSITINFO{$daycode} if $DAYS_FROM_TRANSITINFO{$daycode};
    # if passed a day code from the Transitinfo definitions, convert it
    # TODO - maybe use coercion instead?

    $daycode =~ s/\D//g;
    # eliminate anything that's not a digit

    # TODO - add option to make it Saturdays-and-holidays
    #    instead of Sundays-and-holidays, or treat holidays as a separate
    #    schedule

    $daycode =~ s/7H?/7H/;    # make sure Sundays always includes holidays
    
    $set->($daycode);
} ## tidy end: sub _initialize_daycode

has 'schooldaycode' => (
    is      => 'ro',
#    isa => 'Str' , # code not working and I don't know why
    isa     => SchoolDayCode,    # [BDH]
    default => 'B',
);
# D = school days only, H = school holidays only, B = both

has '_composite_code' => (
    is       => 'ro',
    init_arg => undef,
    builder  => '_build_composite_code',
    lazy     => 1,
);

sub _build_composite_code {
    my $self          = shift;
    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    return $self->daycode unless $schooldaycode;
    return $self->schooldaycode . $self->daycode;
}

sub as_sortable {
    my $self = shift;
    return $self->_composite_code;
}
# composite_code not guaranteed to remain sortable in the future

sub as_transitinfo {

    my $self      = shift;
    my $composite = $self->_composite_code;

    state %cache;
    return $cache{$composite} if $cache{$composite};

    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;

    return $cache{$composite} = "SD" if $self->_is_SD;
    return $cache{$composite} = "SH" if $self->_is_SH;

    my $transitinfo = $TRANSITINFO_DAYS_OF{$daycode};

    return $cache{$composite} = $transitinfo if $transitinfo;
    return $cache{$composite} = $self->_invalid_transitinfo_daycode;

} ## tidy end: sub as_transitinfo

sub _invalid_transitinfo_daycode {
    my $self          = shift;
    my $daycode       = $self->daycode;
    my $schooldaycode = $self->schooldaycode;
    carp qq[Using invalid Transitinfo daycode XX for <$daycode/$schooldaycode>];
    return 'XX';
}

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

Readonly my @ADJECTIVES => ( @SEVENDAYNAMES, qw(Holiday Weekday Weekend Daily),
    "Daily except holidays" );
Readonly my %ADJECTIVE_OF => mesh( @DAYLETTERS, @ADJECTIVES );
Readonly my %ADJECTIVE_SCHOOL_OF => (
    B => $EMPTY_STR,
    D => ' (except school holidays)',
    H => ' (except school days)',
);

sub as_adjectives {

    my $self      = shift;
    
    my $composite = $self->_composite_code;

    state %cache;
    return $cache{$composite} if $cache{$composite};

    my $daycode = $self->daycode;
    $daycode =~ s/1234567H/D/;    # every day
    $daycode =~ s/1234567/X/;     # every day except holidays
    $daycode =~ s/12345/W/;       # weekdays
    $daycode =~ s/67/E/;          # weekends

    my $schooldaycode = $self->schooldaycode;

    my @as_adjectives = map { $ADJECTIVE_OF{$_} } split( //, $daycode );
    
    if (not @as_adjectives) {
     
      say Data::Dumper::Dumper($self);
    }

    my $results
      = joinseries(@as_adjectives) . $ADJECTIVE_SCHOOL_OF{$schooldaycode};

    return $cache{$composite} = $results;

} ## tidy end: sub as_adjectives

Readonly my @PLURALS => (
    @SEVENDAYPLURALS, qw(Holidays Weekdays Weekends),
    'Every day', "Every day except holidays"
);

Readonly my %PLURAL_OF => mesh( @DAYLETTERS, @PLURALS );
Readonly my %PLURAL_SCHOOL_OF => (
    B => $EMPTY_STR,
    D => ' (School days only)',
    H => ' (School holidays only)',
);

sub as_plurals {

    my $self      = shift;
    my $composite = $self->_composite_code;

    state %cache;
    return $cache{$composite} if $cache{$composite};

    my $daycode = $self->daycode;
    $daycode =~ s/1234567H/D/;    # every day
    $daycode =~ s/1234567/X/;     # every day except holidays
    $daycode =~ s/12345/W/;       # weekdays
         # $daycode =~ s/67/E/;  # weekends intentionally omitted

    my $schooldaycode = $self->schooldaycode;

    my @as_plurals = map { $PLURAL_OF{$_} } split( //, $daycode );
    my $results = joinseries(@as_plurals);

    if ( $PLURAL_SCHOOL_OF{$schooldaycode} ) {

        my $results .= $PLURAL_SCHOOL_OF{$schooldaycode};
    }
    else {

        $results .= ' except holidays' unless $daycode =~ /H/;
    }

    return $cache{$composite} = $results;

} ## tidy end: sub as_plurals
Readonly my @ABBREVS =>
  ( @SEVENDAYABBREVS, qw(Hol Weekday Weekend), 'Daily', "Daily except Hol" );

Readonly my %ABBREV_OF => mesh( @DAYLETTERS, @PLURALS );
Readonly my %ABBREV_SCHOOL_OF => (
    B => $EMPTY_STR,
    D => ' (Sch days)',
    H => ' (Sch hols)',
);

sub as_abbrevs {

    my $self      = shift;
    my $composite = $self->_composite_code;

    state %cache;
    return $cache{$composite} if $cache{$composite};

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

    return $cache{$composite} = $results;

} ## tidy end: sub as_abbrevs

1;

__END__

=head1 NAME

Actium::Sked::Days - Object for holding scheduled days

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Sked::Days;
 
 my $daycode = Actium::Sked::Days->new ('135');
 
 say $daycode->as_plurals; # "Mondays, Wednesdays, and Fridays"
 say $daycode->as_adjectives; # "Monday, Wednesday, and Friday"
 say $daycode->as_abbrevs; # "Mon Wed & Fri"
 
 say $daycode->as_transitinfo; # 'MZ'
 
=head1 DESCRIPTION

This class is used for objects storing scheduled day information. 
Trips, or timetables, are assigned to particular scheduled days.
Almost all the time this is either usually weekdays, Saturdays, 
or Sundays-and-Holidays.  However, there are lots of exceptions.
Some trips run only school days, while others run only school holidays. 
Some trips run only a few weekdays (e.g., Mondays, Wednesdays, and Fridays).

=head1 METHODS

=over

=item B<Actium::Sked::Days->new(I<daycode> , I<schooldaycode>)>

The object is constructed using "Actium::Sked::Days->new".  

It accepts a day specification 
as a string, containing any or all of the numbers 1 through 7 and optionally H.
If a 1 is present, it operates on Mondays; if 2, it operates on Tuesdays;
and so on through 7 for Sundays.  (7 is used instead of 0 for two reasons:
because Hastus provides it in this way, and because 0 is false in perl and it's
convenient to allow simple truth tests.)  The H, if present, is used to
indicate holidays. However, at this time the system will add an H to any 7
specified.

As an alternative, the two-letter codes derived from those used by the old 
www.transitinfo.org web site may be specified. See 
L<as_transitinfo|/as_transitinfo> below. 

The constructor also accepts a school days flag, a single character.
If specified, "D" indicates that it operates school days only, and "H" that 
it operates school holidays only. The default is "B", which indicates that 
operation on both school days and school holidays. (This is regardless of
whether school normally operates on that day -- weekend trips will 
still have "B" as the school day flag, unless there is a situation where
some school service is operated on a Saturday.)

=item B<$obj->daycode()>

Returns the day specification: a string with one or more of the characters
1 through 7, indicating operation on Monday through Sunday, and the character
H, indicating operation on holidays.

=item B<$obj->schooldaycode()>

Returns one character. "D" indicates operation school days only. "H" indicates
operation school holidays only. "B" indicates operation on both types of days.
(Service on days when school service does not operate is also indicated 
by "B".)

=item B<$obj->as_sortable()>

Returns a version of the day code / schoolday code that can be sorted using 
perl's cmp operator to be in order.

=item B<$obj->as_transitinfo>

Returns the two-letter code for the day derived from the codes used by the 
old www.transitinfo.org web site.

Here is a table of equivalents:

      DA  1234567H    SU  7H      TF  25
      WD  12345       WE  67H     WF  35
      SA  6           TT  24      MZ  135
 
Since these codes do not allow for
the full range of possibilities, these codes probably should not be used
in new situations.

Where there is no valid code for the days, the code "XX" is returned and a
warning is generated (using "carp").

=item B<$obj->as_adjectives>

This returns a string containing English text describing the days in a
form intended for use to describe service: "This is <x> service."

The form is "Day, Day and Day" . The days used are as follows:

 Monday     Thursday   Sunday    Weekend
 Tuesday    Friday     Holiday   Daily
 Wednesday  Saturday   Weekday
 
May be followed by "(except school holidays)" or "(except school days)".

=item B<$obj->as_plurals>

This returns a string containing English text describing the days in a
form intended for use as nouns: "This service runs <x>."

The form is "Days, Days and Days" . The days used are as follows:

 Mondays     Thursdays   Sundays    Every day
 Tuesdays    Fridays     Holidays
 Wednesdays  Saturdays   Weekdays
 
(Saturdays and Sundays are not combined into weekends here.)
 
May be followed by "(School days only)" or "(School holidays only)".

=item B<$obj->as_abbrevs>

This returns a string containing English text describing the days in as 
brief a form as possible, for tables or other places with little space.

The form is "Day Day & Day" . The days used are as follows:

 Mon     Thu    Sun       Daily
 Tue     Fri    Hol
 Wed     Sat    Weekday
 
May be followed by "(Sch days)" or "(Sch hols)".

=back

=head1 BUGS

Holidays are hard-coded to always go with Sundays. At the very least 
holidays should be allowed to go with Saturdays, since some agencies run
a Saturday rather than Sunday schedule on holidays.

=head1 DEPENDENCIES

=over

=item Perl 5.012 and the standard distribution.

=item List::MoreUtils

=item Moose

=item MooseX::StrictConstructor

=item Readonly

=item Actium::Constants

=item Actium::Types

=item Actium::Util

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 
