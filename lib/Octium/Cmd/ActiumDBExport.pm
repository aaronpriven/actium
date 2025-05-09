package Octium::Cmd::ActiumDBExport 0.012;

use Actium;
use Octium;

sub OPTIONS { return 'actiumdb' }
use DDP;
use Text::CSV;
my $csv = Text::CSV->new( { binary => 1, eol => "\r\n", quote_space => 0 } );

sub START {

    my $actiumdb = env->actiumdb;

    my $dbh = $actiumdb->dbh;

    #my $query1 = "SELECT * FROM Filemaker_Tables";
    #\my @array1 = $dbh->selectall_arrayref( $query1, { Slice => {} } );
    #p @array1;

    my $query1 = 'SELECT TableName, BaseTableName from Filemaker_Tables';
    \my @array1 = $dbh->selectall_arrayref($query1);
    my %basetable_of;
    foreach \my @array(@array1) {
        $basetable_of{ $array[0] } = $array[1];
    }
    #p %basetable_of;

    my @fields = qw/
      TableName
      FieldName
      FieldType
      FieldID
      FieldClass
      FieldReps
      ModCount
      /;

    my $fields = join( ", ", @fields );

    my $query = "SELECT $fields FROM Filemaker_Fields";
    \my @array = $dbh->selectall_arrayref($query);

    open my $out, '>', "actium_fields.txt" or die $!;

    my %fields_of_table;

    say $out join( "\t", @fields );
    for \my @row(@array) {
        my $table = $row[0];
        if ( $basetable_of{$table} ne $table ) {
            next;
        }
        push $fields_of_table{$table}->@*,  $row[1];
        say $out join( "\t", @row );
    }
    close $out;

    foreach my $table (sort keys %fields_of_table) {
        next if $table eq 'Global';
        my @fields_of_table = sort $fields_of_table{$table}->@*;

        my @quoted = map { qq{"$_"} } @fields_of_table;
        my $fields = join(", " , @quoted);
        my $query = "SELECT $fields FROM $table";

        say $query , "\n";

        \my @array = $dbh->selectall_arrayref($query);
        unshift @array, \@fields_of_table;

        my $filename = "$table.csv";
        $csv->csv(in => \@array, out => $filename, encoding => 'utf-8');

    }

}    

1;

__END__

=encoding utf8

=head1 NAME

Octium::Cmd::Scratch - temporary programs

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

