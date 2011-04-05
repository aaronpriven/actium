# /Actium/OrderStopsByRoute.pm

# Takes a list of stops and order it so that people can drive down a
# particular bus route and hit as many stops as possible.

# Subversion: $Id$

use 5.012;
use warnings;

use sort ('stable');

# add the current program directory to list of files to include

use Carp;
use Storable();

use Actium::Sorting(qw<byline>);
use Actium::Constants;

use Actium::Options;
use Actium::Signup;

sub order_stops_by_route {
    my %linedirs_of_stop = %{ +shift };

    # keys - stop IDs, values - arrayref of linee/dir combinations

    my $slistsdir = Actium::Signup->new('slists');

    # retrieve data
    my $stops_r = $slistsdir->retrieve('line.storable')
      or die "Can't open line.storable file: $!";
    my %stops_of_linedir = %{$stops_r};

    # load the stops that are on the list

    # From the %stops_of_linedir list, eliminate all stops
    # that are not on the list of stops to put in order
    while ( my ( $linedir, $stops_r ) = each %stops_of_linedir ) {
        my @newstops;
        foreach my $stop ( @{$stops_r} ) {
            push @newstops, $stop if $linedirs_of_stop{$stop};
        }
        $stops_of_linedir{$linedir} = \@newstops;
    }

    my @results;

    while ( scalar keys %stops_of_linedir ) {

        my $max_linedir = _get_max_linedir(\%stops_of_linedir);
        # $max_linedir is now the line/dir combination with the most stops
        # (excluding 600s)

        my @stops = @{ $stops_of_linedir{$max_linedir} };
        # and @stops is the current list of stops

        last unless @stops;

        push @results, [ $max_linedir, @stops ];

        # Save the one with the most stops

        delete $stops_of_linedir{$max_linedir};
        delete $linedirs_of_stop{$_} foreach @stops;

        # delete all stops in the subsequent series that have been done so far.

        my %seen_stop;
        $seen_stop{$_} = 1 foreach @stops;

        while ( my ( $linedir, $stops_r ) = each %stops_of_linedir ) {
            my @newstops;
            foreach my $stop ( @{$stops_r} ) {
                push @newstops, $stop unless $seen_stop{$stop};
            }
            if (@newstops) {
                $stops_of_linedir{$linedir} = \@newstops;
            }
            else {
                delete $stops_of_linedir{$linedir};
            }
        }

    }
    return @results;
}

sub _get_max_linedir {

    my $stops_of_r = shift;

    my $max_linedir = (
        sort {
                 ( $a =~ /^6\d\d/ <=> $b =~ /^6\d\d/ )
              or ( @{ $stops_of_r->{$b} } <=> @{ $stops_of_r->{$a} } )
              or byline( $a, $b )
          } keys %{$stops_of_r}
    )[0];

    return $max_linedir;
}

1;

__END__

