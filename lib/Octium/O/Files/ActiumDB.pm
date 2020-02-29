package Octium::O::Files::ActiumDB 0.013;

# Class holding routines related to the Actium database
# (the FileMaker database used by Actium users), accessed
# thorugh ODBC.

use Actium ('class');
use Octium;
use Hash::Util();
use Params::Validate;

const my $KEYFIELD_TABLE          => 'FMTableKeys';
const my $KEY_OF_KEYFIELD_TABLE   => 'FMTableKey';
const my $TABLE_OF_KEYFIELD_TABLE => 'FMTable';

const my $IDT => 'Octium::Text::InDesignTags';

const my @ALL_LANGUAGES => qw/en es zh/;

const my $DEFAULT_AGENCY => 'ACTransit';

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
    my %keys_of = Octium::flatten($rows_r);

    return \%keys_of;

    # copy of returned hashref

}

##############################
### CACHED TABLES

# commented out ones are just things I haven't used yet

const my %TABLE_OF_ITEM => (
    agency      => 'Agencies',
    agency_abbr => undef,
    line        => 'Lines',
    i18n        => 'I18N',
    city        => 'Cities',
    color       => 'Colors',
    #flagtype => 'Flagtypes',
    linegrouptype => 'LineGroupTypes',
    #pubtimetable => 'PubTimetables',
    #signtype => 'SignTypes',
    transithub => 'TransitHubs',
    place      => 'Places_Neue',
    sign       => 'Signs',
    #ssj        => 'Signs_Stops_Join',
    stop => 'Stops_Neue',
);

foreach my $item ( keys %TABLE_OF_ITEM ) {
    my $table = $TABLE_OF_ITEM{$item};

    has "_${item}_cache_r" => (
        traits   => ['Hash'],
        is       => 'bare',
        init_arg => undef,
        isa      => 'HashRef[HashRef]',
        handles  => {
            "${item}_row_r"  => 'get',
            "${item}_exists" => 'exists',
            "${item}_keys"   => 'keys',
            "${item}_cache"  => 'elements',
        },
        builder => "_build_${item}_cache",
        lazy    => 1,
    );

}

sub _build_table_cache {
    my $self    = shift;
    my $item    = shift;
    my $table   = $TABLE_OF_ITEM{$item};
    my @columns = @_;

    my $dbh = $self->dbh;

    my $cache_r = $self->all_in_columns_key(
        {   TABLE   => $table,
            COLUMNS => \@columns,
        }
    );

    Hash::Util::lock_hashref_recurse($cache_r);
    return $cache_r;
}

sub _build_sign_cache {
    my $self    = shift;
    my $cache_r = $self->_build_table_cache(
        'sign',
        qw/
          SignID Active stp_511_id Status SignType Cluster Sidenote
          Agency ShelterNum NonStopLocation NonStopCity
          Delivery City TIDFile CopyQuantity
          /
    );
}

sub _build_city_cache {
    my $self = shift;
    my $cache_r = $self->_build_table_cache( 'city', qw[City SmokingText ] );
}

sub _build_stop_cache {
    my $self    = shift;
    my $cache_r = $self->_build_table_cache(
        'stop',
        qw[h_stp_511_id c_city c_description_full
          c_description_nocity u_work_zone]
          # these are just the ones used in bpoints.
          # We may need more later
    );
}

sub _build_i18n_cache {
    my $self = shift;
    my $cache_r = $self->_build_table_cache( 'i18n', qw(en es zh), );
}

sub _build_color_cache {
    my $self    = shift;
    my $cache_r = $self->_build_table_cache(
        'color', qw(
          ColorID RGB Cyan Magenta Yellow Black Red Green Blue
          ),
    );
}

sub _build_agency_cache {
    my $self = shift;
    return $self->_build_table_cache(
        'agency',
        qw(
          agency_id            agency_lang
          agency_linemap_url   agency_url          agency_abbr
          agency_linesked_url  agency_mapversion   agency_name
          agency_phone         agency_timezone
          agency_fare_url      agency_effective_date
          )
    );
}

