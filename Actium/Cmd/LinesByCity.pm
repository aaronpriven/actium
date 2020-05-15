#/Actium/Cmd/LinesByCity.pm

package Actium::Cmd::LinesByCity 0.010;

use Actium::Preamble;
use Actium::Sorting::Line         (qw(sortbyline));
use Actium::Cmd::Config::ActiumFM ('actiumdb');

sub OPTIONS {
    my ($class, $env) = @_;
    return (Actium::Cmd::Config::ActiumFM::OPTIONS($env) );
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);

    my (@stops);

    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                array  => \@stops,
                fields => [ qw[ h_stp_511_id p_active p_lines c_city ] ],
            },
        }
    );

    my %lines_of;
    my %cities_of;

    foreach my $stop (@stops) {

        next unless $stop->{p_active};

        my @routes = split( $SPACE, $stop->{p_lines} );
        foreach (@routes) {

            next if /NULL/s;
            my $city = $stop->{c_city};
            $city =~ s/^\s+//s;
            $city =~ s/\s+$//s;
            $lines_of{$city}{$_}++;
            $cities_of{$_}{$city}++;
        }
    }

    my @cities = sort keys %lines_of;

    my @lines = sortbyline keys %cities_of;

    foreach my $line (@lines) {
        print "\t$line";
    }
    print "\n";

    foreach my $city (@cities) {
        print "$city:";
        foreach my $line (@lines) {
            my $x = $lines_of{$city}{$line} ? 'X' : $EMPTY_STR;
            print "\t$x";
        }

        print "\n";

    }

    return;
} ## tidy end: sub START

1;
