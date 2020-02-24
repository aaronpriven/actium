package Octium::Cmd::AVL2StopLists 0.014;

use Octium;
# avl2stoplists - see POD documentation below

use sort ('stable');

# add the current program directory to list of files to include

use Carp;          ### DEP ###
use Storable();    ### DEP ###

use Octium::Set('ordered_union');
use Octium::DaysDirections ('dir_of_hasi');

# don't buffer terminal output

sub HELP {

    my $helptext = <<'EOF';
avl2stoplists reads the data written by readavl and turns it into lists
of stops in order for each pattern and each route. These routes are stored in
the "slists" directory in the signup directory.
EOF

    print $helptext;
    return;
}

sub OPTIONS {
    return (qw/actiumdb signup/);
}

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $signup = $env->signup;
    chdir $signup->path();

    # retrieve data

    my $slistsfolder = $signup->subfolder('slists');
    my $patfolder    = $slistsfolder->subfolder('pat');
    my $linefolder   = $slistsfolder->subfolder('line');

    my %pat;
    my %tps;

    my %stops;

    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    {    # scoping
# the reason to do this is to release the %avldata structure, so Affrus
# (or, presumably, another IDE)
# doesn't have to display it when it's not being used. Of course it saves memory, too

        my $avldata_r = $signup->retrieve('avl.storable');

        %pat = %{ $avldata_r->{PAT} };

    }

    my $count = 0;

    my %liststomerge;

  PAT:
    foreach my $key ( keys %pat ) {

        my $dir = $pat{$key}{DirectionValue};
        next unless dir_of_hasi($dir);
        $dir = dir_of_hasi($dir);

        my $route = $pat{$key}{Route};

        my $filekey;
        ( $filekey = $key ) =~ s/$KEY_SEPARATOR/-$dir-/g;

        open my $fh, '>:utf8', "slists/pat/$filekey.txt"
          or die "Cannot open slists/pat/$filekey.txt for output";

        printf "%13s", $filekey;
        $count++;
        print "\n" unless $count % 6;

        print $fh join( "\t",
            $route, $dir, $pat{$key}{Identifier},
            $pat{$key}{Via}, $pat{$key}{ViaDescription} );
        print $fh "\n";

        my @thesestops;

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};

            push @thesestops, $stopid;

            print $fh $stopid, "\t",
              $stops{$stopid}{c_description_full} // $EMPTY, "\n";
        }

        push @{ $liststomerge{$route}{$dir} }, \@thesestops;

        close $fh;

    } ## tidy end: PAT: foreach my $key ( keys %pat)

    print "\n\n";

    $count = 0;

    my %stops_of_line;

    foreach my $route ( keys %liststomerge ) {
        foreach my $dir ( keys %{ $liststomerge{$route} } ) {

            printf "%13s", "$route-$dir";
            $count++;
            print "\n" unless $count % 6;

            my @union = @{ ordered_union( @{ $liststomerge{$route}{$dir} } ) };
            $stops_of_line{"$route-$dir"} = \@union;

            {
                open my $fh, '>:utf8', "slists/line/$route-$dir.txt"
                  or die "Cannot open slists/line/$route-$dir.txt for output";
                print $fh u::jointab( $route, $dir ), "\n";
                foreach (@union) {

                    my $desc = $stops{$_}{c_description_full} // $EMPTY;
                    #utf8::decode($desc);

                    print $fh "$_\t$desc\n";
               #print $fh u::jointab($_, $stops{$_}{c_description_full}) , "\n";
                }
                close $fh;
            }

        } ## tidy end: foreach my $dir ( keys %{ $liststomerge...})
    } ## tidy end: foreach my $route ( keys %liststomerge)

    print "\n\n";

    Storable::nstore( \%stops_of_line, "slists/line.storable" );

} ## tidy end: sub START

1;

=head1 NAME

avl2stoplists - Make stop lists by pattern and route from AVL files.

=head1 DESCRIPTION

avl2stoplists reads the data written by readavl and turns it into lists
of  stops by pattern and by route.  First it produces a list for each
pattern  (files in the form <route>-<direction>-<patternnum>.txt) and
then one for  each route (in the form <route>-<direction>.txt. Lists
for each pattern are merged using the Algorithm::Diff routine.

=head1 AUTHOR

Aaron Priven

=cut

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

