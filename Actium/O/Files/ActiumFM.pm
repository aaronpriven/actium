# Actium/O/Files/ActiumDB.pm

# Class holding routines related to the Actium database
# (the FileMaker database used by Actium users), accessed
# thorugh ODBC.

# Subversion: $Id$

# Legacy stage 4

package Actium::O::Files::ActiumFM 0.008;

use Actium::Moose;
use Actium::Sorting::Line('sortbyline');

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

    my $query =
"SELECT $TABLE_OF_KEYFIELD_TABLE, $KEY_OF_KEYFIELD_TABLE FROM $KEYFIELD_TABLE";
    my $rows_r  = $dbh->selectall_arrayref($query);
    my %keys_of = flatten($rows_r);

    return \%keys_of;

    # copy of returned hashref

}

##############################
### CACHED TABLES

# commented out ones are just things I haven't used yet

my %table_of_item = (
    agency => 'Agencies',
    line   => 'Lines',

    #city => 'Cities',
    #color => 'Colors',
    #flagtype => 'Flagtypes',
    #pubtimetable => 'PubTimetables',
    #signtype => 'SignTypes',
    transithub => 'TransitHubs',
);

foreach my $item ( keys %table_of_item ) {
    my $table = $table_of_item{$item};

    has "_${item}_cache_r" => (
        traits   => ['Hash'],
        is       => 'bare',
        init_arg => undef,
        isa      => 'HashRef[HashRef]',
        handles  => { "${item}_row_r" => 'get', lc($table) => 'keys' },
        builder  => "_build_${item}_cache",
        lazy     => 1,
    );

}

sub _build_table_cache {
    my $self    = shift;
    my $item    = shift;
    my $table   = $table_of_item{$item};
    my @columns = @_;

    my $dbh = $self->dbh;

    my $cache_r = $self->all_in_columns_key(
        {
            TABLE   => $table,
            COLUMNS => \@columns,
        }
    );
    return $cache_r;
}

sub _build_agency_cache {
    my $self = shift;
    return $self->_build_table_cache(
        'agency',
        qw(
          agency_fare_url      agency_id           agency_lang
          agency_linemap_url   agency_url
          agency_linesked_url  agency_mapversion   agency_name
          agency_phone         agency_timezone
          )
    );
}

sub _build_transithub_cache {
    my $self = shift;
    return $self->_build_table_cache( 'transithub', qw<City Name ShortName> );
}

sub _build_line_cache {
    my $self    = shift;
    my $dbh     = $self->dbh;
    my $cache_r = $self->all_in_columns_key(
        {
            TABLE   => 'Lines',
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
        ( $savedtime, $cache_r ) =
          @{ $folder->retrieve($SS_CACHE_FNAME) };
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

#########################
### AGENCY METHODS

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

        $lines_of_linegrouptype{$linegrouptype} =
          [ sortbyline @{ $lines_of_linegrouptype{$linegrouptype} } ];

    }

    return \%lines_of_linegrouptype;

}

##############################
### TRANSIT HUBS ATTRIBUTES

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
    my $self = shift;
    my $hub  = shift;
    return @{ $self->_lines_of_transithub_r($hub) };
}

sub _build_lines_of_transithub {
    my $self = shift;

    my %lines_of_transithub;

    foreach my $line ( $self->lines ) {
        my $transithubs_field = $self->line_row_r($line)->{TransitHubs};
        next unless $transithubs_field;
        my @transithubs =
          split( /\r/, $transithubs_field );    # check - is \r correct?
        foreach my $transithub (@transithubs) {
            push @{ $lines_of_transithub{$transithub} }, $line;
        }

    }

    return \%lines_of_transithub;
}

#########################
### TRANSIT HUBS HTML OUTPUT

