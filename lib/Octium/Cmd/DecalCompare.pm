package Octium::Cmd::DecalCompare 0.012;

use Actium;
use Octium;

use autodie;         ### DEP ###
use Data::Dumper;    ### DEP ###

sub START {

    my $class = shift;
    my $env   = shift;

    my @argv = $env->argv;

    my $firstfile  = shift(@argv);
    my $secondfile = shift(@argv);

    my %decals_of;
    my %olddesc_of;

    open my $in, '<', $firstfile;

    while ( my $line = <$in> ) {
        chomp $line;
        my ( $id, $olddesc, $decals ) = split( /\t/, $line, 3 );

        my @decals;
        @decals = Actium::uniq split( /\t/, $decals );

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
                new_line    => [
                    Actium::sortbyline(
                        Actium::uniq split /\t/,
                        $new_decals_text
                    )
                ],
                old_line         => [],
                new_decals       => [],
                old_decals       => [],
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

        $results_of{$id}{new_line} = [
            Actium::sortbyline(
                map { @{ $new_decals_of_line{$_} } } @{$new_lines}
            )
        ];
        $results_of{$id}{old_line} = [
            Actium::sortbyline(
                map { @{ $old_decals_of_line{$_} } } @{$old_lines}
            )
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

    }    ## tidy end: while ( my $line = <$comparefh>)
    close $comparefh;

    foreach my $id ( keys %decals_of ) {
        next if $results_of{$id};
        $results_of{$id} = {
            description => $olddesc_of{$id},
            change      => 'RS',
            old_line   => [ Actium::sortbyline( split /\t/, $decals_of{$id} ) ],
            new_line   => [],
            new_decals => [],
            old_decals => [],
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

    }    ## tidy end: foreach my $id ( sort keys ...)

    return;

}    ## tidy end: sub START

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
          7-c   7-d
          65-a    65-d
          65-b    65-e
          67-f    67-i
          67-g    67-j
          88-a    88-c
          851-a   851-e
          12-i    12-r
          12-i    12-t
          12-i    12-u
          18-e    18-k
          18-f    18-m
          51A-c   51A-h
          51A-c   51A-i
          80-b    80-k
          80-c    80-n
          80-g    80-m
          G-a     G-f
          G-d     G-g
          S-b     S-d
          S-a     S-c
          SB-a    SB-f
          SB-c    SB-d
          Z-a     Z-f
          Z-d     Z-e
          210-b   210-e
          210-c   210-f
          29-f    29-n
          29-g    29-o

          )
    ];

    my ( $new_decals, $old_decals, $unchanged_decals ) = @_;

    my ( %is_old_decal, %is_new_decal );
    $is_old_decal{$_} = 1 for @{$old_decals};
    $is_new_decal{$_} = 1 for @{$new_decals};

    my $it = Actium::natatime( 2, @$same_decals );

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

}    ## tidy end: sub move_insignificant_changes_to_unchanged

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

