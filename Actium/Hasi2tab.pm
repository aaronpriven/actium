# Actium/Hasi2tab.pm

# File for getting tab-delimted files from Hastus ASI files

# Subversion: $Id$

# legacy status: 4

use 5.012;
use warnings;

package Actium::Hasi2tab 0.001;

use Actium::Signup;
use Actium::Util qw(jt );
use Actium::Term ('output_usage');
use Actium::Files::HastusASI;
use Actium::Constants;

sub hasi2tab_START {

    my $hasidir = Actium::Signup->new('hasi');
    my $hasi    = Actium::Files::HastusASI->new( $hasidir->get_dir() );

    my $table = $ARGV[0];
    
    my $iterator = $hasi->each_row($table);

    emit "Sending tab-delimited $table data to STDOUT";

    my @columnnames = $hasi->columns_of_table($table);
    
    my $composite_key_name = "${table}_key";
    my $key = $hasi->key_of_table($table);
    push @columnnames, $composite_key_name 
       if ($key and $composite_key_name eq $key);
    
    unshift @columnnames, "${table}_id";
    
    my $parent = $hasi->parent_of_table($table);
    push @columnnames, "${parent}_id" if $parent;
    
    say jt (@columnnames);

    while (my $row_r = $iterator->()) {
        my @values;
        foreach my $key (@columnnames) {
            push @values, $row_r->{$key};
        }
        say jt(@values);
    }

    emit_done;

    return;
} ## #tidy# end sub hasi2tab_START

sub hasi2tab_HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium hasi2tab -- convert an Hasi file to tab file

Usage:

actium hasi2tab ROWTYPE

Outputs to standard output text consisting of the ROWTYPE from the Hastus
AVL Standard Interface files of the specified signup, converted to 
tab-delimited files. It is primarily for testing the Hasi routines. 
HELP

    output_usage();

    return;

} ## #tidy# end sub hasi2tab_HELP

1;
            
__END__


=head1 NAME

Hasi2tab - fetch Hastus AVL Standard Interface data from a database
and output as tab-delimited files

=head1 VERSION

This documentation refers to version 0.001

=head1 USAGE

From a shell:

 actium.pl hasi2tab ROWTYPE
   
=head1 REQUIRED ARGUMENTS

=over

=item B<ROWTYPE>

ROWTYPE is the table name from the Hastus AVL Standard Interface data.
This is the same as "Record" -- in the Hastus AVL Standard Interface 
documentation -- e.g., "STP" for the stop records.

=back

=head1 OPTIONS

This subprogram specifies no options, but other modules this subprogram
uses specify several. See:

=item L<OPTIONS in Actium::Files::SQLite|Actium::Files::SQLite/OPTIONS>
=item L<OPTIONS in Actium::Signup|Actium::Signup/OPTIONS>
=item L<OPTIONS in Actium::Term|Actium::Term/OPTIONS>

A complete list of options can be found by running "actium.pl help hasi2tab"

=head1 DESCRIPTION

Outputs to standard output text consisting of the ROWTYPE from the Hastus
AVL Standard Interface files of the specified signup, converted to 
tab-delimited files. Its purpose is primarily to test Actium::Files::SQLite
and Actium::Files::HastusASI, but may have other uses.

It includes the data from the Hastus ASI files as documented in the Hastus 
AVL Standard Interface documentation. It will also have at least one other 
column:

=over 

=item TABLE_id

A serial number for each line in the file, called "${table}_id" (e.g., 
"TPS" for the TPS table).

=item PARENTTABLE_id

The serial number the for the parent row of this row, in the parent table,
if this table has a parent.  For example, the TPS table will have a column 
PAT_id, containing the ID for the parent's row.

=item TABLE_key

If this row has a composite key (more than one field is part of the key),
then this column will exist, and consist of the components of the column
separated by the 
L<$KEY_SEPARATOR from Actium::Constants|Actium::Constants/$KEY_SEPARATOR>.

=back

=head1 DEPENDENCIES

=over

=item perl 5.012

=item Actium::Signup

=item Actium::Util

=item Actium::Term 

=item Actium::Files::HastusASI

=item Actium::Constants

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE. 