sub lines_at_transit_hubs_html {
    my $self = shift;

    my $text = "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->\n";

    foreach my $city ( sort $self->transithub_cities ) {
        $text .=
            qq{<h3>$city</h3>\n}
          . qq{<table width="100%" }
          . qq{cellspacing=0 style="border-collapse:collapse;" }
          . qq{cellpadding=4 border="0">};

        foreach my $hub ( sort $self->_transithubs_of_city($city) ) {

            my $hub_name = $self->transithub_row_r($hub)->{Name};
            $text .=
qq{<tr><td width='30%' style="vertical-align: middle; text-align: right;">}
              . qq{$hub_name</td><td width='2%' style="vertical-align:middle;">&bull;</td>};

            my @lines = sortbyline( $self->_lines_of_transithub($hub) );

            next unless @lines;

            my @displaylines;
            foreach my $line (@lines) {

                push @displaylines,
                  qq{<a href="} . $self->linesked_url($line) . qq{">$line</a>};
            }

            $text .=
                '<td style="vertical-align:middle;">'
              . join( "&nbsp;&middot; ", @displaylines )
              . "</td></tr>\n";

        }

        $text .= "</table>\n";

    }

    return $text;

}

#######################
### LINES HTML OUTPUT

sub line_descrip_html {

    require HTML::Entities;
    require Actium::EffectiveDate;

    my $self = shift;

    my %params = validate(
        @_,
        {
            signup => 1,
        }
    );

    my $signup = $params{signup};

    my $effdate = Actium::EffectiveDate::effectivedate($signup);

    my $html =
        "\n<!--\n    Do not edit this file! "
      . "It is automatically generated from a program.\n-->"
      . _ldh_header($effdate);

    my $total = 0;

    foreach my $linegrouptype (
        qw/ Local Transbay
        /, 'All Nighter', 'Supplementary'
      )
    {

        my @lines = $self->_lines_of_linegrouptype($linegrouptype);

        # heading
        my $count = scalar @lines;
        my $pub   = "$linegrouptype Lines";
        my $anchor =
          $linegrouptype eq 'All Nighter' ? 'AllNighter' : $linegrouptype;

        $html .=
            qq{<table style="border-collapse: collapse;" border="1">}
          . qq{<caption style="padding-top: 1.2em;"><strong><a name="$anchor">}
          . qq{$pub</a></strong></caption>};

        $html .=
            '<thead><tr><th style="background-color: silver;">Line</th>'
          . '<th style="background-color: silver;">Description</th>';

        $html .=
          "\n" . '<th style="background-color: silver;">Links</th></thead>';

        $html .= '<tbody>';

        foreach my $line (@lines) {
            my $desc = HTML::Entities::encode_entities(
                ${ $self->line_row_r($line) }{Description} );

            my $mapurl  = $self->linemap_url($line);
            my $skedurl = $self->linesked_url($line);

            $html .=
qq{<tr><td style="text-align: center;vertical-align:middle;">$line</td>};
            $html .= qq{<td style="padding: 2pt;">$desc</td>};
            $html .= '<td style="text-align: center;">';
            $html .= qq{<a href="$mapurl">Map</a>};

#qq{<a href="http://www.actransit.org/maps/maps_results.php?ms_view_type=2&maps_line=$line&version_id=$current_version&map_submit=Get+Map">Map</a>};
            $html .= "<br>";
            $html .= qq{<a href="$skedurl">Schedule</a>};

#qq{<a href="http://www.actransit.org/maps/schedule_results.php?quick_line=$line&Go=Go">Schedule</a>};
            $html .= '</td></tr>' . "\n";

        }

        $html .= '</tbody></table>' . "\n";
        $html .= "<p>($linegrouptype lines: $count)</p>\n";

        $total += $count;

    }    ## tidy end: foreach my $linegrouptype ( qw/Local Transbay/...)

    $html .= "<p>(Total lines: $total)</p>\n";

    $html .= _ldh_footer();

    return $html;

}    ## tidy end: sub line_descrip_html

sub _ldh_footer {

    my $footer = <<'EOF';
  <p> <strong>Find <a href="http://www.actransit.org/maps/index.php">maps 
    &amp; schedules</a> for these lines.</strong> Or call 511 and say 
    &quot;AC Transit&quot; for trip-planning assistance.</p>
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
  <a href="#AllNighter">All Nighter Lines</a> <br>
  <a href="#Supplementary">Supplementary Lines</a><br>
</p>

<hr>
EOF

    $header =~ s/\n/ /g;
    $header =~ s/ +/ /g;

    return $header;

}    ## tidy end: sub _ldh_header

with 'Actium::O::Files::FileMaker_ODBC';

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion)

1;

__END__


