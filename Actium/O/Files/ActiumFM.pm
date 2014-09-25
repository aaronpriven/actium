# Actium/O/Files/ActiumDB.pm

# Class holding routines related to the Actium database
# (the FileMaker database used by Actium users), accessed
# thorugh ODBC.

# Subversion: $Id$

# Legacy stage 4

package Actium::O::Files::ActiumFM 0.006;

use Actium::Moose;

const my $KEYFIELD_TABLE          => 'FMTableKeys';
const my $KEY_OF_KEYFIELD_TABLE   => 'FMTableKey';
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
    traits   => ['Hash'],
    is       => 'bare',
    init_arg => undef,
    isa      => 'HashRef[Str]',
    handles  => { key_of_table => 'get', },
    builder  => '_build_keys_of',
    lazy     => 1,
);

sub _build_keys_of {
    my $self = shift;
    $self->_ensure_loaded($KEYFIELD_TABLE);

    my $dbh = $self->dbh;

    my $query
      = "SELECT $TABLE_OF_KEYFIELD_TABLE, $KEY_OF_KEYFIELD_TABLE FROM $KEYFIELD_TABLE";
    my $rows_r  = $dbh->selectall_arrayref($query);
    my %keys_of = flatten($rows_r);

    return \%keys_of;
    # copy of returned hashref

}

##############################
### SS CACHE

const my $DEFAULT_CACHE_FOLDER => '/tmp/actium_db_cache/';

const my $SS_TABLE           => 'Stops_Neue';
const my $SS_CACHE_FNAME     => 'ss_cache.storable';
const my $CACHE_TIME_TO_LIVE => 60 * 60;               # seconds

const my @SS_COLUMNS => (
    qw[
      h_stp_511_id
      h_stp_identifier
      c_description_full
      p_active
      h_loca_longitude
      h_loca_latitude
      ]
);

has cachefolder => (
    isa     => 'Actium::O::Folder',
    is      => 'ro',
    builder => '_build_cachefolder',
    lazy    => 1,
);

sub _build_cachefolder {
    my $self = shift;
    require Actium::O::Folder;
    return Actium::O::Folder::->new($DEFAULT_CACHE_FOLDER);
}

has _ss_cache_r => (
    traits   => ['Hash'],
    is       => 'ro',
    init_arg => undef,
    isa      => 'HashRef[HashRef]',
    handles  => { ss => 'get', },
    builder  => '_build_ss_cache',
    lazy     => 1,
);

sub _build_ss_cache {
    my $self   = shift;
    my $folder = $self->cachefolder;

    my $do_reload = 1;
    my ( $savedtime, $cache_r );

    if ( -e ( $folder->make_filespec($SS_CACHE_FNAME) ) ) {
        ( $savedtime, $cache_r )
          = @{ $folder->retrieve($SS_CACHE_FNAME) };
        if ( $savedtime + $CACHE_TIME_TO_LIVE >= time ) {
            $do_reload = 0;
        }

    }

    if ($do_reload) {

        $cache_r   = $self->_reload_ss_cache;
        $savedtime = time;
        $folder->store( [ $savedtime, $cache_r ], $SS_CACHE_FNAME );
    }

    return $cache_r;

} ## tidy end: sub _build_ss_cache

sub _reload_ss_cache {
    my $self = shift;
    my $dbh  = $self->dbh;

    my $cache_r = $self->all_in_columns_key( $SS_TABLE, @SS_COLUMNS );

    # This makes all the Hastus IDs keys in the cache, as well as the 511 IDs.
    # At this point there can't be conflicts (since they have different
    # formats), and it's easier to put them all together this way
    # than to have two separate caches.

    foreach my $row ( values %{$cache_r} ) {
        $cache_r->{ $row->{h_stp_identifier} } = $row;
    }

    return $cache_r;

}

sub search_ss {
    my $self       = shift;
    my $argument   = shift;
    my $ss_cache_r = $self->_ss_cache_r;

    if (/\A\d{5,8}\z/) {
        return ( $ss_cache_r->{$argument} // $argument );
    }

    if (/\A\d{6}\z/) {
        return ( $ss_cache_r->{"0$argument"} // $argument );
    }
    
    my %row_of_stopid;
    # saving in hash avoids duplicate entries
    # (because rows saved twice, once under Hastus ID, once under 511 ID)

    foreach my $fields_r ( values %{$ss_cache_r} ) {
        
        my $stopid = $fields_r->{h_stp_511_id};
        next if $row_of_stopid{$stopid};

        my $desc = $fields_r->{c_description_full};

        $argument =~ s{/}{.*}g;
        # slash is easier to type, doesn't need to be quoted,
        # not a regexp char normally, not usually found in descriptions
        $row_of_stopid{$stopid} = $fields_r
          if $desc =~ m{$argument}i;

    }

    return values %row_of_stopid;

} ## tidy end: sub search_ss

with 'Actium::O::Files::FileMaker_ODBC';

1;

__END__




1;

__END__
