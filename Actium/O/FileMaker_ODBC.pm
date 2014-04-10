# Actium/O/Files/FMPXMLResult.pm

# Class for reading and processing FileMaker Pro databases via ODBC

# Subversion: $Id$

# Legacy stage 4

use 5.016;
use strict;
use warnings;

use Actium::Preamble;

use DBI;

__END__


use DBI qw(:sql_types);

my $db_connect_string_fmpro = 'ActiumFM';
#my $filemaker_database_name = 'ACTransit_Actium';
my $filemaker_database_name = 'Flagtypes';

my $long_readlength = 100000; # maximum number of bytes for Text, LongBLOB type data read from FileMaker - increase this value as needed
my $record_count=0;
my @rowdata = ();

my $fmpro_dbh = DBI->connect ("dbi:ODBC:$db_connect_string_fmpro", "username", "password", {RaiseError => 1, PrintError => 1, AutoCommit => 0})
or die "Can't connect to the FileMaker $db_connect_string_fmpro database: $DBI::errstr\n";

$fmpro_dbh->{LongReadLen} = $long_readlength;
$fmpro_dbh->{LongTruncOk} = 0;

my $fmpro_sth = $fmpro_dbh->prepare("select * from $filemaker_database_name");

$fmpro_sth->execute();

while ( @rowdata = $fmpro_sth->fetchrow_array())
{

say (join("\t" , @rowdata));

}

$fmpro_dbh->disconnect or warn "Can't disconnect from the FileMaker $db_connect_string_fmpro database: $DBI::errstr\n";