sub _build_agency_abbr_cache {
    my $self         = shift;
    my %agency_cache = $self->agency_cache;
    my %agency_abbr_cache;
    foreach my $agency_id ( keys %agency_cache ) {
        my $abbr = $agency_cache{$agency_id}{agency_abbr};
        $agency_abbr_cache{$abbr} = $agency_cache{$agency_id};
    }

    return \%agency_abbr_cache;

}

sub _build_linegrouptype_cache {
    my $self = shift;
    return $self->_build_table_cache( 'linegrouptype', 'LineGroupType',
        'SortValue', 'RGBHex', );
}

sub _build_transithub_cache {
    my $self = shift;
    return $self->_build_table_cache( 'transithub', qw<City Name ShortName> );
}

sub _build_line_cache {
    my $self    = shift;
    my $dbh     = $self->dbh;
    my $cache_r = $self->all_in_columns_key(
        {   TABLE   => 'Lines',
            COLUMNS => [
                qw(
                  agency_id      Color     Description
                  GovDeliveryTopic        PubTimetable
                  LineGroupType           LineGroup
                  TimetableDate           NoLocalsOnTransbay
                  TransitHubs
                  )
            ],
            WHERE       => 'Active = ?',
            BIND_VALUES => ['Yes'],
        }
    );

    return $cache_r;
}    ## tidy end: sub _build_line_cache

sub _build_place_cache {
    my $self = shift;
    return $self->_build_table_cache(
        'place',
        qw(h_plc_identifier c_description c_destination
          h_plc_reference_place h_plc_number c_city
          ux_usecity_description
          )
    );

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
    isa     => 'Octium::O::Folder',
    is      => 'ro',
    builder => '_build_cachefolder',
    lazy    => 1,
);

sub _build_cachefolder {
    my $self = shift;
    require Octium::O::Folder;
    return Octium::O::Folder::->new($DEFAULT_CACHE_FOLDER);
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

}    ## tidy end: sub _build_ss_cache

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

}    ## tidy end: sub search_ss

const my $MAXIMUM_VALID_DISTANCE => 1320;

sub ss_nearest_stop {

    require Octium::Geo;

    my ( $self, $lat, $long ) = @_;

    my $cache_r = $self->_ss_cache_r;

    my $nearest_dist = $MAXIMUM_VALID_DISTANCE;
    my $nearest;

    foreach \my %stop_data ( values %{$cache_r} ) {

        my $stoplat  = $stop_data{h_loca_latitude};
        my $stoplong = $stop_data{h_loca_longitude};

        my $dist
          = Octium::Geo::distance_feet( $lat, $long, $stoplat, $stoplong );

        if ( $dist < $nearest_dist ) {
            $nearest      = \%stop_data;
            $nearest_dist = $dist;
        }

    }

    return $nearest if $nearest;
    return;

}    ## tidy end: sub ss_nearest_stop

#########################
### I18N METHODS

sub i18n_all {
    my $self    = shift;
    my $i18n_id = shift;

    state $i18n_all_cache_r = {};

    return @{ $i18n_all_cache_r->{$i18n_id} }
      if exists $i18n_all_cache_r->{$i18n_id};

    my $i18n_row_r = $self->i18n_row_r($i18n_id);

    my $all_r = [ @{$i18n_row_r}{@ALL_LANGUAGES} ];

    s/\s+\z// foreach ( @{$all_r} );

    $i18n_all_cache_r->{$i18n_id} = $all_r;
    return @{$all_r};

}

sub i18n_all_indd {
    my $self    = shift;
    my $i18n_id = shift;

    my $metastyle = shift;

    state $i18n_all_cache_r = {};
    return @{ $i18n_all_cache_r->{$i18n_id} }
      if exists $i18n_all_cache_r->{$i18n_id};

    my $i18n_row_r = $self->i18n_row_r($i18n_id);

    require Octium::Text::InDesignTags;

    my $all_r;
    foreach my $language (@ALL_LANGUAGES) {
        my $phrase = $i18n_row_r->{$language};
        $phrase
          = Octium::Text::InDesignTags::->language_phrase( $language,
            $phrase, $metastyle );
        $phrase =~ s/\s+\z//;
        push @{$all_r}, $phrase;
    }

    $i18n_all_cache_r->{$i18n_id} = $all_r;
    return @{$all_r};

}    ## tidy end: sub i18n_all_indd

