# Actium/O/Files/ActiumDB.pm

# Class holding routines related to the Actium database
# (the FileMaker database used by Actium users), accessed
# thorugh ODBC.

# Subversion: $Id$

# Legacy stage 4

package Actium::O::Files::ActiumFM;

use Actium::Moose;
use Params::Validate(':all');

const my $KEYFIELD_TABLE        => 'FMTableKeys';
const my $KEY_OF_KEYFIELD_TABLE => 'FMTableKey';
const my $TABLE_OF_KEYFIELD_TABLE => 'FMTable';

has 'db_name' => (
    is  => 'ro',
    isa => 'Str',
);

has 'db_user' => (
    is  => 'ro',
    isa => 'Str',
);

has 'db_password' => (
    is  => 'ro',
    isa => 'Str',
);

has '_keys_of_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    init_arg => undef,
    isa     => 'HashRef[Str]',
    handles => { key_of_table => 'get', },
    builder => '_build_keys_of',
    lazy    => 1,
);

sub _build_keys_of {
    my $self = shift;
    $self->_ensure_loaded($KEYFIELD_TABLE);

    my $dbh = $self->dbh;

    my $query =
      "SELECT $TABLE_OF_KEYFIELD_TABLE, $KEY_OF_KEYFIELD_TABLE FROM $KEYFIELD_TABLE"
      ;
    my $rows_r = $dbh->selectall_arrayref( $query );
    my %keys_of = flatten ($rows_r);

    return \%keys_of;
    # copy of returned hashref

}



with 'Actium::O::Files::FileMaker_ODBC';

1;

__END__




1;

__END__
