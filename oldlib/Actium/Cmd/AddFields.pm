package Actium::Cmd::AddFields 0.012;

# Adds fields from the database to a file.

use Actium;

use Actium::O::2DArray;

const my $DEFAULT_TABLE  => 'Stops_Neue';
const my $DEFAULT_FIELD  => 'c_description_full';
const my $DEFAULT_ID_COL => 1;

sub HELP {
    my ( $class, $env ) = @_;
    my $command = $env->command;
    say "Adds fields from the database to a file.";
    say "Usage: $command addfields <input_file> <field> <field>...";
    say '    If no fields are specified, uses "c_description_full"';
    return;
}

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        'actiumdb',
        {   spec            => 'table=s',
            description     => "Table where fields will come from",
            fallback        => $DEFAULT_TABLE,
            display_default => 1,
        },
        {   spec        => 'idcolumn=i',
            description => 'Column of the input file which will be used as IDs'
              . ' (starting with 1)',
            fallback        => $DEFAULT_ID_COL,
            display_default => 1,
        },
        {   spec        => 'output=s',
            description => 'Name of the output file. If not specified, '
              . 'the output file will be the name of the input file '
              . 'with "-out" just before the extension; e.g., "file.txt" '
              . 'will be changed to "file-out.txt".',
        },
        {   spec => 'headers!',
            description =>
              'Treat the first row of the files as the names of the headers '
              . '(on by default; turn off with -no-headers)',
            fallback => 1,
        },
    );
}    ## tidy end: sub OPTIONS

sub START {

    my ( $class, $env ) = @_;
    my $actiumdb = $env->actiumdb;

    my $table    = $env->option('table');
    my $keyfield = $actiumdb->key_of_table($table);

    my $column;
    if ( $env->option_is_set('idcolumn') ) {
        $column = $env->option('idcolumn') - 1;
    }
    else {
        $column = $DEFAULT_ID_COL;
    }
    # externally one-based, internally zero-based

    my $has_headers = $env->option('headers');
    my @fields      = $env->argv;
    my $file        = shift @fields;

    @fields = ($DEFAULT_FIELD) unless @fields;

    my $output_file = $env->option('output')
      // u::add_before_extension( $file, 'out' );

    my $load_cry = cry("Loading $file");
    my $aoa      = Actium::O::2DArray->new_from_file($file);
    $load_cry->done;

    my $process_cry = cry("Getting column from $file");
    my $last_col    = $aoa->last_col;

    if ( $column > $last_col ) {
        $process_cry->text(
            sprintf(
"Column specified, %d, is greater than last column in table, %d",
                $column + 1,
                $last_col + 1,
            )
        );
        $process_cry->d_error;
        die;
    }

    my @ids = $aoa->col($column);
    $process_cry->done;

    my $query_cry = cry('Preparing FileMaker query');
    $query_cry->text("From table $table, using $keyfield as the key");
    $query_cry->text("Fields: @fields");
    #$query_cry->text("Values: @ids");
    my $placeholders = join( ' , ', ( ('?') x (@ids) ) );
    my $eachtable = $actiumdb->each_columns_in_row_where(
        table       => $table,
        columns     => [ $keyfield, @fields ],
        where       => "WHERE $keyfield IN ( $placeholders )",
        bind_values => \@ids,
    );
    $query_cry->done;

    my %morefields_of;
    my $fetch_cry = cry('Fetching data from FileMaker');
    while ( my $row_r = $eachtable->() ) {
        my @values = @{$row_r};
        # copy is necessary since eachtable->() reuses the reference
        my $id = shift @values // $EMPTY;
        $fetch_cry->over($id);
        $morefields_of{$id} = \@values;
    }
    $fetch_cry->over($EMPTY);
    $fetch_cry->done;

    my $push_cry  = cry('Placing data in the correct rows');
    my $first_row = 0;
    if ($has_headers) {
        $first_row = 1;
        my $header_cry = cry('Adding field names to headers');

        $aoa->[0]->$#* = $last_col;
        push $aoa->[0]->@*, @fields;

        $header_cry->done;

    }

    for \my @row( $aoa->@[ $first_row .. $#{$aoa} ] ) {
        my $id = $row[$column] // $EMPTY;
        if ( exists $morefields_of{$id} ) {
            $push_cry->over($id);
            $#row = $last_col;
            # make sure there are enough undefined entries to fill out column
            push @row, @{ $morefields_of{$id} };
        }
    }
    $push_cry->over($EMPTY);
    $push_cry->done;

    # say u::dumpstr( \$aoa );

    my $write_cry = cry("Writing $output_file");

    $aoa->file( output_file => $output_file );
    $write_cry->done;

}    ## tidy end: sub START

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