sub i18n_all_indd_hash {
    my $self    = shift;
    my $i18n_id = shift;

    my $metastyle = shift;

    state $i18n_all_cache_r = {};
    return %{ $i18n_all_cache_r->{$i18n_id} }
      if exists $i18n_all_cache_r->{$i18n_id};

    my $i18n_row_r = $self->i18n_row_r($i18n_id);

    require Octium::Text::InDesignTags;

    my $all_r;
    foreach my $language (@ALL_LANGUAGES) {
        my $phrase = $i18n_row_r->{$i18n_id}{$language};
        $phrase
          = Octium::Text::InDesignTags::->language_phrase( $language,
            $phrase, $metastyle );
        $phrase =~ s/\s+\z//;
        $all_r->{$language} = $phrase;
    }

    $i18n_all_cache_r->{$i18n_id} = $all_r;
    return %{$all_r};

}    ## tidy end: sub i18n_all_indd_hash

#########################
### PLACE METHODS

sub field_of_referenced_place {
    my $self = shift;

    my %params = validate(
        @_,
        {   field => 1,
            place => 1,
        }
    );

    my $row_r = $self->place_row_r( $params{place} );
    while ( $row_r->{h_plc_reference_place}
        and $row_r->{h_plc_reference_place} ne $params{place} )
    {
        $row_r = $self->place_row_r( $row_r->{h_plc_reference_place} );
        return unless $row_r;
    }
    return $row_r->{ $params{field} };
}

sub dereference_place {
    my $self  = shift;
    my $place = shift;
    return $place unless $place;
    my $deref_place = $self->field_of_referenced_place(
        field => 'h_plc_identifier',
        place => $place,
    );
    return $deref_place || $place;
}

sub place8 {
    my $self   = shift;
    my $place  = shift;
    my $place8 = $self->field_of_referenced_place(
        field => 'h_plc_number',
        place => $place,
    );
    return $place8;
}

sub destination {
    my $self        = shift;
    my $place       = shift;
    my $destination = $self->field_of_referenced_place(
        field => 'c_destination',
        place => $place,
    );
    return $destination;
}

method destination_or_warn ($tp4) {
    if ( $self->place_exists($tp4) ) {
        return $self->destination($tp4);
    }
    else {
        last_cry()->text("No timepoint found for $tp4");
        return $tp4;
    }
}

#########################
### LINEGROUPTYPE METHODS

sub linegrouptypes_in_order {
    my $self     = shift;
    my %lg_cache = $self->linegrouptype_cache;

    my %sortvalue_of
      = map { $_->{LineGroupType}, $_->{SortValue} } values %lg_cache;
    return sort { $sortvalue_of{$a} <=> $sortvalue_of{$b} } keys %sortvalue_of;

}

#########################
### AGENCY METHODS

sub agency_or_abbr_row {
    my $self = shift;
    my $name = shift;

    if ( $self->agency_exists($name) ) {
        my $row_r = $self->agency_row_r($name);
        return ( $name, $row_r->{agency_abbr}, $row_r );
    }

    if ( $self->agency_abbr_exists($name) ) {
        my $row_r = $self->agency_abbr_row_r($name);
        return ( $row_r->{agency_id}, $name, $row_r );
    }

    return;

}

