# Actium/Sked.pm

# the Sked object, containing everything that is a schedule

# Subversion: $Id$

# legacy status 3

package Actium::Sked 0.001;

use 5.012;
use strict;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose::Util::TypeConstraints;

use English '-no_match_vars';

use List::MoreUtils qw<none>;

use Actium::Util(qw<:ALL>);
use Actium::Time(qw<:all>);
use Actium::Sorting qw<sortbyline>;
use Actium::Constants;

use Actium::Types (qw/DirCode HastusDirCode ActiumSkedDir ActiumSkedDays/);

use Actium::Sked::Trip;
use Actium::Sked::Dir;
use Actium::Sked::Days;

use Actium::Term;

###################################
## MOOSE ATTRIBUTES

# comes from AVL, not headways
has 'place4_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        place4s     => 'elements',
        place_count => 'count',
    },
);

# comes from AVL or headways
has 'place8_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { place8s => 'elements', },
);

# from AVL or headways
has [qw<origlinegroup linegroup linedescrip>] => (
    is  => 'rw',
    isa => 'Str',
);

# direction
has 'dir_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'direction',
    is       => 'ro',
    isa      => ActiumSkedDir,
    handles  => {'dircode' => 'dircode ' ,
                 'to_text' => 'as_to_text' },
);

# days
has 'days_obj' => (
    required => 1,
    coerce   => 1,
    init_arg => 'days',
    is       => 'ro',
    isa      => ActiumSkedDays,
    handles  => {
        daycode       => 'daycode',
        schooldaycode => 'schooldaycode',
    }
);

# from AVL or headways, but specific data in trips varies
has 'trip_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Actium::Sked::Trip]',
    default => sub { [] },
    handles => { trips => 'elements', trip => 'get', trip_count => 'count' },
);

# from AVL only

has 'stopid_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { stopids => 'elements', },
);

has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'bare',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { stopplaces => 'elements', },
);

#################################
## METHODS


sub routes {

    # It would be nice to cache this in some way, but getting the Trip object
    # to regenerate the cache each time it's changed is more trouble than
    # it's worth.

    # Trips are kept read-write so that AVL and headways can be merged --
    # would it be better to have them be readonly,
    # and create new sked objects each time?

    my $self = shift;

    my $route_r;
    my %seen_route;

    foreach my $trip ( $self->trips() ) {
        $seen_route{ $trip->routenum() } = 1;
    }

    return sortbyline( keys %seen_route );

} ## tidy end: sub routes

sub has_multiple_routes {
    my $self   = shift;
    my @routes = $self->routes;
    return @routes > 1;
}

sub daysexceptions {

    my $self = shift;

    my %seen_daysexceptions;

    foreach my $trip ( $self->trips() ) {
        $seen_daysexceptions{ $trip->daysexceptions } = 1;
    }

    return sort keys %seen_daysexceptions;

}

sub has_multiple_daysexceptions {
    my $self           = shift;
    my @daysexceptions = $self->daysexceptions;
    return @daysexceptions > 1;
}

sub divide_sked {
    my $self = shift;

    my @routes = $self->routes();

    my %linegroup_of;
    foreach (@routes) {
        $linegroup_of{$_} = ( $LINES_TO_COMBINE{$_} || $_ );

        #        $linegroup_of{$_} = ( $_ );
    }

    my %linegroups;
    $linegroups{$_} = 1 foreach ( values %linegroup_of );
    my @linegroups = keys %linegroups;

    if ( scalar(@linegroups) == 1 ) {  # there's just one linegroup, return self
        $self->set_linegroup( $routes[0] );

        if ( $linegroups{'97'} ) {
            print '';                  # DEBUG - breakpoint
        }

        $self->delete_blank_columns;

        # override Scheduling's linegroup with the first route
        return $self;
    }

    # More than one linegroup! Split apart

    my ( %trips_of, @newskeds );

    # collect trips for each one in %trips_of
    foreach my $trip ( $self->trips ) {
        my $linegroup = $linegroup_of{ $trip->routenum };
        push @{ $trips_of{$linegroup} }, $trip;
    }

    foreach my $linegroup (@linegroups) {

        my %value_of;

        # collect all other attribute values in %values_of
        # This is a really primitive clone routine and might arguably
        # be better replaced by something based on MooseX::Clone or some other
        # "real" deep clone routine.

        foreach my $attribute ( $self->meta->get_all_attributes ) {

            # meta-objects! woohoo! screw you, Mouse!

            my $attrname = $attribute->name;
            next if $attrname eq 'trip_r' or $attrname eq 'linegroup';

            my $value = $self->$attrname;
            if ( ref($value) eq 'ARRAY' ) {
                $value = [ @{$value} ];
            }
            elsif ( ref($value) eq 'HASH' ) {
                $value = { %{$value} };
            }    # purely speculative as there are no hash attributes right now

            # use of "ref" rather than "reftype" is intentional here. We don't
            # want to clone objects this way.

            $value_of{$attrname} = $value;
        }    ## <perltidy> end foreach my $attribute ( $self...)

        my $newsked = Actium::Sked->new(
            trip_r    => $trips_of{$linegroup},
            linegroup => $linegroup,
            %value_of,
        );

        $newsked->delete_blank_columns;

        push @newskeds, $newsked;

    }    ## <perltidy> end foreach my $linegroup (@linegroups)

    return @newskeds;

}    ## <perltidy> end sub divide_sked

sub placetime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->placetime_count - 1 ) {
            push @{ $columns[$i] }, $trip->placetime($i);
        }
    }

    return @columns;
}

sub stoptime_columns {
    my $self = shift;
    my @columns;
    foreach my $trip ( $self->trips ) {
        foreach my $i ( 0 .. $trip->stoptime_count - 1 ) {
            push @{ $columns[$i] }, $trip->stoptime($i);
        }
    }

    return @columns;
}

sub delete_blank_columns {
    my $self = shift;

    my @columns_to_delete;

    if ( not $self->trip(0)->placetimes_are_empty ) {

        my @columns_of_times = $self->placetime_columns;
        for my $i ( reverse( 0 .. $#columns_of_times ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @columns_to_delete, $i;
                $self->delete_place8($i) if ( not $self->place8s_are_empty );
                $self->delete_place4($i) if ( not $self->place4s_are_empty );

            }
        }

        foreach my $trip ( $self->trips ) {
            foreach my $i (@columns_to_delete) {
                $trip->delete_placetime($i);
            }
        }
    }

    if ( not $self->trip(0)->stoptimes_are_empty ) {

        my @columns_of_times = $self->stoptime_columns;
        for my $i ( reverse( 0 .. $#columns_of_times ) ) {
            if ( none { defined($_) } @{ $columns_of_times[$i] } ) {
                push @columns_to_delete, $i;
                $self->delete_stopid($i)    if ( $self->stopid_r );
                $self->delete_stopplace($i) if ( $self->stopplace_r );
            }
        }

        foreach my $trip ( $self->trips ) {
            foreach my $i (@columns_to_delete) {
                $trip->delete_stoptime($i);
            }
        }

    }

    return;

}    ## <perltidy> end sub delete_blank_columns

sub id {
    my $self = shift;
    return $self->skedid;
}

sub skedid {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->dircode, $self->daycode ) );
}

sub dump {
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper::Dumper($self);
}

with 'Actium::Sked::Prehistoric';
# allows prehistoric skeds files to be read and written.

1;

__END__

