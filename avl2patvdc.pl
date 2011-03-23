#!/usr/bin/perl

@ARGV = qw(-s w08 -o f08) if $ENV{RUNNING_UNDER_AFFRUS};

# avl2patvdc - see POD documentation below

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

use Actium(qw[add_option initialize avldata sayq chdir_signup option]);
use Actium::Constants;
use Actium::Union('ordered_union');
use List::MoreUtils('uniq');

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
avl2patvdc reads the data written by readavl.
It then assembles a list of patterns and the appropriate 
vehicle display messages.
EOF

my $intro = 'avl2patvdc -- patterns and vehicle display codes';

Actium::initialize( $helptext, $intro );

my %stoplist = ();

my ( %pat, %vdc );

{    # scoping
        # the reason to do this is to release the %avldata structure, so Affrus
        # (or, presumably, another IDE)
     # doesn't have to display it when it's not being used. Of course it saves memory, too

    my $avldata_r = avldata();

    %pat = %{ $avldata_r->{PAT} };

    %vdc = %{ $avldata_r->{VDC} };

}


my %msgs;

foreach my $key ( keys %pat ) {

    next unless $pat{$key}{IsInService};

    my @messages;

    my $pat = $pat{$key}{Identifier};

    my $vdccode = $pat{$key}{VehicleDisplay};

    my $route = $pat{$key}{Route};

    my $dir = $pat{$key}{DirectionValue};

    foreach (qw(Message1 Message2 Message3 Message4)) {
        push @messages, $vdc{$vdccode}{$_};
    }


    my $newkey = sprintf('% 6s % 6s % 1s', $route, $pat, $dir);

    $msgs{$newkey} = "$route\t$pat\t$dir\t$vdccode: " . join (":", @messages);

}

foreach (sort keys %msgs) {
   print $msgs{$_} , "\n";
}

=head1 NAME

avl2patvdc - Displays the vehicle display code for each pattern

=head1 DESCRIPTION

avl2patvdc reads the data written by readavl.
It then assembles a list of patterns and the appropriate 
vehicle display messages.

=head1 AUTHOR

Aaron Priven

=cut
