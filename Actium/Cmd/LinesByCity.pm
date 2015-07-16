#/Actium/Cmd/LinesByCity.pm

package Actium::Cmd::LinesByCity 0.010;

use Actium::Preamble;
use Actium::Files::FileMaker_ODBC (qw[load_tables]);
use Actium::Sorting::Line         (qw(sortbyline));
use Actium::O::Folders::Signup;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

#my $signupdir = Actium::O::Folders::Signup->new();
#chdir $signupdir->path();
#my $signup = $signupdir->signup;

# open and load files

# read in FileMaker Pro data into variables in package main

sub HELP { say 'Help not implemented.'; return; }

sub OPTIONS {
    return Actium::Cmd::Config::ActiumFM::OPTIONS();
}

sub START {

    my ( $class, %params ) = @_;
    my $actiumdb = actiumdb(%params);

    my (@stops);

    load_tables(
        actiumdb => $actiumdb,
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
