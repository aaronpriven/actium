package Actium::Cmd::SchoolTrips 0.012;

use Actium;

use Actium::O::Sked::Collection;
use List::MoreUtils;
use Actium::Time;

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $collection
      = Actium::O::Sked::Collection->load_storable( collection => 'received' );

    my @skeds = $collection->skeds;

    my %place_cache = $actiumdb->place_cache;

    say "Line\tBlock\tFrom\tDep\tTo\tArr";

    foreach my $sked (@skeds) {
        my $linegroup = $sked->linegroup;
        next unless $linegroup =~ /^6\d\d/;

        my @places = $sked->place4s;

        my @trips = $sked->trips;
        foreach my $trip (@trips) {

            my @blocks;

            my @mergedtrips = $trip->mergedtrips;
            if (@mergedtrips) {
                foreach my $mergedtrip (@mergedtrips) {
                    push @blocks, $mergedtrip->blockid;
                }
            }
            else {
                push @blocks, $trip->blockid;
            }

            my @placetimes = $trip->placetimes;

            my @indices = (
                ( Actium::firstidx {defined} @placetimes ),
                ( List::MoreUtils::lastidx {defined} @placetimes )
            );

            my @theplaces = map { $places[$_] } @indices;
            my @thetimes
              = map { Actium::Time->from_num( $placetimes[$_] )->ap } @indices;

            foreach my $block (@blocks) {

                my $from = $place_cache{ $theplaces[0] }{c_description};
                my $to   = $place_cache{ $theplaces[1] }{c_description};
                say join( "\t",
                    $linegroup, $block, $from,
                    $thetimes[0], $to, $thetimes[1], );

            }

            #say "$linegroup\t", $places[$first], "\t", $placetimes[$first],
            #  "\t", $places[$last], "\t", $placetimes[$last], "\t",

        }    ## tidy end: foreach my $trip (@trips)

    }    ## tidy end: foreach my $sked (@skeds)

}    ## tidy end: sub START

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

