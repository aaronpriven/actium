package Actium::Cmd::ActiumDBExport 0.011;

# Exports data for Scheduling import

use Actium::Preamble;
use Actium::O::Folder;
use Archive::Zip (qw( :ERROR_CODES :CONSTANTS ));    ### DEP ###

my %fields_of =

  ( Lines => [
        qw[ Active Color Description GovDeliveryTopic
          Line LineForSorting TimetableDate ]
    ],
    Colors => [
        qw[ Black Blue CMYKDisplay ColorID Cyan Green
          LongColorName Magenta Red RGB RGBDisplay Yellow ]
    ],
    Cities      => [qw[ City Code Region Side Sector ]],
    Places_Neue => [qw[ c_city c_description c_destination h_plc_identifier ]],
    Stops_Neue  => [
        qw[ c_at c_at_long c_city c_comment c_corner
          c_description_city c_description_full c_description_ids
          c_description_nocity c_description_short c_direction
          c_on c_site c_street_num h_stp_511_id
          p_active p_added_line_count p_added_lines p_just_made_active
          p_just_made_inactive p_line_count p_lines p_prev_line_count
          p_prev_lines p_removed_line_count p_removed_lines
          p_unch_line_count p_unch_lines u_connections ]
    ],
  );

sub OPTIONS {
    return 'actiumdb';
}

sub START {

    my ( $class, $env ) = @_;
    $env->be_quiet;

    local $OUTPUT_RECORD_SEPARATOR = "\r\n";    # exporting for windoze

    my $actiumdb = $env->actiumdb;

    my $dbh = $actiumdb->dbh;

    my $folder = Actium::O::Folder->new('/Volumes/Bireme/Actium/database');
    my $zip    = Archive::Zip->new();

    foreach my $table ( keys %fields_of ) {

        my @columns = @{ $fields_of{$table} };

        my $column_list = join( ',', @columns );
        my $rows_r
          = $dbh->selectall_arrayref("SELECT $column_list from $table");

        #my $fh = $folder->open_write("$table.txt");

        my $result_text;
        open my $fh, '>:encoding(UTF-8)', \$result_text
          or die $OS_ERROR;

        say $fh join( "\t", @columns );

        foreach my $row_r ( @{$rows_r} ) {
            my @values = @{$row_r};

          VALUE:
            foreach my $value (@values) {
                if ( not defined $value ) {
                    $value = $EMPTY_STR;
                    next VALUE;
                }
                $value =~ s/\r/\|/sg;
            }
            process_values(@values);
            say $fh join( "\t", @values );
        }

        close $fh or die $OS_ERROR;
        $zip->addString( $result_text, "$table.txt",
            COMPRESSION_LEVEL_BEST_COMPRESSION );

    } ## tidy end: foreach my $table ( keys %fields_of)

    my $zipfile = $folder->make_filespec('ActiumExports.zip');

    unless ( $zip->writeToFileNamed($zipfile) == AZ_OK ) {
        die 'error writing zip file';
    }

} ## tidy end: sub START

sub process_values {

  VALUE:
    foreach (@_) {
        if ( not defined ) {
            $_ = $EMPTY_STR;
            next VALUE;
        }
        s/\r/\|/gs;
    }

    return;

}

1;
