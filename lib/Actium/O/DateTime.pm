package Actium::O::DateTime 0.014;

# Object representing a date and time
# (a thin wrapper around the DateTime module, with some i18n methods)

# Non-moosey, because Moose kept interfering too much with
# constructor names and the like

use 5.022;
use warnings;    ### DEP ###

use Actium::Preamble;

use DateTime;
our @ISA = qw(DateTime);
# DateTime ### DEP ###

use overload q{""} => '_stringify';

sub _stringify {
    my $self = shift;
    return $self->long_en;
}

const my $CONSTRUCTOR => __PACKAGE__ . '->new';

sub new { # needs rewriting so it returns $self

    my $class = shift;

    croak "No arguments given to $CONSTRUCTOR" unless @_;

    my %args;

    if ( @_ == 1 and not u::is_plain_hashref( $_[0] ) ) {
        %args = ( datetime => $_[0] );
    }
    else {
        %args = @_;
    }

    my @special_args = (qw[datetime strp cldr ymd]);

    my $special_argcount = 0;
    foreach my $special_arg (@special_args) {
        $special_argcount++ if exists $args{$special_arg};
    }

    croak "Can't specify more than one of (@special_args) to $CONSTRUCTOR"
      if $special_argcount > 1;

    my $pattern;
    if ( $special_argcount and exists $args{pattern} ) {
        $pattern = delete $args{pattern};
    }

    croak "Can't specify both a special argument (one of @special_args) "
      . "and also DateTime arguments to $CONSTRUCTOR"
      if $special_argcount == 1 and ( scalar keys %args > 1 );

    if ($special_argcount) {

        if ( exists $args{datetime} ) {
            if ( u::is_blessed_ref( $args{datetime} ) ) {
                return { object => $args{datetime} };
            }

            $args{strptime} = delete $args{datetime};
        }

        if ( exists $args{strptime} ) {
            return { object => _dt_from_string( $args{strptime}, $pattern ) };
        }

        if ( exists $args{cldr} ) {
            return { object => _dt_from_cldr( $args{cldr}, $pattern ) };
        }

        if ( exists $args{ymd} ) {

            if ( not u::is_arrayref( $args{ymd} )
                or $args{ymd}->@* != 3 )
            {
                croak 'Argument to ymd must be a reference '
                  . 'to a three-element array (year, month, and day) in '
                  . $CONSTRUCTOR;
            }

            my ( $year, $month, $day ) = $args{ymd}->@*;

            %args = (
                year  => $year,
                month => $month,
                day   => $day
              )

        }

    } ## tidy end: if ($special_argcount)

    return { object => DateTime->new(%args) }

} ## tidy end: sub new

#######################################
## Return international date formats

my %locale_of_language = ( en => 'en_US', es => 'es_US', zh => 'zh_Hans' );
my @languages = qw/en es zh/;    # for order
# currently happens to be in alpha order, but Vietnamese or Korean
# would come after Chinese

# have to rewrite non-moosey

my $format_language_cr = sub {
    my $self     = shift;
    my $format   = shift;
    my $language = shift;
    my $locale   = shift;

    my $dt     = $self->datetime_obj;
    my $method = "date_format_$format";

    require DateTime::Locale;
    require DateTime::Format::CLDR;

    my $dl = DateTime::Locale->load($locale);

    my $cldr = DateTime::Format::CLDR->new(
        locale  => $locale,
        pattern => $dl->$method,
    );

    return $cldr->format_datetime($dt);

};

# There ought to be a way to dynamically generate those but I can't
# figure it out right now

