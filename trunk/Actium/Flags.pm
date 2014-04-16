# Actium/Flags.pm

# Routines for dealing with flag artwork

# Subversion: $Id$

# legacy stage 4

package Actium::Flags 0.003;

use Actium::Preamble;
use Actium::Term;

const my @COLUMNS =>
  qw[ flagtype_filename    flagtype_master_page    Flags.stp_511_id
  FullDescription      decals  ];

const my $COLUMNS_SQL => join( ', ', @COLUMNS );

sub flag_assignments {

    my $actium_db  = shift;
    my $actium_dbh = $actium_db->dbh;

    my $query = qq[
    SELECT $COLUMNS_SQL 
    FROM Flags INNER JOIN Stops_Hastus 
       ON Flags.stp_511_id = Stops_Hastus.stp_511_id 
       LEFT JOIN Stops_User ON Flags.stp_511_id = Stops_User.stp_511_id 
       LEFT JOIN Stops_Perl ON Flags.stp_511_id = Stops_Perl.stp_511_id 
       LEFT JOIN Flagtypes on Flags.flagtype_id = Flagtypes.flagtype_id
    WHERE Flags.flag_to_print_next_run = 1
    ];

    my $sth = $actium_dbh->prepare($query);
    $sth->execute();

    my %rows_of_file;

    while ( my $row_r = $sth->fetchrow_arrayref ) {
    	my ($file, @rest) = @{$row_r};
    	$file =~ s/\.indd\z//;
        # DBI reuses the same hashref over and over, so have to make that
        # copy each time
        push @{$rows_of_file{$file}}, \@rest;
    }
    $sth->finish();
    
    unless (scalar %rows_of_file) {
        emit_text "No flags marked as to print in database.";
        emit_fatal;
        die "No flags marked as to print in database.";
    }
    
    my @rows_by_file;
    foreach my $file (keys %rows_of_file) {
    	push @rows_by_file, [ FILE => $file ];
    	push @rows_by_file, @{$rows_of_file{$file}};
    }

    return \@rows_by_file;

} ## tidy end: sub flag_assignments

sub flag_assignments_tabbed {
    my $actiumdb        = shift;
    my $assignments_aoa = Actium::Flags::flag_assignments($actiumdb);

    my $tabbed = Actium::Util::aoa2tsv( $assignments_aoa );

    return $tabbed;

}

1;

__END__

(these are tabs)

% more 19.5x17-RW13 
53315   Washington Blvd. at Fremont Blvd., Fremont, near side, going west       210-c   215-a
55969   Washington Blvd. at Fremont Blvd., Fremont, far side, going east        210-a   215-c
