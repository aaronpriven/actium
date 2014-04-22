# Actium/O/Files/ActiumDB.pm

# Class holding routines related to the Actium database
# (the FileMaker database used by Actium users), accessed
# thorugh ODBC.

# Subversion: $Id$

# Legacy stage 4

package Actium::O::Files::ActiumFM;

use Actium::Moose;

const my $KEYFIELD_TABLE        => 'FMTableKeys';
const my $KEY_OF_KEYFIELD_TABLE => 'FMTableKey';

#around BUILDARGS => sub {
#    my $orig  = shift;
#    my $class = shift;
#
#    my $args_r = $class->$orig(@_);
#
#    for (qw(user password)) {
#        my $db = "db_$_";
#        if ( exists $args_r->{$_} and not exists $args_r->{$db} ) {
#            $args_r->{$db} = $args_r->{$_};
#            delete $args_r->{$_};
#        }
#    }
#
#    return $args_r;
#
#};

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

    my $query = "SELECT $KEY_OF_KEYFIELD_TABLE FROM $KEYFIELD_TABLE";
    my $key_of_r = $dbh->selectall_hashref( $query, $KEY_OF_KEYFIELD_TABLE );
    return $key_of_r;

}

with 'Actium::O::Files::FileMaker_ODBC';

1;

__END__




1;

__END__