my $url_make_cr = sub {

    my $self  = shift;
    my $line  = shift;
    my $field = shift;

    my $line_row_r = $self->line_row_r($line);

    my $agency = $line_row_r->{agency_id};

    croak "agency_id field undefined " . qq{in "$line" record in Lines table}
      if not defined $agency;

    my $agency_row_r = $self->agency_row_r($agency);
    my $version      = $agency_row_r->{agency_mapversion};
    my $url          = $agency_row_r->{$field};

    if ( $url =~ m/ \[ actium_version \] /x ) {

        croak "agency_mapversion field undefined "
          . qq{in "$agency" record in Agencies table}
          if not defined $version;

        croak qq{agency_mapversion field "$version" }
          . qq{must not be empty or all spaces }
          . qq{in "$agency" record in Agencies table}
          if $version =~ /\A\s*\z/;

        $url =~ s/ \[ actium_version \] /$version/sx;

    }

    $url =~ s/ \[ actium_line \] /$line/sx;

    return $url;

};

sub linemap_url {
    my $self = shift;
    my $line = shift;
    return $url_make_cr->( $self, $line, 'agency_linemap_url' );
}

sub linesked_url {
    my $self = shift;
    my $line = shift;
    return $url_make_cr->( $self, $line, 'agency_linesked_url' );
}

method effective_date (
       Str :$agency = $DEFAULT_AGENCY,
       :@lines is ref_alias = [],
    ) {

    my %line_cache = $self->line_cache;

    my @dates;

    if (@lines) {
        @dates = map { $line_cache{$_}{TimetableDate} } @lines;
    }
    else {
        my $agency_row_r = $self->agency_row_r($agency);
        @lines
          = grep { $line_cache{$_}{agency_id} eq $agency } keys %line_cache;

        @dates = (
            ( map { $line_cache{$_}{TimetableDate} } @lines ),
            $agency_row_r->{agency_effective_date}
        );
    }

    require Octium::O::DateTime;
    return Octium::O::DateTime->newest_date(@dates);

}    ## tidy end: method effective_date

sub date_i18n_texts_hash {
    my $self    = shift;
    my $dt      = shift;
    my $i18n_id = shift;

    my $i18n_row_r = $self->i18n_row_r($i18n_id);

    my %text_of;

    foreach my $lang (qw(en es zh)) {
        my $text   = $i18n_row_r->{$lang};
        my $method = "long_$lang";
        my $date   = $dt->$method;
        $text =~ s/\%s/$date/;
        $text_of{$lang} = $text;
    }

    return \%text_of;

}    ## tidy end: sub date_i18n_texts_hash

#########################
### LINES ATTRIBUTES

has _lines_of_linegrouptype_r => (
    traits   => ['Hash'],
    is       => 'bare',
    init_arg => undef,
    isa      => 'HashRef[ArrayRef[Str]]',
    builder  => '_build_lines_of_linegrouptype',
    handles  => { _lines_of_linegrouptype_r => 'get' },
    lazy     => 1,
);

sub lines {
    my $self = shift;
    return $self->line_keys;
}

sub _lines_of_linegrouptype {
    my $self          = shift;
    my $linegrouptype = shift;
    return @{ $self->_lines_of_linegrouptype_r($linegrouptype) };
}

sub _build_lines_of_linegrouptype {
    my $self = shift;

    my %lines_of_linegrouptype;

    foreach my $line ( $self->lines ) {
        my $line_row_r    = $self->line_row_r($line);
        my $linegrouptype = $line_row_r->{LineGroupType};
        push @{ $lines_of_linegrouptype{$linegrouptype} }, $line;
    }

    foreach my $linegrouptype ( keys %lines_of_linegrouptype ) {

        $lines_of_linegrouptype{$linegrouptype}
          = [ Actium::sortbyline @{ $lines_of_linegrouptype{$linegrouptype} } ];

    }

    return \%lines_of_linegrouptype;

}    ## tidy end: sub _build_lines_of_linegrouptype

const my $FALLBACK_COLOR => 'Grey80';

method color_of_line ($line) {
    return $FALLBACK_COLOR unless $self->line_exists($line);
    \my %attribute_of_line = $self->line_row_r($line);
    return $FALLBACK_COLOR unless $attribute_of_line{Color};
    return $attribute_of_line{Color};
}

##############################
### TRANSIT HUBS ATTRIBUTES

sub transithubs {
    my $self = shift;
    return $self->transithub_keys;
}

