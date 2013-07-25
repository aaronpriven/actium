# Actium/Sorting/Skeds.pm
# Routines to sort schedule-type objects

# Subversion: $Id$

# legacy status 4

use 5.016;
use warnings;

package Actium::Sorting::Skeds 0.001;

#use Storable;

use Sub::Exporter -setup => { exports => [qw(skedsort)] };
use Params::Validate;

use Actium::Sorting::Line (qw(byline linekeys));
use Actium::Constants;

my $required_methods = [qw( daycode earliest_timenum dircode linegroup )];

# can take Actium::Sked objects, or Actium::Sked::Timetable objects
# or anything else that can do those methods

sub skedsort {

    validate_pos( @_, ( ( { can => $required_methods } ) x scalar(@_) ) );

    my @objs_with_values;
    foreach my $obj (@_) {
        push @objs_with_values,
          { obj          => $obj,
            dircode      => $obj->dircode,
            daycode      => $obj->daycode,
            timenum      => $obj->earliest_timenum,
            linegroupkey => linekeys( $obj->linegroup ),
          };

    }

    @objs_with_values = sort _dircode_ordering (@objs_with_values);

    my %idxs_of_lg;

    foreach my $i ( 0 .. @objs_with_values ) {
        my $linegroupkey = $objs_with_values[$i]{linegroupkey};
        push @{ $idxs_of_lg{$linegroupkey} }, $i;
    }

    foreach my $linegroupkey ( keys %idxs_of_lg ) {
        my @idxs = @{ $idxs_of_lg{$linegroupkey} };

        if ( $objs_with_values[ $idxs[0] ]{obj}
            ->should_preserve_direction_order )
        {
            next;
        }
        
        # add stuff here
        
        

    }

    return map { $_->{obj} } @objs_with_values;

} ## tidy end: sub skedsort

sub _dircode_ordering {
    return
         $a->{linegroupkey} cmp $b->{linegroupkey}
      || $a->{daycode} cmp $b->{daycode}
      || $a->{dircode} cmp $b->{dircode};
}

sub _timenum_ordering {
    return
         $a->{linegroupkey} cmp $b->{linegroupkey}
      || $a->{daycode} cmp $b->{daycode}
      || $a->{timenum} <=> $b->{timenum}
      || $a->{dircode} cmp $b->{dircode};

}

1;

__END__
