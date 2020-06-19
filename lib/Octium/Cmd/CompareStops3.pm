package Octium::Cmd::CompareStops3 0.011;

use Actium;
use Octium;

use Storable();    ### DEP ###
use Octium::Set('ordered_union');
use Octium::DaysDirections (':all');
use Octium::Folders::Signup;
use Algorithm::Diff('sdiff');    ### DEP ###
use List::Compare;

sub HELP {

    my $helptext = <<'EOF';

comparestops3 <line> [<line>] ...

comparestops reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.
EOF

    print $helptext;
    return;
}

sub OPTIONS {
    return (qw/actiumdb signup/);
}

my ( %changes, %oldstoplists, %stops );

sub START {

    my $actiumdb = env->actiumdb;

    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    my $signup = env->signup;
    my $base   = $signup->base;
    my @args   = env->argv;
    die "must specify two signups" unless @args == 2;

    my @signupnames = env->argv;

    my @signups
      = map { Octium::Folders::Signup::->new( base => $base, signup => $_ ) }
      @signupnames;
    push @signups,     $signup;
    push @signupnames, $signup->signup;

    chdir $signup->path;

    my $comparedir = $signup->subfolder('compare');

    my %stoplists_of;
    my %is_a_stopid;

    foreach my $signup_to_test (@signups) {
        my %stoplists = assemble_stoplists($signup_to_test);
        $is_a_stopid{$_} = 1 foreach keys %stoplists;
        $stoplists_of{ $signup_to_test->signup } = \%stoplists;
    }

    my $filename = 'comparestops3.txt';

    open my $out, '>:utf8', "compare/$filename" or die $OS_ERROR;
    # done here so as to make sure the file is saved in the *new*
    # signup directory

    say $out join( "\t", 'StopID', 'Stop Description', @signupnames );

    my @stopids = sort keys %is_a_stopid;

  STOPID:
    foreach my $stopid (@stopids) {
        my $desc = $stops{$stopid}{c_description_full};
        next if dummy($desc);

        my @routes
          = map { [ sort keys $stoplists_of{$_}{$stopid}{Routes}->%* ] }
          @signupnames;
        my $lcm = List::Compare->new(@routes);
        next STOPID unless $lcm->get_nonintersection;
        # unless there's some differenece skip this

        my @routestrs = map { join( " ", @$_ ) } @routes;
        say $out join( "\t", $stopid, $desc, @routestrs );

    }    # STOPID

}

sub dummy {
    local $_ = shift;
    return 1 if ( /^Virtual/ or /^Dummy/ );
    #return 1 if /San Francisco Terminal/;
    #return 1 if /Transbay Temp Terminal/;
    return;
}

sub output_stops {
    my $desc = shift;
    my $fh   = shift;
    my $type = shift;

    return unless $changes{$type};

    my %thesestops = %{ $changes{$type} };

    foreach my $stopid ( sort keys %thesestops ) {
        my $description = $oldstoplists{$stopid}{Description};
        next if dummy($description);
        print $fh "$desc\t", $stopid, "\t", $oldstoplists{$stopid}{Description};

        if ( exists $changes{$type}{$stopid}{ADDED} ) {
            my @added
              = sort Actium::byline @{ $changes{$type}{$stopid}{ADDED} };
            print $fh "\t", '"', join( ' ', @added ), '"';
        }
        else {
            print $fh "\t";
        }

        if ( exists $changes{$type}{$stopid}{REMOVED} ) {
            my @removed
              = sort Actium::byline @{ $changes{$type}{$stopid}{REMOVED} };
            print $fh "\t", '"', join( ' ', @removed ), '"';
        }
        else {
            print $fh "\t";
        }

        if ( exists $changes{$type}{$stopid}{UNCHANGED} ) {
            my @unchanged
              = sort Actium::byline @{ $changes{$type}{$stopid}{UNCHANGED} };
            print $fh "\t", '"', join( ' ', @unchanged ), '"';
        }

        print $fh "\n";

    }

    return;

}

sub assemble_stoplists {

    my $signup  = shift;
    my $reverse = pop;

    my %stoplist = ();

    my %skipped;
    $skipped{$_} = 1 foreach @_;

    my (%pat);

    {    # scoping
         # the reason to do this is to release the %avldata structure, so Affrus
         # (or, presumably, another IDE)
         # doesn't have to display it when it's not being used. Of course it saves memory, too

        my $avldata_r = $signup->retrieve('avl.storable');

        %pat = %{ $avldata_r->{PAT} };

    }

  PAT:
    foreach my $key ( keys %pat ) {

        my $dir = $pat{$key}{DirectionValue};
        next unless dir_of_hasi($dir);
        $dir = dir_of_hasi($dir);

        my $route = $pat{$key}{Route};

        #next if $route eq 'BSH' or $route eq '51S' or $route eq 'NC';

        if ($reverse) {
            next unless $skipped{$route};
        }
        else {
            next if $skipped{$route};
        }

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};
            next if $stopid =~ /^D/i;

            #$stoplist{$stopid}{Routes}{"$route-$dir"} = 1;
            $stoplist{$stopid}{Routes}{$route} = 1;
            #$stoplist{$stopid}{Description} = $stp{$stopid}{Description};
            $stoplist{$stopid}{Description}
              = $stops{$stopid}{c_description_full};

        }

    }

    return %stoplist;

}

1;

__END__

=head1 NAME

comparestops - Compares the stops from two sets of AVL files.

=head1 DESCRIPTION

comparestops reads the data written by readavl. It then assembles a
list of stops and the routes that stop at each one. Finally, it
displays a list of new, deleted, and changed stops.

=head1 AUTHOR

Aaron Priven

=cut

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

