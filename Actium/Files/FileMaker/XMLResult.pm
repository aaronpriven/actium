# Actium/Files/HastusASI.pm

# Class for reading and processing FileMaker Pro FMPXMLRESULT XML exports
# and storing in an SQLite database using Actium::Files::SQLite

# Subversion: $Id$

# Legacy stage 4

use warnings;
use 5.012;    # turns on features

package Actium::Files::FileMaker::XMLResult 0.001;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

use Readonly;

#requires(
#    qw/db_type key_of_table columns_of_table tables
#       _load _files_of_filetype _tables_of_filetype
#       _filetype_of_table is_a_table/
#);

sub db_type () {'FileMaker'}
# I think all the FileMaker exports will be the same database type

# Should be moved to a configuration file of some kind
Readonly my %KEY_OF => (
    Cities        => 'Code',
    Colors        => 'ColorID',
    Lines         => 'Line',
    Neighborhoods => 'Neighborhood',
    Projects      => 'Project',
    SignTypes     => 'SignType',
    Signs         => 'SignID',
    SkedAdds      => 'SkedId',
    Skedidx       => 'SkedId',
    Timepoints    => 'Abbrev4',
    Stops         => 'PhoneID',
);

# Just one table per filetype, and file and filetype have the same name
sub _tables_of_filetype {
   my $self = shift;
   my $table = shift;
   return $table;
}

sub _filetype_of_table {
   my $self = shift;
   my $table = shift;
   return $table;
}

sub _files_of_filetype {
   my $self = shift;
   my $table = shift;
   return "$table.xml";
}

sub _key_of_table {
   my $self = shift;
   my $table = shift;
   my $key = $KEY_OF{$table};
   return unless $key;
   return $key;  
}

sub tables {
 
 # glob xml files on disk and return list, minus extension
}

sub is_a_table {
 # check against list found by tables, above
 
}

sub columns_of_table {
 
 # load table, then get columns
 
}

sub _load {
 
 # load
 
}

