package Actium::Cmd::CompareStops 0.011;

use Actium;

use Storable();    ### DEP ###
use Actium::Sorting::Line ('byline');
use Actium::Set('ordered_union');
use Actium::DaysDirections (':all');
use Algorithm::Diff('sdiff');    ### DEP ###

sub HELP {

    my $helptext = <<'EOF';
comparestops reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.
EOF

    print $helptext;
    return;
}

sub OPTIONS {
    return (
        qw/actiumdb signup_with_old/,
        {   spec        => 'ignore600s!',
            description => 'Ignore lines 600-699 in comparison. ',
            fallback    => 0,
        },

    );
}

my ( %changes, %oldstoplists, %stops );

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb  = $env->actiumdb;
    my $oldsignup = $env->oldsignup;
    my $signup    = $env->signup;

    my $ignore_600s = $env->option('ignore600s');

    my @skipped = qw(BSH 399);
    if ($ignore_600s) {
        push @skipped, ( 600 .. 699 );
    }

    chdir $signup->path;
    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    my $comparedir = $signup->subfolder('compare');

    my %newstoplists = assemble_stoplists( $signup, @skipped );

    open my $out, '>:utf8', 'compare/comparestops.txt' or die $OS_ERROR;
    # done here so as to make sure the file is saved in the *new*
    # signup directory

    print $out
"Change\tStopID\tStop Description\tNumAdded\tAdded\tNumRemoved\tRemoved\tNumUnchanged\tUnchanged\n";

    %oldstoplists = assemble_stoplists( $oldsignup, @skipped );

    my @stopids = u::uniq( sort ( keys %newstoplists, keys %oldstoplists ) );

    foreach my $type (qw<ADDED REMOVED UNCHANGED>) {
        $changes{$type} = {};
    }
    foreach my $type (qw<ADDEDSTOPS DELETEDSTOPS>) {
        $changes{$type} = [];
    }

  STOPID:
    foreach my $stopid (@stopids) {

        if ( not exists $oldstoplists{$stopid} ) {
            push @{ $changes{ADDEDSTOPS} }, $stopid;
            next STOPID;
        }

        if ( not exists $newstoplists{$stopid} ) {
            push @{ $changes{DELETEDSTOPS} }, $stopid;
            next STOPID;
        }

        my @oldroutes = sort keys %{ $oldstoplists{$stopid}{Routes} };
        my @newroutes = sort keys %{ $newstoplists{$stopid}{Routes} };

        next STOPID if ( join( '', @oldroutes ) ) eq ( join( '', @newroutes ) );
        # no changes

        my ( @added, @removed, @unchanged );

      COMPONENT:
        foreach
          my $component ( Algorithm::Diff::sdiff( \@oldroutes, \@newroutes ) )
        {

            my ( $action, $a_elem, $b_elem ) = @$component;

            if ( $action eq 'u' ) {
                #push @{$changes{CHANGEDSTOPS}{$stopid}{UNCHANGED}} , $a_elem;
                push @unchanged, $a_elem;
            }

            if ( $action eq 'c' or $action eq '-' ) {
                #push @{$changes{CHANGEDSTOPS}{$stopid}{REMOVED}} , $a_elem;
                push @removed, $a_elem;
            }

            if ( $action eq 'c' or $action eq '+' ) {
                #push @{$changes{CHANGEDSTOPS}{$stopid}{ADDED}}   , $b_elem;
                push @added, $b_elem;
            }

        }    # COMPONENT

        if ( not @removed ) {
            $changes{ADDLINES}{$stopid}{ADDED}     = \@added;
            $changes{ADDLINES}{$stopid}{UNCHANGED} = \@unchanged;
        }
        elsif ( not @added ) {
            $changes{REMOVEDLINES}{$stopid}{REMOVED}   = \@removed;
            $changes{REMOVEDLINES}{$stopid}{UNCHANGED} = \@unchanged;
        }
        else {
            $changes{CHANGEDSTOPS}{$stopid}{ADDED}     = \@added;
            $changes{CHANGEDSTOPS}{$stopid}{REMOVED}   = \@removed;
            $changes{CHANGEDSTOPS}{$stopid}{UNCHANGED} = \@unchanged;

        }

    }    # STOPID

    foreach my $added_stopid ( sort @{ $changes{ADDEDSTOPS} } ) {
        my $description = $newstoplists{$added_stopid}{Description};
        next if dummy($description);
        my @list = sort byline keys %{ $newstoplists{$added_stopid}{Routes} };
        print $out "AS\t", $added_stopid, "\t$description\t", scalar @list,
          "\t",
          '"', join( ' ', @list ), '"', "\n";
    }

    foreach my $deleted_stopid ( sort @{ $changes{DELETEDSTOPS} } ) {
        my $description = $oldstoplists{$deleted_stopid}{Description};
        next if dummy($description);
        my @list = sort byline keys %{ $oldstoplists{$deleted_stopid}{Routes} };
        print $out "RS\t", $deleted_stopid, "\t$description\t\t\t",
          scalar @list, "\t",
          '"', join( ' ', @list ), '"', "\n";
    }

    output_stops( 'AL', $out, 'ADDLINES' );

    output_stops( 'RL', $out, 'REMOVEDLINES' );

    output_stops( 'CL', $out, 'CHANGEDSTOPS' );

    say 'Completed comparison.';

    return;
} ## tidy end: sub START

sub dummy {
    local $_ = shift;
    return 1 if ( /^Virtual/ or /^Dummy/ );
    return 1 if /San Francisco Terminal/;
    return 1 if /Transbay Temp Terminal/;
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
            my @added = sort byline @{ $changes{$type}{$stopid}{ADDED} };
            print $fh "\t", scalar @added, "\t", '"', join( ' ', @added ), '"';
        }
        else {
            print $fh "\t\t";
        }

        if ( exists $changes{$type}{$stopid}{REMOVED} ) {
            my @removed = sort byline @{ $changes{$type}{$stopid}{REMOVED} };
            print $fh "\t", scalar @removed, "\t", '"', join( ' ', @removed ),
              '"';
        }
        else {
            print $fh "\t\t";
        }

        if ( exists $changes{$type}{$stopid}{UNCHANGED} ) {
            my @unchanged
              = sort byline @{ $changes{$type}{$stopid}{UNCHANGED} };
            print $fh "\t", scalar @unchanged, "\t", '"',
              join( ' ', @unchanged ), '"';
        }
        #      else {
        #         print $fh "\t\t";
        #      }

        print $fh "\n";

    } ## tidy end: foreach my $stopid ( sort keys...)

    return;

} ## tidy end: sub output_stops

sub assemble_stoplists {

    my $signup = shift;

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
        next if $skipped{$route};

        foreach my $tps_r ( @{ $pat{$key}{TPS} } ) {
            my $stopid = $tps_r->{StopIdentifier};
            next if $stopid =~ /^D/i;

            #$stoplist{$stopid}{Routes}{"$route-$dir"} = 1;
            $stoplist{$stopid}{Routes}{$route} = 1;
            #$stoplist{$stopid}{Description} = $stp{$stopid}{Description};
            $stoplist{$stopid}{Description}
              = $stops{$stopid}{c_description_full};

        }

    } ## tidy end: PAT: foreach my $key ( keys %pat)

    return %stoplist;

} ## tidy end: sub assemble_stoplists

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

