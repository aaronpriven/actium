package Actium::O::DateTime 0.014;

# Object representing a date and time
# (a thin wrapper around the DateTime module, with some i18n methods)

# Non-moosey, because Moose kept interfering too much with
# constructor names and the like

use Actium;

use parent 'DateTime';
# DateTime ### DEP ###

use overload q{""} => '_stringify';

sub _stringify {
    my $self = shift;
    return $self->long_en;
}

const my $CONSTRUCTOR => __PACKAGE__ . '->new';

sub _datetime_arg {
    my $class = shift;
    my $arg   = shift;
    if ( u::is_blessed_ref($arg) ) {
        return $class->from_object($arg);
    }
    return $class->_from_strptime($arg);
}

sub new {

    my $class = shift;

    croak "No arguments given to $CONSTRUCTOR" unless @_;

    if ( @_ == 1 and not u::is_plain_hashref( $_[0] ) ) {
        return $class->_datetime_arg(@_);
    }

    my %args = @_;

    my @exclusive_args         = (qw[datetime strp cldr]);
    my $exclusive_args_display = u::joinseries_or(@exclusive_args);
    my $exclusive_argcount     = scalar( @args{@exclusive_args} ) // 0;

    croak
      "Can't specify more than one of ($exclusive_args_display) to $CONSTRUCTOR"
      if $exclusive_argcount > 1;

    my $pattern;
    if ( exists $args{pattern} ) {
        if ($exclusive_argcount) {
            $pattern = delete $args{pattern};
        }
        else {
            croak "Can't specify a pattern without specifying "
              . "one of $exclusive_args_display to "
              . $CONSTRUCTOR;
        }
    }

    croak(  "Can't specify both a exclusive argument "
          . "(one of $exclusive_args_display)"
          . " and also DateTime arguments to $CONSTRUCTOR" )
      if $exclusive_argcount == 1 and ( scalar keys %args > 1 );

    return $class->_datetime_arg( $args{datetime} )
      if ( exists $args{datetime} );

    return $class->_from_strptime( $args{strptime}, $pattern )
      if ( exists $args{strptime} );

    return $class->_from_cldr( $args{cldr}, $pattern )
      if ( exists $args{cldr} );

    if ( exists $args{ymd} ) {

        if ( not u::is_arrayref( $args{ymd} )
            or $args{ymd}->@* != 3 )
        {
            croak 'Argument to ymd must be a reference '
              . 'to a three-element array (year, month, and day) in '
              . $CONSTRUCTOR;
        }

        croak "Can't specify ymd and also either year, month, or day to"
          . $CONSTRUCTOR
          if exists $args{year}
          or exists $args{month}
          or exists $args{day};

        my ( $year, $month, $day ) = $args{ymd}->@*;

        %args = (
            %args,
            year  => $year,
            month => $month,
            day   => $day
          )

    } ## tidy end: if ( exists $args{ymd})

    return $class->SUPER::new(%args);

} ## tidy end: sub new

{

    my %strp_obj_of;

    sub _from_strptime {
        my $class   = shift;
        my $datestr = shift;
        my $pattern = shift // $datestr =~ m{/} ? '%m/%d/%Y' : '%Y-%m-%d';
        # %Y - four-digit year (unlike %D)

        require DateTime::Format::Strptime;    ### DEP ###

        my $strp_obj = $strp_obj_of{$pattern}
          //= DateTime::Format::Strptime->new(
            pattern  => $pattern,
            locale   => 'en_US',
            on_error => 'croak',
          );

        my $obj = $strp_obj->parse_datetime($datestr);

        # returns a DateTime object.
        # This re-blesses it into an Actium::O::DateTime object

        bless $obj, $class;
        return $obj;

    } ## tidy end: sub _from_strptime

    my %cldr_obj_of;

    sub _from_cldr {

        my $class   = shift;
        my $datestr = shift;
        my $pattern = shift // $datestr =~ m{/} ? 'M/d/y' : 'y-d-m';

        require DateTime::Format::CLDR;    ### DEP ###

        my $cldr = $cldr_obj_of{$pattern} //= DateTime::Format::CLDR->new(
            $pattern => $pattern,
            locale   => 'en_US',
            on_error => 'croak',
        );

        my $obj = $cldr->parse_datetime($datestr);

        # returns a DateTime object.
        # This re-blesses it into an Actium::O::DateTime object

        bless $obj, $class;
        return $obj;

    } ## tidy end: sub _from_cldr

} ## tidy end: sub _dt_from_cldr

### OBJECT METHODS

{

## international date formats

    my %locale_of_language = (
        en => 'en_US',
        es => 'es_US',
        zh => 'zh_Hans'
    );

    my @languages = qw/en es zh/;    # for order
         # currently happens to be in alpha order, but Vietnamese or Korean
         # would come after Chinese

    my $format_language_cr = sub {
        my $self     = shift;
        my $language = shift;
        my $format   = shift;
        my $locale   = $locale_of_language{$language};

        my $method = "date_format_$format";

        require DateTime::Locale;          ### DEP ###
        require DateTime::Format::CLDR;    ### DEP ###

        my $dl = DateTime::Locale->load($locale);

        my $cldr = DateTime::Format::CLDR->new(
            locale  => $locale,
            pattern => $dl->$method,
        );

        return $cldr->format_datetime($self);

    };

    sub long_en {
        my $self = shift;
        return $format_language_cr->( $self, 'en', 'long' );
    }

    sub long_es {
        my $self = shift;
        return $format_language_cr->( $self, 'es', 'long' );
    }

    sub long_zh {
        my $self = shift;
        return $format_language_cr->( $self, 'zh', 'long' );
    }

    sub full_en {
        my $self = shift;
        return $format_language_cr->( $self, 'en', 'full' );
    }

    sub full_es {
        my $self = shift;
        return $format_language_cr->( $self, 'es', 'full' );
    }

    sub full_zh {
        my $self = shift;
        return $format_language_cr->( $self, 'zh', 'full' );
    }

    my $formats_cr = sub {
        my $self   = shift;
        my $format = shift;

        my @ret;

        foreach my $language (@languages) {
            my $method = $format . "_$language";
            push @ret, $self->$method;
        }

        return \@ret;
    };

    sub longs {
        my $self = shift;
        return $formats_cr->( $self, 'long' );

    }

    sub fulls {
        my $self = shift;
        return $formats_cr->( $self, 'full' );
    }

}

