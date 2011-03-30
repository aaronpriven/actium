# Subversion: $Id$
# make lists of stops by driving order

# This needs refactoring badly.
# Currently though it is still the version being used.

use warnings;
use 5.012;

package Actium::DrivingOrder;

our $VERSION = '0.001'; $VERSION = eval $VERSION;    ## no critic (StringyEval)

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use Storable;
use Carp;
use List::Util ('max');

use Actium::Constants;
use Actium::Signup;
use Actium::Sorting(qw/byline sortbyline/);
use English ('-no_match_vars');
use Actium::Options(qw(option add_option));

add_option( 'descriptions', 'Adds descriptions to the output file' );

sub HELP {

    my $helptext = <<'EOF';
slists2bagorder makes the order for bags (that is, listing stops by route in order
of traversing that route) from the line.storable file.
EOF

    say $helptext or die q{Can't open STDOUT for writing};

    return;

}

sub START {

    my ( $infile, $outfile ) = @ARGV;

    die 'No input file specified'  unless $infile;
    die 'No output file specified' unless $outfile;

    open my $in, '<', $infile or die "Can't open $infile: $OS_ERROR";
    my %stop_used;
    while (<$in>) {
        chomp;
        my ( $stop, $rest ) = split( /\t/s, $_ );
        $stop_used{$stop} = $rest;
    }
    close $in or die $OS_ERROR;

    my %ordered_stops_of = make_ordering( \%stop_used );

    open my $baglist, '>', $outfile or die $OS_ERROR;

    if ( option('descriptions') ) {

        my $signup   = Actium::Signup->new;
        my $stopsobj = $signup->mergeread('Stops.csv');

        foreach my $linedir ( sortbyline keys %ordered_stops_of ) {
            say {$baglist} ( "*** $linedir ***");
            foreach my $stop ( @{ $ordered_stops_of{$linedir} } ) {
                my @rows = $stopsobj->rows_where('PhoneID' , $stop); 
                my $hashrow = $stopsobj->hashrow($rows[0]);
                say {$baglist} "$stop\t$hashrow->{DescriptionCityF}"
                  or die "Can't print to $outfile: $OS_ERROR";
            }

        }

    }

    else {

        foreach my $linedir ( sortbyline keys %ordered_stops_of ) {
            say {$baglist}
              join( "\t", $linedir, @{ $ordered_stops_of{$linedir} } )
              or die "Can't print to $outfile: $OS_ERROR";
        }
    }
    close $baglist or die $OS_ERROR;

    return;

} ## tidy end: sub drivingorder_START

sub make_ordering {

    my $stop_used_r = shift;

    my $slistsdir = Actium::Signup->new('slists');

    # retrieve data
    my $stops_of_linedir_r = $slistsdir->retrieve('line.storable')
      or die $OS_ERROR;

    # delete bad lines like NC and LC
    foreach my $linedir ( keys %{$stops_of_linedir_r} ) {
        if ( $linedir =~ /\A399/s ) {
            delete $stops_of_linedir_r->{$linedir};
        }
    }

    # eliminate all stops that are not in the input
    while ( my ( $linedir, $stops_r ) = each %{$stops_of_linedir_r} ) {
        my @newstops;
        foreach my $stop ( @{$stops_r} ) {
            push @newstops, $stop if $stop_used_r->{$stop};
        }
        $stops_of_linedir_r->{$linedir} = \@newstops;
    }

    # Now %stops_of contains all stops in every line.

    my %ordered_stops_of;

    while ( scalar keys %{$stops_of_linedir_r} ) {

        my @list = keys %{$stops_of_linedir_r};

        my $max_linedir = (
            sort {
                ( $a =~ /^6\d\d/s <=> $b =~ /^6\d\d/s )
                  or (
                    scalar @{ $stops_of_linedir_r->{$b} } <=>
                    scalar @{ $stops_of_linedir_r->{$a} } )
                  or byline( $a, $b )
              } keys %{$stops_of_linedir_r}
        )[0];

        my @stops = @{ $stops_of_linedir_r->{$max_linedir} };

        last unless scalar @stops;

        $ordered_stops_of{$max_linedir} = \@stops;

        delete $stops_of_linedir_r->{$max_linedir};

        delete $stop_used_r->{$_} foreach @stops;

      # we've printed the one with the most stops.
      # now delete all stops in the subsequent series that have been done so far

        my %seen_stop;
        $seen_stop{$_} = 1 foreach @stops;

        while ( my ( $linedir, $these_stops_r ) = each %{$stops_of_linedir_r} )
        {
            my @newstops;
            foreach my $stop ( @{$these_stops_r} ) {
                push @newstops, $stop unless $seen_stop{$stop};
            }
            if (@newstops) {
                $stops_of_linedir_r->{$linedir} = \@newstops;
            }
            else {
                delete $stops_of_linedir_r->{$linedir};
            }
        }

    } ## tidy end: while ( scalar keys %{$stops_of_linedir_r...})

    if ( scalar keys %{$stop_used_r} ) {
        $ordered_stops_of{_UNUSED} = [ keys %{$stop_used_r} ];
    }

    return %ordered_stops_of;

} ## tidy end: sub make_ordering

1;
