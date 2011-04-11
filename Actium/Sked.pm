# Actium/Sked.pm

# the Sked object, containing everything that is a schedule

# Subversion: $Id$

# legacy status 3

package Actium::Sked;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;

use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;
use Moose;
use Moose::Util::TypeConstraints;

use List::MoreUtils qw<uniq none>;
use Actium::Util(qw<:ALL>);
use Actium::AttributeHandlers qw<:all>;

use Actium::Time(qw<:all>);

use Actium::Sorting qw<sortbyline>;

use Actium::Constants;

# comes from AVL, not headways
has 'place4_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { arrayhandles('place4') },
);

# comes from AVL or headways
has 'place8_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { arrayhandles('place8') },
);

# from AVL or headways
has [qw/origlinegroup linegroup linedescrip direction days/] => (
    is  => 'rw',
    isa => 'Str',
);

sub routes {

    # It would be nice to cache this in some way, but getting the Trip object
    # to regenerate the cache each time it's changed is more trouble than
    # it's worth.

    my $self = shift;

    my $route_r;
    my %seen_route;

    foreach my $trip ( $self->trips() ) {
        $seen_route{ $trip->routenum() } = 1;
    }

    return sortbyline( keys %seen_route );

}

# from AVL or headways, but specific data in trips varies
has 'trip_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Actium::Trip]',
    default => sub { [] },
    handles => { arrayhandles('trip') },

    #handles => { 'add_trip' => 'push' , 'tripelems' => 'elements'},
);

# from AVL only

has 'stopid_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { arrayhandles('stopid') },
);

has 'stopplace_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { arrayhandles('stopplace') },
);

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
        } ## <perltidy> end foreach my $attribute ( $self...)

        my $newsked = Actium::Sked->new(
            trip_r    => $trips_of{$linegroup},
            linegroup => $linegroup,
            %value_of,
        );

        $newsked->delete_blank_columns;

        push @newskeds, $newsked;

    } ## <perltidy> end foreach my $linegroup (@linegroups)

    return @newskeds;

} ## <perltidy> end sub divide_sked

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

} ## <perltidy> end sub delete_blank_columns

sub id {
    my $self = shift;
    return $self->skedid;
}

sub skedid {
    my $self = shift;
    my $linegroup = $self->linegroup || $self->oldlinegroup;
    return ( join( '_', $linegroup, $self->direction, $self->days ) );
}

sub dump {
    my $self = shift;
    require Data::Dumper;
    return Data::Dumper::Dumper($self);
}

sub prehistoric_skedsfile {

    my $self = shift;

    my $outdata;
    open( my $out, '>', \$outdata );

    say $out $self->id;

    say $out "Note Definitions:\t";

    my @place9s;
    my %place9s_seen;

    foreach ( $self->place8s ) {
        my $place9 = $_;
        substr( $place9, 4, 0, $SPACE );
        $place9 =~ s/  / /g;

        if ( $place9s_seen{$place9} ) {

            $place9s_seen{$place9}++;
            $place9 .= '=' . $place9s_seen{$place9};
        }
        else {
            $place9s_seen{$place9} = 1;
        }

        push @place9s, $place9;
    }

    say $out jt( 'SPEC DAYS', 'NOTE', 'VT', 'RTE NUM', @place9s );

    my $timesub = timestr_sub( SEPARATOR => $EMPTY_STR );

    foreach my $trip ( $self->trips ) {
        my $times = $timesub->( $trip->placetimes );

        say $out jt( $trip->exceptions, $EMPTY_STR, $EMPTY_STR, $trip->routenum,
            $times );
    }

    close $out;

    return $outdata;

} ## <perltidy> end sub prehistoric_skedsfile

#sub dump {
#    my $self = shift;
#
#    my $dumpdata;
#
#    open( my $dump, '>', \$dumpdata );
#
#    say $dump "origlinegroup\t", $self->origlinegroup();
#    say $dump "linegroup\t",     $self->linegroup();
#    say $dump "linedescrip\t",   $self->linedescrip();
#    say $dump "direction\t",     $self->direction();
#    say $dump "place4\t",        jt( $self->place4s() );
#    say $dump "place8\t",        jt( $self->place8s() );
#    say $dump "stopid\t",        jt( $self->stopids() );
#    say $dump "stopplace\t",     jt( $self->stopplaces() );
#    say $dump "trips:\n";
#
#    foreach my $trip ( $self->trips() ) {
#        say $dump $trip->dump();
#    }
#
#    close $dump;
#
#    return $dumpdata;
#
#} ## <perltidy> end sub dump

1;

__END__