# CLASS METHOD

sub newest_date {
    my $class = shift;

    my @dates = @_;

    my $newest_date;

    foreach my $date (@dates) {

        if ( not u::is_blessed_ref($date) ) {
            $date = $class->_from_strptime($date);
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

Actium::O::DateTime is a thin wrapper around L<DateTime>.  In inherits
almost almost everything from DateTime, while providing a few
convenience methods and convenience ways of constructing the object.

Actium::O::DateTime was created in order to do comparisons and
presentation of dates rather than times. Therefore, its own methods
ignore such details as  time zones, leap seconds and the like. 
Theoretically you could use Actium::O::DateTime  objects to do
processing on time, but it's not really intended for that  purpose.

=head1 METHODS

=over

=item B<new()>

This subroutine takes arguments and returns a new Actium::O::DateTime
object.

Most arguments must be specified using names:

    $dt = 
      Actium::O::DateTime->new(
        cldr => '31-5-2017' , pattern => 'D-M-Y' 
      );
    
If a single positional argument is seen,  then it is treated the same
as an argument to 'datetime', below.

The arguments used by Actium::O::DateTime are given below. If none of
these arguments are present, the arguments are passed through to
DateTime. Only one of "datetime", "strptime" or "cldr" can be present, 
and if one is, none of the other arguments other than "pattern" can be
present.

=over

=item cldr

This is treated as a string, to be parsed by DateTime::Format::CLDR.

If the named argument "pattern" is present, that will be passed to 
DateTime::Format::CLDR. Otherwise, it will use the pattern  "M/d/y" if
slashes are present in the value, or the pattern "y-d-M" otherwise.

=item datetime

The named datetime argument can be:

=over

=item * 

An object. A new object is returned using DateTime->from_object, q.v.

=item * 

A string. This is treated as the argument to strptime.

=back

=item pattern

See the "cldr" and "strptime" arguments. This cannot be specified
unless one of datetime, strptime, or cldr is also specified.

=item strptime

This is treated as a string, to be parsed by
DateTime::Format::Strptime.

If the named argument "pattern" is present, that will be passed to 
DateTime::Format::Strptime. Otherwise, it will use the pattern 
"%m/%d/%Y" (e.g., 12/31/2017) if any slashes are present in the value,
or the pattern "%Y-%m-%d" (e.g., 2017-12-31) otherwise.

=item ymd

If passed, this value must be a reference to an array with three
entries,  representing the year, month, and day, in order. These are
submitted as  year, month and day to DateTime->new.  If it is present,
none of  "year", "month" and "day" can also be present.

=back

Any other arguments are treated as they are in DateTime.

=item B<long_en()>

=item B<long_es()>

=item B<long_zh()>

=item B<full_en()>

=item B<full_es()>

=item B<full_zh()>

These provide dates formatted in the appropriate languages: English,
Spanish,  or Chinese (simplified), using the locales "en_US", "es_US",
and "zh_Hans".

The "long" date formats provide the full name of the month, the day and
the year.  The "full" date formats add the weekday as well.

=item B<fulls>

=item B<longs>

These return a reference to an array of each of the appropriate "full"
or  "long" values, in language order. The order is currently
alphabetical, although if more languages are added later, they will
probably be added  at the end.

=item B<newest_date($date, $date, $date...)>

This class method (not object method) calculates the newest date from a
list of dates passed to it. (Note that the invocant is assumed to be
the class name and is not used in the calculation.)  The dates can be
Actium::O::DateTime objects, DateTime objects, or strings; if they are
strings they will be formatted as dates as though they were passed to
new() in the strptime argument.  The return value is an
Actium::O::DateTime object.

=back

=head1 DIAGNOSTICS

=over

=item * 

No arguments given

Some arguments must be passed in calls to new().

=item  *

Can't specify more than one of ...

The "datetime", "strptime", and "cldr" arguments are mutually
exclusive. Specify just one.

=item *

Can't specify a pattern without specifying one of ...

The "pattern" argument has no meaning unless it is coupled  with either
"datetime", "strptime", or "cldr". Specify one.

=item *

Can't specify both a exclusive argument (one of ... ) and also DateTime
 arguments

The "datetime", "strptime" or "cldr" arguments must be specified alone
or with the "pattern" argument, and cannot be combined with any of the
regular arguments to DateTime.

=item *

Argument to ymd must be a reference to a three-element array (year,
month, and day)

Some other sort of argument was recieved than a reference to a 
three-element array.  Specify just the year, month, and day.

=item *

Can't specify ymd and also either year, month, or day ...

The "ymd" argument repalces the "year", "month", and "day" arguments to
 DateTime, so you can't specify both. Specify one of either "ymd" or 
the separate set of "year", "month", and "day" arguments.

=back

See also the dependencies, below.

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

