package Actium::O::DateTime 0.012;

# Object representing a date and time
# (a thin wrapper around the DateTime module, with some i18n methods)

use 5.016;
use warnings;    ### DEP ###

use Actium::Moose;
use DateTime;    ### DEP ###

use overload q{""} => '_stringify';

sub _stringify {
    my $self = shift;
    return $self->long_en;
}

around BUILDARGS => sub {

    my $orig = shift;
    my $self = shift;

    my $args_r;

    my $methodname = __PACKAGE__ . '->new';

    croak "No arguments given to $methodname" unless @_;

    if ( @_ == 1 and ref( $_[0] ) ne 'HASH' ) {
        $args_r = $self->$orig( { datetime => $_[0] } );
    }
    else {
        $args_r = $self->$orig(@_);
    }

    my @args = (qw[datetime strp cldr ymd]);

    my $argcount = 0;
    foreach my $arg (@args) {
        $argcount++ if exists $args_r->{$arg};
    }

    croak "Can't specify more than one of (@args) to " . __PACKAGE__ . '->new'
      if $argcount > 1;

    if ( exists $args_r->{datetime}
        and not( u::blessed( $args_r->{datetime} ) ) )
    {
        $args_r->{strptime} = $args_r->{datetime};
    }

    if ( exists $args_r->{strptime} ) {

        require DateTime::Format::Strptime;    ### DEP ###

        my $pattern = $args_r->{pattern} || '%m/%d/%Y';

        $args_r->{datetime} = DateTime::Format::Strptime::strptime( $pattern,
            $args_r->{strptime} );

        delete @{$args_r}{qw[strptime pattern]};
    }
    elsif ( exists $args_r->{cldr} ) {

        require DateTime::Format::CLDR;        ### DEP ###

        my $pattern = $args_r->{pattern} || 'M/d/y';
        $args_r->{datetime}
          = DateTime::Format::Cldr::cldr_parse( $pattern, $args_r->{strptime} );
        delete @{$args_r}{qw[cldr pattern]};

    }
    elsif ( exists $args_r->{ymd} ) {

        if ( u::reftype( $args_r->{ymd} ) ne 'ARRAY'
            or @{ $args_r->{ymd} } != 3 )
        {
            croak 'Argument to ymd must be a reference '
              . 'to a three-element array (year, month, and day) in '
              . __PACKAGE__ . '->new';
        }

        my ( $year, $month, $day ) = @{ $args_r->{ymd} };
        $args_r->{datetime}
          = DateTime::->new( year => $year, month => $month, day => $day );
        delete $args_r->{ymd};

    }

    return $args_r;

};

has datetime_obj => (
    is       => 'ro',
    isa      => 'DateTime',
    init_arg => 'datetime',
    handles  => [
        qw(
          doq doy iso8601 mday min mjd mon sec strftime time time_zone
          wday week week_number week_of_month week_year weekday_of_month
          ymd add clone datetime day day_abbr day_name day_of_month_0
          day_of_quarter day_of_week day_of_year dmy epoch formatter
          hms hour is_leap_year mdy minute month month_0 month_abbr
          month_name quarter second set set_day set_formatter
          set_hour set_locale set_minute set_month set_nanosecond
          set_second set_time_zone set_year subtract year ymd
          )
    ],
);

#######################################
## Return international date formats

my %locale_of_language = ( en => 'en_US', es => 'es_US', zh => 'zh_Hans' );
my @languages = qw/en es zh/; # for order
# currently happens to be in alpha order, but Vietnamese or Korean
# would come after Chinese

my @formats = qw/long full/;

foreach my $format (@formats) {

    # This creates methods long_en, long_es, long_zh, full_en, etc.

    foreach my $language ( keys %locale_of_language ) {
        my $locale = $locale_of_language{$language};
        has "${format}_$language" => (
            is      => 'ro',
            isa     => 'Str',
            lazy    => 1,
            default => sub {

                my $self   = shift;
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

            },

        );

    } ## tidy end: foreach my $language ( keys...)

    # This creates longs and fulls

    has "${format}s_r" => (

        reader   => "_${format}s_r",
        init_arg => undef,
        isa      => 'ArrayRef[Str]',
        traits   => ['Array'],
        handles  => { "${format}s" => 'elements' },
        lazy     => 1,
        default  => sub {
            my $self = shift;

            my @return;

            foreach my $language ( @languages ) {
                my $locale = $locale_of_language{$language};

                my $method = "${format}_$language";
                push @return, $self->$method;
            }

            return \@return;
        },
    );

} ## tidy end: foreach my $format (@formats)

1;

__END__