has _transithubs_of_city_r => (
    traits   => ['Hash'],
    is       => 'bare',
    init_arg => undef,
    isa      => 'HashRef[ArrayRef]',
    handles => { _transithubs_of_city_r => 'get', transithub_cities => 'keys' },
    builder => '_build_transithubs_of_city',
    lazy    => 1,
);

sub _transithubs_of_city {
    my $self = shift;
    my $city = shift;
    return @{ $self->_transithubs_of_city_r($city) };
}

sub _build_transithubs_of_city {
    my $self = shift;

    my %transithubs_of_city;
    foreach my $transithub ( $self->transithubs ) {
        my $city = $self->transithub_row_r($transithub)->{City};
        push @{ $transithubs_of_city{$city} }, $transithub;
    }

    return \%transithubs_of_city;

}

has _lines_of_transithub_r => (
    traits   => ['Hash'],
    is       => 'bare',
    init_arg => undef,
    isa      => 'HashRef[ArrayRef]',
    handles  => { _lines_of_transithub_r => 'get' },
    builder  => '_build_lines_of_transithub',
    lazy     => 1,
);

sub _lines_of_transithub {
    my $self   = shift;
    my $hub    = shift;
    my $hubs_r = $self->_lines_of_transithub_r($hub) // [];
    return @{$hubs_r};
}

sub _build_lines_of_transithub {
    my $self = shift;

    my %lines_of_transithub;

    foreach my $line ( $self->lines ) {
        my $transithubs_field = $self->line_row_r($line)->{TransitHubs};
        next unless $transithubs_field;
        my @transithubs
          = split( /\r/, $transithubs_field );    # check - is \r correct?
        foreach my $transithub (@transithubs) {
            push @{ $lines_of_transithub{$transithub} }, $line;
        }

    }

    return \%lines_of_transithub;
}

# $x->{Hubname}{line} = description

has _line_descrips_of_transithubs_r => (
    traits   => ['Hash'],
    isa      => 'HashRef[HashRef[Str]]',
    init_arg => undef,
    is       => 'bare',
    handles  => { _line_descrips_of_transithub_r => 'get' },
    builder  => '_build_line_descrips_of_transithub',
    lazy     => 1,
);

sub line_descrips_of_transithub {
    my $self       = shift;
    my $hub        = shift;
    my $descrips_r = $self->_line_descrips_of_transithub_r($hub) // {};
    return %{$descrips_r};

}

sub _build_line_descrips_of_transithub {
    my $self = shift;

    my %line_descrips_of_transithub;
    foreach my $transithub ( $self->transithubs ) {
        my @lines = $self->_lines_of_transithub($transithub);
        foreach my $line (@lines) {
            next if $line =~ /4\d\d/;
            my $desc = ${ $self->line_row_r($line) }{Description};
            $line_descrips_of_transithub{$transithub}{$line} = $desc;
        }
    }

    return \%line_descrips_of_transithub;

}

######################################
#### LINE DESCRIPTIONS OF TRANSIT HUBS

sub descrips_of_transithubs_indesign {
    my $self = shift;

    my %params = validate( @_, { signup => 1, } );
    my $signup = $params{signup};

    my %line_cache = $self->line_cache;

    require Octium::Text::InDesignTags;
    my %descrips_of_hubs;

    foreach my $transithub ( $self->transithubs ) {

        my %descrip_of = $self->line_descrips_of_transithub($transithub);

        my @descrip_texts;
        my @lines_of_hub;

        foreach my $line ( Actium::sortbyline keys %descrip_of ) {
            push @lines_of_hub, $line;
            my $descrip = $descrip_of{$line};

            push @descrip_texts,
              Actium::joinempty(
                $IDT->parastyle('LineDescrip_Line'),
                $IDT->encode_high_chars($line),
                $IDT->hardreturn,
                $IDT->parastyle('LineDescrip_Descrip'),
                $IDT->encode_high_chars($descrip)
              );

        }

        next unless @lines_of_hub;

        my $effdate_obj = $self->effective_date();

        my $effdate = $effdate_obj->long_en;

        $descrips_of_hubs{$transithub} = Actium::joinempty(
            $IDT->start,
            $IDT->parastyle('LineDescrip_TitleLine'),
            $IDT->charstyle('LineDescrip_Title'),
            'Line Descriptions',
            $IDT->nocharstyle,
            ' Effective ',
            join( $IDT->hardreturn, $effdate, @descrip_texts ),
        );

    }    ## tidy end: foreach my $transithub ( $self...)

    return \%descrips_of_hubs;

}    ## tidy end: sub descrips_of_transithubs_indesign

