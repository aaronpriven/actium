package Octium::Flags 0.012;

use Actium;
use Octium;

const my @COLUMNS => qw[
  u_flagtype_id        flagtype_filename    flagtype_master_page
  h_stp_511_id         c_description_full   p_decals
  u_flex_route
];

const my %COLUMN_INDEX_OF => ( map { $COLUMNS[$_] => $_ } 0 .. $#COLUMNS );

const my $COLUMNS_SQL => join( ', ', @COLUMNS );

const my %SKIPPED_EXPLANATION_OF => (
    no_flagtype => 'The following had no flagtype set',
    no_decals   => 'The following had no decals set'
);

sub flag_assignments {

    my $actium_db  = shift;
    my $actium_dbh = $actium_db->dbh;

    my @stopids = @_;
    my $query;

    if (@stopids) {

        my $placeholders = ( join ', ', ('?') x scalar @stopids );

        $query = <<"EOT";

    SELECT $COLUMNS_SQL 
    FROM Stops_Neue 
       LEFT JOIN Flagtypes ON Stops_Neue.u_flagtype_id = Flagtypes.flagtype_id
       WHERE Stops_Neue.h_stp_511_id IN ($placeholders)
EOT

    }
    else {

        $query = <<"EOT";

    SELECT $COLUMNS_SQL 
    FROM Stops_Neue 
       LEFT JOIN Flagtypes ON Stops_Neue.u_flagtype_id = Flagtypes.flagtype_id
    WHERE Stops_Neue.u_flag_to_print_next_run = 1

EOT

    }

    my $sth = $actium_dbh->prepare($query);
    $sth->execute(@stopids);

    my ( %rows_of_file, %skipped_because );

    while ( my $row_r = $sth->fetchrow_arrayref ) {

        foreach ( @{$row_r} ) {
            next unless defined;
            s/\s+\z//;    # trim trailing white space
        }

        my ( $flagtype, $file, $master, $stopid, $description, $decals, $flex )
          = @{$row_r};

        if ( $flex and $decals ) {
            $decals .= " $flex";
        }
        elsif ($flex) {
            $decals = $flex;
        }

        unless ($flagtype) {
            push @{ $skipped_because{no_flagtype} }, $stopid;
            next;
        }

        unless ($decals) {
            push @{ $skipped_because{no_decals} }, $stopid;
            next;
        }

        $master ||= 'A';

        $file =~ s/[.]indd\z//sx;

        push @{ $rows_of_file{$file} },
          [ $master, $stopid, $description, $decals ];

    }    ## tidy end: while ( my $row_r = $sth->...)
    $sth->finish();

    foreach my $reason ( keys %skipped_because ) {
        my @stops = join( $SPACE, @{ $skipped_because{$reason} } );
        env->wail("$SKIPPED_EXPLANATION_OF{$reason}: @stops");
    }

    unless ( scalar %rows_of_file ) {
        env->last_cry->error( { -reason => 'Error: No flags to prepare.' } );
        return;
    }

    my @rows_by_file;
    foreach my $file ( keys %rows_of_file ) {
        push @rows_by_file, [ FILE => $file ];
        push @rows_by_file, @{ $rows_of_file{$file} };
    }

    return \@rows_by_file;

}    ## tidy end: sub flag_assignments

sub flag_assignments_tabbed {
    my $assignments_aoa = Octium::Flags::flag_assignments(@_);

    return unless $assignments_aoa;    # if there was an error

    require Array::2D;
    my $assignments = Array::2D->bless($assignments_aoa);

    return $assignments->tsv;

}

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

