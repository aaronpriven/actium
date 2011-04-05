# Actium/SQLite2tab.pm

# File for getting tab-delimted files from Actium::Files::SQLite

# Subversion: $Id$

# legacy status: 4

use 5.012;
use warnings;

package Actium::SQLite2tab 0.001;

use Actium::Signup;
use Actium::Util qw(jt );
use Actium::Term ('output_usage');
use Actium::Constants;
use Actium::Files::FMPXMLResult;
use Actium::Files::HastusASI;


use Actium::Options(qw<add_option option>);

add_option( 'type=s', 'Database type -- H for Hastus or F for FileMaker' );

sub START {

    my $dir;
    my $db;

    my $type = option('type');
    given ( lc($type) ) {
        when ('f') {
            $dir = Actium::Signup->new('xml');
            $db = Actium::Files::FMPXMLResult->new( $dir->get_dir() );
        }
        when ('h') {
            $dir = Actium::Signup->new('hasi');
            $db = Actium::Files::HastusASI->new( $dir->get_dir() );
        }
        default {
            die "Don't know about type $type";
        }
    }

    my $table = $ARGV[0];

    my $iterator = $db->each_row($table);

    emit "Sending tab-delimited $table data to STDOUT";
    
    binmode STDOUT, ':utf8';

    my @columnnames = $db->columns_of_table($table);

    my $composite_key_name = "${table}_key";
    my $key                = $db->key_of_table($table);
    push @columnnames, $composite_key_name
      if ( $key and $composite_key_name eq $key );

    unshift @columnnames, "${table}_id";

    my $parent = $db->parent_of_table($table);
    push @columnnames, "${parent}_id" if $parent;

    say jt (@columnnames);

    while ( my $row_r = $iterator->() ) {
        my @values;
        foreach my $key (@columnnames) {
            push @values, $row_r->{$key};
        }
        say jt(@values);
    }

    emit_done;

    return;
} ## tidy end: sub START

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium sqlite2tab -- convert Actium::Files::SQLite data to tab file

Usage:

actium sqlite2tab --type <type> <table>

<type> must be either H for Hastus or F for FileMaker.

Outputs to standard output text consisting of the table from the 
specified database, delimited by tabs. It is primarily for testing the 
database routines. 
HELP

    output_usage();

    return;

}
1;

__END__


=head1 NAME

sqlite2tab - fetch data from a SQLite database
and output as tab-delimited files

=head1 VERSION

This documentation refers to version 0.001

=head1 USAGE

From a shell:

 actium.pl sqlite2tab -type <type> <table>
   
=head1 REQUIRED ARGUMENTS

=over

=item B<table>

This is the table name. From the Hastus AVL Standard Interface data,
it is the same as "Record" -- in the Hastus AVL Standard Interface 
documentation -- e.g., "STP" for the stop records. For FileMaker data, 
it is the name of the file (e.g., "Timepoints" for "Timepoints.xml").

=back

=head1 OPTIONS

=over

=item B<-type>

"type" is a required option (not really an option, then, I guess), specifying
what kind of database to use: H for Hastus ASI or F for FileMaker FMPXMLResult.

=back

Other modules this subprogram uses specify several other options. See:

=item L<OPTIONS in Actium::Files::SQLite|Actium::Files::SQLite/OPTIONS>
=item L<OPTIONS in Actium::Signup|Actium::Signup/OPTIONS>
=item L<OPTIONS in Actium::Term|Actium::Term/OPTIONS>

A complete list of options can be found by running "actium.pl help sqlite2tab"

=head1 DESCRIPTION

Outputs to standard output text consisting of the ROWTYPE from the Hastus
AVL Standard Interface files, or the FileMaker Pro FMPXMLRESULT XML files
of the specified signup, converted to 
tab-delimited files. Its purpose is primarily to test Actium::Files::SQLite
and classes that compose it, but may have other uses.

For Hastus ASI, it includes the data from the Hastus ASI files as documented in the Hastus 
AVL Standard Interface documentation.  For FileMaker, it includes whatever
data was exported.

It will also have one or more additional columns:

=over 

=item TABLE_id

A serial number for each line in the file, called "${table}_id" (e.g., 
"TPS" for the TPS table). This will always be present.

=item PARENTTABLE_id

The serial number the for the parent row of this row, in the parent table,
if this table has a parent.  For example, the TPS table will have a column 
PAT_id, containing the ID for the parent's row. (Hastus only)

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

=item Actium::Files::FMPXMLResult

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