#########################
### TRANSIT HUBS HTML OUTPUT

sub lines_at_transit_hubs_html {
    my $self = shift;

    my $text = "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->\n";

    foreach my $city ( sort $self->transithub_cities ) {

        my $citytext  = $EMPTY;
        my $skip_city = 1;        # skip city unless we see some lines

        $citytext
          .= qq{<h3>$city</h3>\n}
          . qq{<table width="100%" }
          . qq{cellspacing=0 style="border-collapse:collapse;" }
          . qq{cellpadding=4 border="0">};

        foreach my $hub ( sort $self->_transithubs_of_city($city) ) {

            my @lines = Actium::sortbyline( $self->_lines_of_transithub($hub) );

            next unless @lines;

            $skip_city = 0;    # we saw some lines, don't skip city
            my $hub_name = $self->transithub_row_r($hub)->{Name};

            $citytext
              .= qq{<tr><td width='30%' style="vertical-align: middle; text-align: right;">}
              . qq{$hub_name</td><td width='2%' style="vertical-align:middle;">&bull;</td>};

            my @displaylines;
            foreach my $line (@lines) {
                if ( $line =~ /4[0-9][0-9]/ ) {
                    push @displaylines,
                      qq{<a href="http://actransit.org/flex/">Flex</a>};
                    next;
                }

                push @displaylines,
                  qq{<a href="} . $self->linesked_url($line) . qq{">$line</a>};
            }

            $citytext
              .= '<td style="vertical-align:middle;">'
              . join( "&nbsp;&middot; ", @displaylines )
              . "</td></tr>\n";

        }    ## tidy end: foreach my $hub ( sort $self...)

        if ( not $skip_city ) {
            $text .= "$citytext</table>\n";
        }

    }    ## tidy end: foreach my $city ( sort $self...)

    return $text;

}    ## tidy end: sub lines_at_transit_hubs_html

#######################
### LINES HTML OUTPUT

sub line_descrip_html {

    require HTML::Entities;    ### DEP ###

    my $self = shift;

    my %params = validate( @_,
        { signup => 1, agency => { default => $DEFAULT_AGENCY } } );

    my $signup = $params{signup};

    my $effdate = $self->effective_date()->long_en;

    my $html
      = "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->"
      . _ldh_header($effdate);

    my $total = 0;

    foreach my $linegrouptype (
        qw/ Local Transbay
        /, 'Early Bird', 'All Nighter', 'Service to Schools'
      )
    {

        my @lines = $self->_lines_of_linegrouptype($linegrouptype);

        # heading
        my $count  = scalar @lines;
        my $pub    = "$linegrouptype Lines";
        my $anchor = $linegrouptype =~ s/ /_/gr;
        #= $linegrouptype eq 'All Nighter' ? 'AllNighter' : $linegrouptype;

        $html
          .= qq{<table style="border-collapse: collapse;" border="1">}
          . qq{<caption style="padding-top: 1.2em;"><strong><a name="$anchor">}
          . qq{$pub</a></strong></caption>};

        $html
          .= '<thead><tr><th style="background-color: silver;">Line</th>'
          . '<th style="background-color: silver;">Description</th>';

        $html
          .= "\n" . '<th style="background-color: silver;">Links</th></thead>';

        $html .= '<tbody>';

        foreach my $line (@lines) {
            my $desc = HTML::Entities::encode_entities(
                ${ $self->line_row_r($line) }{Description} );

            my $mapurl  = $self->linemap_url($line);
            my $skedurl = $self->linesked_url($line);

            $html
              .= qq{<tr><td style="text-align: center;vertical-align:middle;">$line</td>};
            $html .= qq{<td style="padding: 2pt;">$desc</td>};
            $html .= '<td style="text-align: center;">';
            $html .= qq{<a href="$mapurl">Map</a>};

#qq{<a href="http://www.actransit.org/maps/maps_results.php?ms_view_type=2&maps_line=$line&version_id=$current_version&map_submit=Get+Map">Map</a>};
            $html .= "<br>";
            $html .= qq{<a href="$skedurl">Schedule</a>};

#qq{<a href="http://www.actransit.org/maps/schedule_results.php?quick_line=$line&Go=Go">Schedule</a>};
            $html .= '</td></tr>' . "\n";

        }    ## tidy end: foreach my $line (@lines)

        $html .= '</tbody></table>' . "\n";
        $html .= "<p>($linegrouptype lines: $count)</p>\n";

        $total += $count;

    }    ## tidy end: foreach my $linegrouptype (...)

    $html .= "<p>(Total lines: $total)</p>\n";

    $html .= _ldh_footer();

    return $html;

}    ## tidy end: sub line_descrip_html

