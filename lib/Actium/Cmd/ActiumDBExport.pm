package Actium::Cmd::ActiumDBExport 0.014;

# Exports data for Scheduling import

use Actium;
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
                    $value = $EMPTY;
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
            $_ = $EMPTY;
            next VALUE;
        }
        s/\r/\|/gs;
    }

    return;

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

