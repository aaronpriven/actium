#Actium/Cmd/DecalCompare.pm

package Actium::Cmd::DecalCompare 0.010;

use Actium::Preamble;
use Actium::Sorting::Line ('sortbyline');

use autodie;         ### DEP ###
use Data::Dumper;    ### DEP ###

sub START {

    my $class  = shift;
    my $env = shift;
    
    my @argv   = $env->argv;

    my $firstfile  = shift(@argv);
    my $secondfile = shift(@argv);

    my %decals_of;
    my %olddesc_of;

    open my $in, '<', $firstfile;

    while ( my $line = <$in> ) {
        chomp $line;
        my ( $id, $olddesc, $decals ) = split( /\t/, $line, 3 );

        # drop DB lines
        my @decals;
        @decals = split( /\t/, $decals );
        #@decals = grep { !/\ADB1?\-/ } @decals;
        next unless @decals;

        $decals_of{$id} = join( "\t", @decals );
        $olddesc_of{$id} = $olddesc;
    }

    close $in;

    open my $comparefh, '<:encoding(UTF-8)', $secondfile;

    my %results_of;

    while ( my $line = <$comparefh> ) {
        chomp $line;

        my ( $id, $description, $new_decals_text ) = split( /\t/, $line, 3 );

        if ( not exists $decals_of{$id} ) {
            $results_of{$id} = {
                change      => 'AS',
                description => $description,
                new_line    => [ sortbyline( split /\t/, $new_decals_text ) ],
                old_line    => [],
                new_decals  => [],
                old_decals  => [],
                unchanged_decals => [],
            };
            next;
        }

        $results_of{$id}{description} = $description;

        my %old_decals_of_line = decals_of_line( $decals_of{$id} );
        my %new_decals_of_line = decals_of_line($new_decals_text);

        my ( $new_lines, $old_lines, $unchanged_lines )
          = add_drop_unchanged( [ keys %old_decals_of_line ],
            [ keys %new_decals_of_line ] );

        $results_of{$id}{new_line}
          = [
            sortbyline( map { @{ $new_decals_of_line{$_} } } @{$new_lines} )
          ];
        $results_of{$id}{old_line}
          = [
            sortbyline( map { @{ $old_decals_of_line{$_} } } @{$old_lines} )
          ];

        my @old_decals
          = map { @{ $old_decals_of_line{$_} } } @{$unchanged_lines};

        my @new_decals
          = map { @{ $new_decals_of_line{$_} } } @{$unchanged_lines};

        my ( $new_decals, $old_decals, $unchanged_decals )
          = add_drop_unchanged( \@old_decals, \@new_decals );

        move_insignificant_changes_to_unchanged( $new_decals, $old_decals,
            $unchanged_decals );

        $results_of{$id}{new_decals}       = $new_decals;
        $results_of{$id}{old_decals}       = $old_decals;
        $results_of{$id}{unchanged_decals} = $unchanged_decals;

    } ## tidy end: while ( my $line = <$comparefh>)
    close $comparefh;

    foreach my $id ( keys %decals_of ) {
        next if $results_of{$id};
        $results_of{$id} = {
            description      => $olddesc_of{$id},
            change           => 'RS',
            old_line         => [ sortbyline( split /\t/, $decals_of{$id} ) ],
            new_line         => [],
            new_decals       => [],
            old_decals       => [],
            unchanged_decals => [],
        };

    }

    say "StopID\tChange\tDescription\t"
      . "Old Line\tNew Line\tOld Decal\tNew Decal\tUnchanged";

    my %change_of_changecode = qw (
      U U
      UO RL
      UN AL
      UOC RLD
      UNC ALD
      UON CL
      UONC CLD
      UC D
    );

    foreach my $id ( sort keys %results_of ) {

        my $r = $results_of{$id};

        my $change;
        if ( exists $r->{change} ) {
            $change = $r->{change};
        }
        else {
            my $changecode = 'U';
            $changecode .= 'O' if @{ $r->{old_line} };
            $changecode .= 'N' if @{ $r->{new_line} };
            $changecode .= 'C'
              if @{ $r->{old_decals} } || @{ $r->{new_decals} };
            $change = $change_of_changecode{$changecode};
        }

        next if $change eq 'U';

        #   my $count;
        #   foreach my $group (qw(old_line new_line old_decals new_decals)) {
        #   	  $count++ foreach @{$r->{$group}};
        #   }
        #   next unless $count;

        print "$id\t$change\t", $r->{description};
        #   say Data::Dumper::Dumper($r);

        for (qw(old_line new_line old_decals new_decals unchanged_decals)) {
            die "Can't find $_ in $id" unless exists $r->{$_};
            die "Undefined $_ in $id"  unless defined $r->{$_};
            print "\t", join( $SPACE, @{ $r->{$_} } );
        }

        print "\n";

    } ## tidy end: foreach my $id ( sort keys ...)

    return;

} ## tidy end: sub START

sub decals_of_line {

    my @decals = split( /\t/, shift );
    my %decal_of;

    foreach my $decal (@decals) {
        my ( $line, $decalletter ) = split( /-/, $decal );
        push @{ $decal_of{$line} }, $decal;
    }

    return %decal_of;

}

sub add_drop_unchanged {

    require List::Compare;    ### DEP ###

    my @l  = sort @{ +shift };
    my @r  = sort @{ +shift };
    my $lc = List::Compare->new( \@l, \@r );

    my $a = $lc->get_Ronly_ref;
    my $d = $lc->get_Lonly_ref;
    my $u = $lc->get_intersection_ref;

    #say Data::Dumper::Dumper($a, $d, $u);

    return ( $a, $d, $u );

}

sub move_insignificant_changes_to_unchanged {
    state $same_decals = [
        qw(
          46-b 46-d
          46-d 46-b
          DB-a DB-g
          DB-b DB-h
          DB-c DB-i
          DB-d DB-j
          DB-e DB-k
          DB-e DB-l
          DB-q DB-s
          DB-r DB-t
          DB1-a DB1-f
          DB1-b DB1-g
          DB1-c DB1-h
          DB1-d DB1-i
          DB1-e DB1-j
          DB3-a DB3-f
          DB3-b DB3-g
          DB3-c DB3-h
          DB3-d DB3-i
          DB3-e DB3-j
          F-e  F-a
          F-f  F-d
          M-a  M-e
          M-b  M-f
          11-d  11-h
          31-b  31-g
          232-d 232-c
          356-a 356-e
          800-b 800-g
          )
    ];

    my ( $new_decals, $old_decals, $unchanged_decals ) = @_;

    my ( %is_old_decal, %is_new_decal );
    $is_old_decal{$_} = 1 for @{$old_decals};
    $is_new_decal{$_} = 1 for @{$new_decals};

    my $it = u::natatime( 2, @$same_decals );

    while ( my ( $old, $new ) = $it->() ) {
        if ( $is_old_decal{$old} and $is_new_decal{$new} ) {
            delete $is_old_decal{$old};
            delete $is_new_decal{$new};
            @$old_decals = keys %is_old_decal;
            @$new_decals = keys %is_new_decal;
            push @$unchanged_decals, "$old=$new";
        }
    }

    return ( $new_decals, $old_decals, $unchanged_decals );

} ## tidy end: sub move_insignificant_changes_to_unchanged

1;