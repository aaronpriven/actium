# Actium/O/DateTime.pm

# Object representing a date and time
# (a thin wrapper around the DateTime module, with some i18n methods)

package Actium::O::DateTime 0.010;

use 5.016;
use warnings;    ### DEP ###

use Actium::Moose;
use DateTime;    ### DEP ###

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

    my @args = (qw[datetime strp cldr]);

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

my @locales = qw/en_US es_US zh_Hans/;
my @formats = qw/long full/;


foreach my $format (@formats) {

# This creates methods long_en_US, long_es_US, long_zh_Hans, full_en_US, etc.

    foreach my $locale (@locales) {
        has "${format}_$locale" => (
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

    } ## tidy end: foreach my $locale (@locales)
    
    # This creates longs and fulls

    has "${format}s_r" => (

        reader   => "_${format}s_r",
        init_arg => undef,
        isa      => 'ArrayRef[Str]',
        traits   => ['Array'],
        handles  => { "${format}s" => 'elements' },
        builder  => sub {
            my $self = shift;

            my @return;

            foreach my $locale (@locales) {
                my $method = "${format}_$locale";
                push @return, $self->$method;
            }

            return @return;
        },
    );

} ## tidy end: foreach my $format (@formats)

1;

__END__


my $dt = DateTime->new(%date);



my @locales = qw/en_US es_US zh_Hans/;

foreach my $locale (@locales) {
   my $dl = DateTime::Locale->load($locale);
   my $pattern = $dl->date_format_full;
   my $cldr = DateTime::Format::CLDR->new(
    locale      => $locale,
     pattern => $pattern, 
  );
  print $cldr->format_datetime($dt) , "\t";
  $cldr->pattern($dl->date_format_long);
  say $cldr->format_datetime($dt);

}




1;

__END__