sub long_en {
    my $self     = shift;
    my $language = 'en';
    my $format   = 'long';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub long_es {
    my $self     = shift;
    my $language = 'es';
    my $format   = 'long';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub long_zh {
    my $self     = shift;
    my $language = 'zh';
    my $format   = 'long';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub full_en {
    my $self     = shift;
    my $language = 'en';
    my $format   = 'full';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub full_es {
    my $self     = shift;
    my $language = 'es';
    my $format   = 'full';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub full_zh {
    my $self     = shift;
    my $language = 'zh';
    my $format   = 'full';
    my $locale   = $locale_of_language{$language};
    return $format_language_cr->( $self, $language, $format, $locale );
}

sub longs {
    my $self = shift;

    my @return;

    foreach my $language (@languages) {
        my $locale = $locale_of_language{$language};

        my $method = "long_$language";
        push @return, $self->$method;
    }

    return \@return;

}

sub fulls {
    my $self = shift;

    my @return;

    foreach my $language (@languages) {
        my $locale = $locale_of_language{$language};

        my $method = "full_$language";
        push @return, $self->$method;
    }

    return \@return;

}

{

    my %strp_obj_of;

    sub _dt_from_string {

        my $datestr = shift;
        my $pattern = shift // $datestr =~ m{/} ? '%m/%d/%Y' : '%Y-%m-%d';
        # %Y - four-digit year (unlike %D)

        require DateTime::Format::Strptime;

        my $strp_obj = $strp_obj_of{$pattern}
          //= DateTime::Format::Strptime->new(
            pattern => $pattern,
            locale  => 'en_US'
          );

        # %Y - four-digit year (unlike %D)

        return $strp_obj->parse_datetime($datestr);

    }

}

sub _dt_from_cldr {

    my $datestr = shift;
    my $pattern = shift;

    unless ($pattern) {
        if ( $datestr =~ m{/} ) {
            $pattern = 'M/d/y';
        }
        else {
            $pattern = "y-d-M";
        }

        require DateTime::Format::CLDR;    ### DEP ###
        my $dt = DateTime::Format::CLDR::cldr_parse( $pattern, $datestr );

        return $dt;

    }

} ## tidy end: sub _dt_from_cldr

# CLASS METHOD

sub newest_date {
    my $class = shift;

    my @dates = @_;

    my $newest_date;

    foreach my $date (@dates) {

        if ( not u::is_blessed_ref($date) ) {
            $date = _dt_from_string($date);
        }

        if (not defined $newest_date
            or ( defined $date
                and $class->compare( $newest_date, $date ) == -1 )
          )
        {
            $newest_date = $date;
        }
    }

    return if not defined $newest_date;

    if ( not $newest_date->isa(__PACKAGE__) ) {
        $newest_date = Actium::O::DateTime::->new($newest_date);
        # if somebody is passing DateTime objects,
        # turns them into Actium::O::DateTime objects
    }

    return $newest_date;

} ## tidy end: sub newest_date

1;

__END__

=encoding utf8

=head1 NAME

Actium::O::DateTime - dates (and times) for Actium

=head1 VERSION

This documentation refers to version 0.014

=head1 SYNOPSIS

 use Actium::O::DateTime;
 
 my $dt = Actium::O::DateTime->('3/27/2017');
 # or equivalently
 my $dt = Actium::O::DateTime->(datetime => '3/27/2017');
 
 my $date_es = $dt->long_es;
 # $date_es = "27 de marzo de 2017";
   
=head1 DESCRIPTION

Actium::O::DateTime is a thin wrapper around L<DateTime>. 
It delegates almost everything to DateTime, while providing a few
convenience methods and convenience ways of constructing the object. 

Actium::O::DateTime was created in order to do comparisons and presentation of
dates rather than times. Therefore, its own methods ignore such details as 
time zones, leap seconds and the like. 
Theoretically you could use Actium::O::DateTime 
objects to do processing on time, but it's not really intended for that 
purpose.

=head1 METHODS

=over

=item B<new()>

This subroutine takes arguments and returns a new Actium::O::DateTime object.

Most arguments must be specified using names: 

    $dt = 
      Actium::O::DateTime->new(
        cldr => '31-5-2017' , pattern => 'D-M-Y' 
      );
    
If a single positional argument is seen, 
then it is treated as an argument to 'datetime', below.

There are four special arguments that signal that Actium::O::DateTime should
proocess its input (rather than passing them directly to DateTime->new).
One cannot use the special arguments and arguments to DateTime at the same time.
One additional argument, "pattern," is used in conjuction with the "cldr" 
and "strptime" arguments.

=over


=item cldr

This is treated as a string, to be parsed by DateTime::Format::CLDR.
The result becomes the DateTime delegate object.

If the named argument "pattern" is present, that will be passed to 
DateTime::Format::CLDR. Otherwise, it will use the pattern 
"M/d/y" if slashes are present in the value, or the pattern "y-d-M" otherwise.

=item datetime

The named datetime argument can be one of three things:

=over

=item * 

A blessed object that does not have datetime_obj as a method. In this case,
it is presumed that this is itself a DateTime object, and it used as the
object to which Actium::O::DateTime will delegate methods.

=item * 

A blessed object that has "datetime_obj" as a method.  In this event, the result
from datetime_obj is used as the object to which Actium::O::DateTime will
delegate methods. This allows you to pass other Actium::O::DateTime objects
to Actium::O::DateTime->new (although I'm not sure this has any benefit really).

=item *

Anything else. This is treated as the argument to strptime. (It exists here
to ease processing for a single positional argument.)

=back

=item pattern

See the "cldr" and "strptime" arguments.

=item strptime

This is treated as a string, to be parsed by DateTime::Format::Strptime.
The result becomes the DateTime delegate object.

If the named argument "pattern" is present, that will be passed to 
DateTime::Format::Strptime. Otherwise, it will use the pattern 
"%m/%d/%Y" (e.g., 12/31/2017) if any slashes are present in the value, or the
pattern "%Y-%m-%d" (e.g., 2017-12-31) otherwise. 

=item ymd

If passed, this value must be a reference to an array with three entries, 
representing the year, month, and day, in order. These are submitted as 
year, month and day to DateTime->new.

=back

Any other arguments are passed to DateTime->new, and the results are used
as the delegate object.

=item B<datetime_obj()>

This provides access to the delegate object, should that be necessary.

=item B<long_en()>

=item B<long_es()>

=item B<long_zh()>

=item B<full_en()>

=item B<full_es()>

=item B<full_zh()>

These provide dates formatted in the appropriate languages: English, Spanish, 
or Chinese (simplified), using the locales "en_US", "es_US", and "zh_Hans".

The "long" date formats provide the full name of the month, the day
and the year.  The "full" date formats add the weekday as well.

=item B<newest_date($date, $date, $date...)>

This class method (not object method) calculates the newest date
from a list of dates passed to it. (Note that the invocant is assumed
to be the class name and is not used in the calculation.)  The dates
can be Actium::O::DateTime objects, DateTime objects, or strings;
if they are strings they will be formatted as dates as though they
were passed to new() in the strptime argument.  The return value
is an Actium::O::DateTime object.

=back

=head1 DIAGNOSTICS

=over

=item * 

No arguments given to Actium::O::DateTime->new

Some arguments must be passed in calls to new().
    
=item  *

Can't specify more than one of (datetime strptime cldr ymd) to Actium::O::DateTime->new

The "datetime," "strptime," "cldr," and "ymd" arguments are mutually exclusive.
Specify just one.

=item *

Can't specify both a special argument (one of datetime strptime cldr ymd) 
and also DateTime arguments to Actium::O::DateTime->new

The "datetime", "strptime," "cldr," and "ymd" arguments must be
specified alone, or in the case of "strptime" or "cldr," only with the
"pattern" argument.  Specify just one.

=item *

Argument to ymd must be a reference to a three-element array (year,
month, and day) in Actium::O::DateTime->new()

Some other sort of argument was recieved. 

=back

=head1 DEPENDENCIES

=over

=item * 

DateTime

=item * 

DateTime::Format::CLDR

=item * 

DateTime::Format::Strptime

=item * 

DateTime::Locale

=item *

Moose

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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
