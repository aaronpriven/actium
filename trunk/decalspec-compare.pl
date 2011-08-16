#!/ActivePerl/bin/perl

use strict;
use warnings;
use 5.014;

use autodie;
use List::MoreUtils('uniq');

use Readonly;
Readonly my $NEWFLAGDIR       => '/Volumes/Bireme/Actium/db/f11/flags';
Readonly my $OLDFLAGDIR       => '/Volumes/Bireme/Actium/db/f10/flags';
Readonly my $OLDASSIGNFILE    => "$OLDFLAGDIR/assignments.txt";
Readonly my $NEWASSIGNFILE    => "$NEWFLAGDIR/assignments.txt";
Readonly my $NEWSTOPDECALFILE => "$NEWFLAGDIR/stop-decals.txt";
Readonly my $OLDSTOPDECALFILE => "$OLDFLAGDIR/stop-decals.txt";
Readonly my $CHANGEDECALFILE  => "$NEWFLAGDIR/stop-decal-compare.txt";

use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

my ( @stops, %stops );
FPread_simple( '/Volumes/Bireme/Actium/db/f11/Stops.csv', \@stops, \%stops, 'PhoneID' );

open my $oldassignments, '<', $OLDASSIGNFILE;

my %source_for;

$_ = <$oldassignments>;    # skip header line

while (<$oldassignments>) {
    chomp;
    my @fields = split(/\t/);
    my ( $stop, $source ) = @fields[ 0, 6 ];

    $source_for{$stop} = $source // q{};

}

close $oldassignments;

open my $new_stop_decals, '<', $NEWSTOPDECALFILE;

my ( %old_decals_of, %new_decals_of, %desc_of, %new_line_of );

while (<$new_stop_decals>) {
    chomp;

    my @fields = split(/\t/);
    my $stop   = shift @fields;
    $new_line_of{$stop}   = $_;
    $desc_of{$stop}       = shift @fields;
    $new_decals_of{$stop} = \@fields;

}

close $new_stop_decals;

open my $old_stop_decals, '<', $OLDSTOPDECALFILE;

my %change;

OLD_STOP:
while (<$old_stop_decals>) {

    chomp;
    my @fields   = split(/\t/);
    my $stop     = shift @fields;
    my $old_desc = shift @fields;
    $old_decals_of{$stop} = \@fields;

    if ( not exists $new_decals_of{$stop} ) {
        $change{$stop}
          = "RS\t$stop\t$source_for{$stop}\t$old_desc\t\t@{$old_decals_of{$stop}}";
        next OLD_STOP;
    }

    $old_decals_of{$stop} = \@fields;

}

close $old_stop_decals;

my %assign;

NEW_STOP:
foreach my $stop ( sort keys %new_decals_of ) {
 
    my $newsource = q{};

    $source_for{$stop} //= q{};
    
        if ($source_for{$stop} =~ /^[PIC]\d/) {
             $newsource = $source_for{$stop};
        }
    
    
    my ( $lines, $boxes , @lines) = get_lines_and_boxes( $new_decals_of{$stop} );

    $assign{$stop}
      = "$stop\t"
      . $stops{$stop}{DescriptionCityF} . "\t"
      . $stops{$stop}{district_id}
      . "\t@lines\t$lines\t$boxes\t$newsource\t$source_for{$stop}";

    if ( not exists $old_decals_of{$stop} ) {
        $source_for{$stop} //= q{};
        $change{$stop}
          = "AS\t$stop\t$source_for{$stop}\t$desc_of{$stop}\t@{$new_decals_of{$stop}}";

        next NEW_STOP;
    }

    my @old_decals = @{ $old_decals_of{$stop} };
    my @new_decals = @{ $new_decals_of{$stop} };

    #say "[@old_decals][@new_decals]";

    if ( "@old_decals" eq "@new_decals" ) {
        $change{$stop}
          = "\t$stop\t$source_for{$stop}\t$desc_of{$stop}\t\t\t@{$new_decals_of{$stop}}";
        next NEW_STOP;
    }

    my ( %in_old, %in_new );

    $in_old{$_}++ foreach @old_decals;
    $in_new{$_}++ foreach @new_decals;

    my $change = "CD\t$stop\t$source_for{$stop}\t$desc_of{$stop}";

    # TODO - add distinctions between AL, RL, CL.
    # But what if changing more than one thing -
    # add a line and change a decal? figure that out

    my ( @added, @removed, @unchanged );

    foreach my $decal ( uniq sort ( @old_decals, @new_decals ) ) {
        if ( $in_old{$decal} and not $in_new{$decal} ) {
            push @removed, $decal;
        }
        elsif ( $in_new{$decal} and not $in_old{$decal} ) {
            push @added, $decal;
        }
        else {
            push @unchanged, $decal;
        }
    }

    no warnings 'uninitialized';

    $change{$stop} = $change . "\t@added\t@removed\t@unchanged";

} ## tidy end: foreach my $stop ( sort keys...)

open my $change_file, '>', $CHANGEDECALFILE;

say $change_file "Change\tStop\tSource\tDescription\tAdded\tRemoved\tUnchanged";

foreach my $stop ( sort keys %change ) {

    my @changes = split( /\t/, $change{$stop} );

    @changes = map {qq{"$_"}} @changes;
    # add quotes so Excel will know it's all text

    say $change_file join( "\t", @changes );

}

close $change_file;

open my $new_assign_file, '>', $NEWASSIGNFILE;

say $new_assign_file
  "StopID\tDescription\tCityCode\tLines\t#lines\t#boxes\tSource\tOldSource";
  
foreach my $stop (sort keys %assign) {
    say $new_assign_file $assign{$stop};
}

close $new_assign_file;

sub get_lines_and_boxes {

    my @decals = @{+shift};
    
    my @lines = map { s/-.*//r } @decals;
    @lines = uniq sort @lines;

    return ( scalar @lines, scalar @decals  , @lines);

}

