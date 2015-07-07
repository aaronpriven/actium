# Actium/Sorting/Skeds.pm
# Routines to sort schedule-type objects

# legacy status 4

use 5.016;
use warnings;

package Actium::Sorting::Skeds 0.010;

#use Storable;

use Sub::Exporter -setup => { exports => [qw(skedsort)] };
use Params::Validate;

use Actium::Sorting::Line (qw(byline linekeys));
use Actium::Constants;

use List::Util(qw/min/);

my $required_methods
  = [qw( linedir earliest_timenum sortable_id sortable_id_with_timenum )];

# can take Actium::Sked objects, or Actium::Sked::Timetable objects
# or anything else that can do those methods

sub skedsort {

    validate_pos( @_, ( ( { can => $required_methods } ) x scalar(@_) ) );

    my %earliest_timenum_of;
    my @objs = @_;

    my @objs_with_ids;

    foreach my $obj (@objs) {

        if ( $obj->should_preserve_direction_order ) {
            push @objs_with_ids, { obj => $obj, id => $obj->sortable_id };
        }
        else {
            my $linedir          = $obj->linedir;
            my $earliest_timenum = $obj->earliest_timenum;
            if ( exists $earliest_timenum_of{$linedir} ) {
                $earliest_timenum_of{$linedir}
                  = min( $earliest_timenum_of{$linedir}, $earliest_timenum );
            }
            else {
                $earliest_timenum_of{$linedir} = $earliest_timenum;
            }
            push @objs_with_ids, { obj => $obj };
        }

    }

    foreach my $obj_with_id (@objs_with_ids) {
        next if exists $obj_with_id->{id};
        my $obj     = $obj_with_id->{obj};
        my $linedir = $obj->linedir;
        my $timenum = $earliest_timenum_of{$linedir};
        $obj_with_id->{id} = $obj->sortable_id_with_timenum($timenum);
    }

    @objs_with_ids = sort { $a->{id} cmp $b->{id} } @objs_with_ids;

    return map { $_->{obj} } @objs_with_ids;
} ## tidy end: sub skedsort

1;

__END__
