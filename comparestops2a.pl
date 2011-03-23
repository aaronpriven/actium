#!/ActivePerl/bin/perl

# comparestops - see POD documentation below

#00000000111111111122222222223333333333444444444455555555556666666666777777777
#23456789012345678901234567890123456789012345678901234567890123456789012345678

use warnings;
use strict;

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Carp;
#use Fatal qw(open close);
use Storable();

use Actium(
    qw[add_option initialize avldata ensuredir sayq chdir_signup option byroutes]
);
use Actium::Constants;
use Actium::Union('ordered_union');
use List::MoreUtils('uniq');
use Actium::HastusASI::Util (':ALL');

# don't buffer terminal output
$| = 1;

{
    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    }
}

my $helptext = <<'EOF';
avl2stoplists reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.
See "perldoc comparestops" for more information.
EOF

my $intro = 'comparestops -- compare old and new stops from AVL data';

add_option( 'oldsignup=s',
'The older signup. The program compares data from the this signup to the one'
      . 'specified by the "signup" option.' );

Actium::initialize( $helptext, $intro );

my %newstoplists = assemble_stoplists(qw(BSH 399));

ensuredir('compare');

open my $out, '>', 'compare/comparestops-x.txt' or die "$!";
# done here so as to make sure the file is saved in the *new*
# signup directory

print $out
"Change\tStopID\tStop Description\tNumAdded\tAdded\tNumRemoved\tRemoved\tNumUnchanged\tUnchanged\n";

chdir_signup( 'oldsignup', 'ACTIUM_OLDSIGNUP', 'old signup' );

my %oldstoplists = assemble_stoplists(qw(BSH 399));

my @stopids = uniq( sort ( keys %newstoplists, keys %oldstoplists ) );

my %changes;

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
    foreach my $component ( Algorithm::Diff::sdiff( \@oldroutes, \@newroutes ) )
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
    my @list = sort byroutes keys %{ $newstoplists{$added_stopid}{Routes} };
    print $out "AS\t", $added_stopid, "\t$description\t", scalar @list, "\t",
      join( ',', @list ), "\n";
}

foreach my $deleted_stopid ( sort @{ $changes{DELETEDSTOPS} } ) {
    my $description = $oldstoplists{$deleted_stopid}{Description};
    next if dummy($description);
    my @list = sort byroutes keys %{ $oldstoplists{$deleted_stopid}{Routes} };
    print $out "RS\t", $deleted_stopid, "\t$description\t\t\t",
      scalar @list, "\t",
      join( ',', @list ), "\n";
}

output_stops( 'AL', $out, 'ADDLINES' );

output_stops( 'RL', $out, 'REMOVEDLINES' );

output_stops( 'CL', $out, 'CHANGEDSTOPS' );

sayq "Completed comparison.";

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
            my @added = sort byroutes @{ $changes{$type}{$stopid}{ADDED} };
            print $fh "\t", scalar @added, "\t", join( ',', @added );
        }
        else {
            print $fh "\t\t";
        }

        if ( exists $changes{$type}{$stopid}{REMOVED} ) {
            my @removed = sort byroutes @{ $changes{$type}{$stopid}{REMOVED} };
            print $fh "\t", scalar @removed, "\t", join( ',', @removed );
        }
        else {
            print $fh "\t\t";
        }

        if ( exists $changes{$type}{$stopid}{UNCHANGED} ) {
            my @unchanged
              = sort byroutes @{ $changes{$type}{$stopid}{UNCHANGED} };
            print $fh "\t", scalar @unchanged, "\t", join( ',', @unchanged );
        }
        #      else {
        #         print $fh "\t\t";
        #      }

        print $fh "\n";

    } ## tidy end: foreach my $stopid ( sort keys...)

    return;

} ## tidy end: sub output_stops

sub assemble_stoplists {

    my %stoplist = ();

    my %skipped;
    $skipped{$_} = 1 foreach @_;

    my ( %pat, %stp );

    {    # scoping
         # the reason to do this is to release the %avldata structure, so Affrus
         # (or, presumably, another IDE)
         # doesn't have to display it when it's not being used. Of course it saves memory, too

        my $avldata_r = avldata();

        %pat = %{ $avldata_r->{PAT} };

        %stp = %{ $avldata_r->{STP} };

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
            $stoplist{$stopid}{Description} = $stp{$stopid}{Description};

        }

    } ## tidy end: foreach my $key ( keys %pat)

    return %stoplist;

} ## tidy end: sub assemble_stoplists

=head1 NAME

comparestops - Compares the stops from two sets of AVL files.

=head1 DESCRIPTION

comparestops reads the data written by readavl.
It then assembles a list of stops and the routes that stop at each one.
Finally, it displays a list of new, deleted, and changed stops.

=head1 AUTHOR

Aaron Priven

=cut
