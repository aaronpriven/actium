# Actium/O/Files/ActiumDB.pm

# Class holding routines related to the Actium database 
# (the FileMaker database used by Actium users), exported. 
# in FMPXMLResult form.

# Subversion: $Id$

# Legacy stage 4

# will probably never be used, because replaced by
# Actium::O::Files::ActiumFM

package Actium::O::Files::ActiumDB;

use warnings;
use 5.016;

use Moose;
use MooseX::StrictConstructor;

use namespace::autoclean;

extends 'Actium::O::Files::FMPXMLResult';

use Actium::Constants;

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

__PACKAGE__->meta->make_immutable; ## no critic (RequireExplicitInclusion)
