#Actium/EffectiveDate.pm

# Subversion: $Id$

use 5.012;
use warnings;

package Actium::EffectiveDate 0.001;
use Actium::Constants;

use Sub::Exporter -setup =>
  { exports => [qw(long_date file_date effectivedate newest_date)] };

sub effectivedate {
    # lame and should be replaced...

    my $signup   = shift;
    my $filespec = $signup->make_filespec('effectivedate.txt');

    open my $date, '<', $filespec
      or die "Can't open $filespec for input";

    our $effdate = scalar <$date>;
    close $date;
    chomp $effdate;
    $effdate =~ s/\r//g;
    return $effdate;

}

sub newest_date {
    require DateTime;
    require DateTime::Format::Strptime;
    state $strp_slashes = DateTime::Format::Strptime->new(
        pattern => '%m/%d/%Y',    # not %D which uses two-digit year
        locale  => 'en_US',
    );
    
    state $strp_dashes = DateTime::Format::Strptime->new(
        pattern => '%Y-%m-%d',    # not %D which uses two-digit year
        locale  => 'en_US',
        );

    my @datestrs = @_;

    my $newest_date;
    foreach my $datestr (@datestrs) {
        
        my $strp = $datestr =~ m{/} ? $strp_slashes : $strp_dashes;

        my $this_date = $strp->parse_datetime($datestr);
        if (not defined $newest_date
            or ( defined $this_date
                and DateTime->compare( $newest_date, $this_date ) == -1 )
          )
        {
            $newest_date = $this_date;
        }
    }

    return if not defined $newest_date;

    return $newest_date;

} ## tidy end: sub newest_date

sub long_date {
    my $date_obj = shift;
    
    unless (defined $date_obj) {
    	print ".";
    }

    return
      $date_obj->month_name
      . $SPACE
      . $date_obj->day . ', '
      . $date_obj->year;

}

sub file_date {
    my $date_obj = shift;
    return $date_obj->ymd('_');
}

#    return
#        $newest_date->month_name
#      . $SPACE
#      . $newest_date->day . ', '
#      . $newest_date->year, $newest_date->ymd('_');
#
#} ## tidy end: sub newest_date

# should probably return object, or allow formatting, or something

1;

__END__

use DateTime;
use DateTime::Format::Strptime;

    my $strp_slashes = DateTime::Format::Strptime->new(
        pattern   => '%D',
        locale => 'en_US',
    );

sub lines_effective_obj {
    my $self = shift;
    my @lines  = @_;

    $self->ensure_loaded('Lines');

    my %datestr_of = $self->all_in_column_key(qw[Lines TimetableDate]);

    my $newest_date;
    foreach my $datestr ( @datestr_of{@lines} ) {
        
        my $this_date = $strp_slashes->new($datestr);
        if ( not defined $newest_date
            or DateTime->compare( $newest_date, $this_date ) == -1 )
        {
            $newest_date = $this_date;
        }
    }
    
    return $newest_date;

} ## tidy end: sub lines_effective

sub lines_effective {
   my $self = shift;
   my $newest_date = $self->lines_effective_obj(@_);
   
   return $newest_date->month_name . $SPACE . 
          $newest_date->day . ', ' .
          $newest_date->year;
 
}

1;
