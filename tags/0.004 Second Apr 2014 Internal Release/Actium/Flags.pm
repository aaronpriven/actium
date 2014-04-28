# Actium/Flags.pm

# Routines for dealing with flag artwork

# Subversion: $Id$

# legacy stage 4

package Actium::Flags 0.004;

use Actium::Preamble;
use Actium::Term;

const my @COLUMNS => qw[
  u_flagtype_id        flagtype_filename    flagtype_master_page
  h_stp_511_id         c_description_full   p_decals
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

    my $query = <<"EOT";

    SELECT $COLUMNS_SQL 
    FROM Stops_Neue 
       LEFT JOIN Flagtypes ON Stops_Neue.u_flagtype_id = Flagtypes.flagtype_id
    WHERE Stops_Neue.u_flag_to_print_next_run = 1

EOT

    my $sth = $actium_dbh->prepare($query);
    $sth->execute();

    my ( %rows_of_file, %skipped_because );

    while ( my $row_r = $sth->fetchrow_arrayref ) {

        my ( $flagtype, $file, $master, $stopid, $description, $decals )
          = @{$row_r};

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

    } ## tidy end: while ( my $row_r = $sth->...)
    $sth->finish();

    foreach my $reason ( keys %skipped_because ) {
        my @stops = join( $SPACE, @{ $skipped_because{$reason} } );
        emit_text "$SKIPPED_EXPLANATION_OF{$reason}: @stops";
    }

    unless ( scalar %rows_of_file ) {
        emit_error { -reason => 'Error: No flags to prepare.' };
        return;
    }

    my @rows_by_file;
    foreach my $file ( keys %rows_of_file ) {
        push @rows_by_file, [ FILE => $file ];
        push @rows_by_file, @{ $rows_of_file{$file} };
    }

    return \@rows_by_file;

} ## tidy end: sub flag_assignments

sub flag_assignments_tabbed {
    my $actiumdb        = shift;
    my $assignments_aoa = Actium::Flags::flag_assignments($actiumdb);

    return unless $assignments_aoa;    # if there was an error

    ## no critic (RequireExplicitInclusion)
    my $tabbed = Actium::Util::aoa2tsv($assignments_aoa);
    ## use critic

    return $tabbed;

}

1;

__END__

