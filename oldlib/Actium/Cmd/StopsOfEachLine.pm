package Actium::Cmd::StopsOfEachLine 0.011;

use Actium;
use Storable();    ### DEP ###
use Actium::Sorting::Line (qw<sortbyline>);

sub HELP {

    my $helptext = <<'EOF';
avl2stops_of_each_line reads the data written by readavl and turns it into a 
list of lines with the number of stops. It is saved in the file 
"stops_of_each_line.txt" in the directory for that signup.
EOF

    say $helptext;

    return;

}

sub OPTIONS {
    return 'signup';
}

sub START {
    my ( $class, $env ) = @_;
    my $signup = $env->signup;

    chdir $signup->folder->stringify();

    # retrieve data

    my %pat;

    {    # scoping
        my $avldata_r = $signup->file('avl.storable')->retreive;
        %pat = %{ $avldata_r->{PAT} };
    }

    my %seen_stops_of;

  PAT:
    foreach my $key ( keys %pat ) {

        next unless $pat{$key}{IsInService};

        my $route = $pat{$key}{Route};

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};

            $seen_stops_of{$route}{$stopid} = 1;

        }

    }

    open my $stopsfh, '>', 'stops_of_each_line.txt' or die "$!";

    say $stopsfh "Route\tStops\tDecals\tInventory\tPer set";

    foreach my $route ( sortbyline keys %seen_stops_of ) {

        next if ( u::in( $route, qw/BSD BSH BSN 399 51S/ ) );

        my $numstops = scalar keys %{ $seen_stops_of{$route} };

        my $numdecals = 2 * $numstops;

        print $stopsfh "$route\t$numstops\t$numdecals\t";

        my $threshold = u::ceil( $numdecals * .02 ) * 10;    #
             # 20%, rounded up to a multiple of ten

        $threshold = 30 if $threshold < 30;

        my $perset = $threshold / 5;

        say $stopsfh "$threshold\t$perset";

    }    ## tidy end: foreach my $route ( sortbyline...)

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