sub _ldh_footer {

    my $footer = <<'EOF';
  <p> <strong>Find <a href="http://www.actransit.org/maps/index.php">maps 
    &amp; schedules</a> for these lines.</strong> Or call (510) 891-4777 
    for trip-planning assistance.</p>
EOF

    $footer =~ s/\n/ /g;
    $footer =~ s/ +/ /g;

    return $footer;

}

sub _ldh_header {

    my $effdate = shift;

    my $header = <<"EOF";
<p>Effective $effdate</p>

<h2>About Bus Line Numbers and Letters</h2>

<p>AC Transit's numbered lines serve the East Bay. </p>

<p>Lines 1&ndash;299 operate normal hours. Normal hours are, at a minimum,
the commute periods, 6 a.m.&ndash;9 a.m. and 4 p.m.&ndash;6 p.m., weekdays.
Almost all operate all day on weekdays and many operate weekday
evenings and weekends as well. Lines 200&ndash;299 serve the areas of
Fremont and Newark, while other lines serve other parts of the East
Bay from Richmond to Hayward.</p>

<p>Lines 300&ndash;399 do not operate during the commute period. They
operate at other times of the day: for example, mid-days only,
weekends only, or evenings only. Some lines operate only a few days
per week (for example, Tuesdays and Thursdays).</p>

<p>Lines 600&ndash;699 are timed to match the instruction hours of local
schools, and operate only when schools are in session. They may
have altered schedules when local schools have minimum day or
alternative schedules. These lines are open to all passengers at
regular fares.</p>

<p>Lines 700&ndash;799 are Early Bird Express lines, operating from 5 a.m.&ndash;6
a.m. daily, due to a shift in early morning service on BART. See
<a href="http://www.bart.gov/earlybirdexpress">
bart.gov/earlybirdexpress</a> for more information.
.</p>

<p>Lines 800&ndash;899 are All Nighter lines, operating from 1 a.m.&ndash;5
a.m. daily. Some may operate somewhat earlier or later (especially
on weekends).</p>

<p>Lettered lines (A&ndash;Z) are Transbay routes, connecting the East
Bay to San Francisco or the Peninsula.</p>

<hr/>

<p><strong>Go to the <a href="http://www.actransit.org/maps/index.php">Maps &amp; Schedules</a> page.
</strong></p>

  <p > 
  <a href="#Local">Local Lines</a><br>
  <a href="#Transbay">Transbay Lines</a><br>
  <a href="#Early_Bird">Early Bird Lines</a><br>
  <a href="#All_Nighter">All Nighter Lines</a> <br>
  <a href="#Service_to_Schools">Service to Schools Lines</a><br>
</p>

<hr>
EOF

    $header =~ s/\n/ /g;
    $header =~ s/ +/ /g;

    return $header;

}    ## tidy end: sub _ldh_header

with 'Octium::O::Files::FileMaker_ODBC';

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

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

