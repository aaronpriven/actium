package Octium::Cmd::AVL2PatDest 0.011;

use Actium;
use Octium;

use Storable();    ### DEP ###
use List::Util('uniq');

use Octium::Set('ordered_union');

sub HELP {

    my $helptext = <<'EOF';
avl2patdest gives the destination of the last timepoint 
of each pattern
EOF

    say $helptext;
    return;
}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return qw/actiumdb signup/;
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $signup = $env->signup;

    chdir $signup->path();

    my %stoplist = ();

    my (%pat);

    {    # scoping
        my $avldata_r = $signup->retrieve('avl.storable');
        %pat = %{ $avldata_r->{PAT} };
    }

    my %places;

    $actiumdb->load_tables(
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
        }
    );

    my %dests_of_ld;

    open my $nbdest, ">", "pattern-destinations.txt";

    say $nbdest "Route\tPattern\tDirection\tDestination\tvdc_id\tplace";

    my @results;
    my (%seen);

    foreach my $key ( keys %pat ) {

        # GET DATA FROM PATTERN

        next unless $pat{$key}{IsInService};

        my $pat   = $pat{$key}{Identifier};
        my $route = $pat{$key}{Route};
        my $dir   = $pat{$key}{DirectionValue};
        my $veh   = $pat{$key}{VehicleDisplay};

        my $lasttp = $pat{$key}{TPS}[-1]{Place};

        $lasttp =~ s/-[21AD]$//;

        my $dest = $places{$lasttp}{c_destination};

        my $city = $places{$lasttp}{c_city};

        $dest ||= $lasttp;

        # SAVE FOR RESULTS

        $seen{$lasttp} = $dest;

        push @{ $dests_of_ld{ $route . "\t" . $dir } }, $dest;

        for ($dir) {
            if ( $_ == 8 ) {
                $dest = "Clockwise to $dest";
                next;
            }
            if ( $_ == 9 ) {
                $dest = "Counterclockwise to $dest";
                next;
            }
            if ( $_ == 14 ) {
                $dest = "A Loop to $dest";
                next;
            }
            if ( $_ == 15 ) {
                $dest = "B Loop to $dest";
                next;
            }

            $dest = "To $dest";

        }    ## tidy end: for ($dir)

        push @results,
          { ROUTE  => $route,
            PAT    => $pat,
            DIR    => $dir,
            DEST   => $dest,
            LASTTP => $lasttp,
            VEH    => $veh,
          };

    }    ## tidy end: foreach my $key ( keys %pat)

    foreach (
        sort {
                 Actium::byline( $a->{ROUTE}, $b->{ROUTE} )
              or $a->{PAT} <=> $b->{PAT}
              or $a->{DIR} <=> $b->{DIR}
        } @results
      )
    {

        say $nbdest join( "\t",
            $_->{ROUTE}, $_->{PAT}, $_->{DIR},
            $_->{DEST},  $_->{VEH}, $_->{LASTTP} );

    }

    close $nbdest;

    open my $joineddest, ">", "pattern-destinations-joined.txt";
    say $joineddest "line\tdir\tdestination";

    foreach my $ld ( Actium::sortbyline( keys %dests_of_ld ) ) {

        my @dests = uniq( $dests_of_ld{$ld}->@* );

        say $joineddest $ld, "\tTo ", join( " / ", @dests );
        # eventually might have to deal with clockwise / counterclockwise

    }

    close $joineddest;

    my %text_of_veh;

    open my $new_codebook, '>', 'new-codebook.txt'
      or die "Can't open new-codebook.txt";

    say $new_codebook "vdc_id\tdestination";

    use DDP;
    foreach ( sort { $a->{VEH} <=> $b->{VEH} } @results ) {

        my $veh  = $_->{VEH};
        my $dest = $_->{DEST};
        if ( exists $text_of_veh{$veh} ) {

            if ( $text_of_veh{$veh} ne $dest ) {
                warn "\nDuplicate! Veh $veh with destination $dest. Using  "
                  . $text_of_veh{$veh} . "\n";
            }
            next;
        }

        say $new_codebook join( "\t", $veh, $dest );
        $text_of_veh{$veh} = $dest;

    }

    close $new_codebook;

    #foreach ( sort keys %seen ) {
    #    say "$_\t$seen{$_}";
    #}

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

