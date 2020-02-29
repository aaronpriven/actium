package Octium::Cmd::Flagspecs 0.014;

use Actium;
use Octium;
use Octium::Set (qw/ordered_union distinguish/);
use Octium::DaysDirections(':all');
use Octium::O::Files::HastusASI;
use Octium::Crier(qw/cry cry_text/);

use Text::Wrap ('wrap');    ### DEP ###
use List::MoreUtils(qw/any uniq/);    ### DEP ###
use File::Spec;                       ### DEP ###
use Text::Trim;                       ### DEP ###

use DDP;

const my $NEW_KEY_SEPARATOR => '_';

sub OPTIONS {
    return qw/actiumdb signup/;
}

sub sk {
    croak 'Null argument specified to ' . __PACKAGE__ . '::sk'
      unless defined $_[0];
    return split( /$NEW_KEY_SEPARATOR/sx, $_[0] );
}

sub jk {
    return join( $NEW_KEY_SEPARATOR, map { $_ // $EMPTY } @_ );
}

sub keyreadable {
    if (wantarray) {
        my @list = @_;
        return @list;
    }
    my $value = shift;
    return $value;
}

const my $CULL_THRESHOLD          => 10;
const my $OVERRIDE_FILENAME       => 'flagspec_override.txt';
const my $TP_OVERRIDE_FILENAME    => 'flagspec_tp_override.txt';
const my $PLAIN_OVERRIDE_FILENAME => 'plain_override.txt';
const my $STOP_SPEC_FILENAME      => 'stop-decals.txt';
const my $DECAL_SPEC_FILENAME     => 'decalspec.txt';

const my $DROPOFFONLY     => 'Drop off only';
const my $LASTSTOP        => $DROPOFFONLY;      #'Last stop';
const my $OVERRIDE_STRING => 'Override:';

const my %ICON_OF => (
    Amtrak           => 'A',
    BART             => 'B',
    'ACE'            => 'C',
    'Early Bird'     => 'E',
    'Ferry'          => 'F',
    DB               => 'D',
    Caltrain         => 'L',
    'All Nighter'    => 'N',
    Airport          => 'P',
    Rapid            => 'R',
    Transbay         => 'T',
    'VTA Light Rail' => 'V',
    Clockwise        => 'W',
    Counterclockwise => 'X',
    'A Loop'         => 'Y',
    'B Loop'         => 'Z',
    # A and B were taken for Amtrak and BART
);

const my %SIDE_OF => (
    ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 27 98 99/ ) ),
    ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
);

my %placelist_of;    # $placelist_of{$pat_rdi} = list of places
my %pats_of;         # $pats_of{$routedir}{$placelist} = PAT identifier
my %num_trips_of_pat;
my %num_trips_of_routedir;
my %plainroutes;
my %routes;
my %plainroutes_of_stop;
# $plainroutes_of_stop{$stop_ident}{$route} = number of times used
my %stops_of_pat;
my %routes_of_stop;
# $routes_of_stop{$stop_ident}{$route} = number of times used
#my %pats_of_stop;    # $pats_of_stop{$stop_ident}{$routedir}{$pat_ident} =
# $patinfo anonhash (Place, NextPlace, Connections)
my %shortkeys_of_stop;
my %tp_override_of;
my %plain_override_of;
my %tp_overridden;

my %color_of;

sub START {

    my $class    = shift;
    my $env      = shift;
    my $actiumdb = $env->actiumdb;

    my $signup = $env->signup;

    my $flagfolder = $signup->subfolder('flags');

    my ( %places, %stops );
    #my %lines;

    $actiumdb->load_tables(
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
            #Lines =>
            #  { hash => \%lines, index_field => 'Line' },
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [
                    qw[h_stp_511_id c_description_full
                      u_connections h_stp_district ]
                ],
            },
        }
    );

    {
        my $hasi_db = $signup->load_hasi();
     #        my $hasidir = $signup->subfolder('hasi');
     #        my $hasi_db = Octium::O::Files::HastusASI->new( $hasidir->path());
        $hasi_db->ensure_loaded(qw(PAT TRP));
        build_place_and_stop_lists( $hasi_db, \%stops );

        build_trip_quantity_lists($hasi_db);
    }

    cull_placepats();

    # free up memory - no longer needed
    %num_trips_of_pat      = ();
    %num_trips_of_routedir = ();
    %stops_of_pat          = ();

    delete_last_stops();

    load_timepoint_data( \%places );
    build_placelist_descriptions();

    build_pat_combos();
    process_combo_overrides($flagfolder);

    read_decal_specs($flagfolder);

    build_color_of( $signup, $actiumdb );

    output_specs( $flagfolder, \%stops );

    return;

}    ## tidy end: sub START

sub build_place_and_stop_lists {

    my $hasi_db = shift;
    my $stops_r = shift;

    my $cry = cry('Building lists of places and stops');

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE IsInService <> '' AND IsInService <> '0' ORDER BY Route} );

    my $dbh = $hasi_db->dbh();
    my $tps_sth
      = $dbh->prepare('SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');

    my $prevroute = $EMPTY;
  PAT:
    while ( my $pat = $eachpat->() ) {

        my $pat_ident = $pat->{Identifier};
        my $route     = $pat->{Route};
        if ( $route ne $prevroute ) {
            $cry->over($route);
            $prevroute = $route;
        }

        next PAT if Octium::in( $route, 'BSH', 'BSD', 'BSN', '399' );
        # skip Broadway Shuttle

        my @tps = @{
            $dbh->selectall_arrayref( $tps_sth, { Slice => {} },
                $pat->{PAT_id} )
        };

        # SKIP 400 and 600 ROUTES
        if ( $route =~ /\A [46]\d\d \z/sx ) {
            for my $tps_row (@tps) {
                my $stop_ident = $tps_row->{StopIdentifier};
                $plainroutes_of_stop{$stop_ident}{$route}++;
                $plainroutes{$route}++;
                $routes_of_stop{$stop_ident}{$route}++;
                $routes{$route}++;
            }
            next PAT;
        }

        my $routedir = jk( $route,    $pat->{DirectionValue} );
        my $pat_rdi  = jk( $routedir, $pat_ident );

        my @places;

        my $prevplace = $EMPTY;
        my $prevstop  = $EMPTY;
        my ( @intermediate_stops, @all_stops );

      TPS:

        for my $tps_row (@tps) {

            my $place = $tps_row->{Place};
            $place =~ s/-[AD12]\z//sx;
            my $stop_ident = $tps_row->{StopIdentifier};

            if ( $stop_ident eq $prevstop ) {    # same stop
                next TPS if ( not $place ) or ( $place eq $prevplace );

                # skip stop entirely unless place is changed

                $all_stops[-1]->{Place} = $place;

                # if place changed, make previous stop this new place

                push @places, $place;
                $prevplace = $place;

                next TPS;
            }

            my $patinfo = {};

            if ( $place and ( $place ne $prevplace ) ) {    # different place
                push @places, $place;
                $prevplace = $place;
                $patinfo->{AtPlace} = 1;

                foreach (@intermediate_stops) {
                    $_->{NextPlace} = $place;
                }
                @intermediate_stops = ();
            }

            my $row = $stops_r->{$stop_ident};

            $patinfo->{Place} = $prevplace;

            my $connections = $row->{u_connections};
            if ($connections) {

                foreach
                  my $connection ( split( /[\n\r]/sx, $row->{u_connections} ) )
                {
                    $patinfo->{Connections}{$connection} = 1;
                }

            }

            my $district = $row->{h_stp_district};
            $district =~ s/\A 0//sx;
            $patinfo->{District} = $district;
            next TPS if $district =~ /\A D/sx;    # dummy stop
            my $side = $SIDE_OF{$district};
            if ( not $side ) {
                carp "Unknown district: $district";
                set_term_pos(0);
            }
            $patinfo->{Side} = $side;

            push @all_stops, $patinfo;
            my $already_in_pattern
              = set_pats_of_stop( $stop_ident, $routedir, $pat_ident,
                $patinfo );
            #$pats_of_stop{$stop_ident}{$routedir}{$pat_ident} = $patinfo;
            $routes_of_stop{$stop_ident}{$route}++ unless $already_in_pattern;
            $routes{$route}++;
            push @{ $stops_of_pat{$pat_rdi} }, $stop_ident;
            push @intermediate_stops, $patinfo;    # if not $place;

            # references to the same anonymous hash

        }    ## tidy end: TPS: for my $tps_row (@tps)
        $all_stops[-1]->{Last} = 1;

        # connections and Transbay info

        transbay_and_connections( $route, @all_stops );

        # Place lists

        my $placelist = jk(@places);

        push @{ $pats_of{$routedir}{$placelist} }, $pat_rdi;
        $placelist_of{$pat_rdi} = $placelist;

        # now we have cross-indexed the pattern ident
        # and its place listing

    }    ## tidy end: PAT: while ( my $pat = $eachpat...)

    $cry->done;

    return;

}    ## tidy end: sub build_place_and_stop_lists

sub transbay_and_connections {
    my ( $route, @all_stops ) = @_;

    my $transbay;
    my $prev_side;
    my %these_connections;
    for my $patinfo ( reverse @all_stops ) {
        # first, put all existing connections into ConnIcons
        foreach my $connection ( keys %these_connections ) {
            $patinfo->{ConnIcons}{$connection} = 1;
        }
        # then, save the connections of the current stop for later
        foreach my $connection ( keys %{ $patinfo->{Connections} } ) {
            $these_connections{$connection} = 1;
        }

        if ($transbay) {
            $patinfo->{TransbayIcon} = 1;
        }
        else {
            my $side = $patinfo->{Side};
            if ( $route !~ /^DB/ and $prev_side and ( $prev_side ne $side ) ) {
                # DB, DB1, DB3 should not have transbay icon
                $transbay = 1;
                $patinfo->{TransbayIcon} = 1;
            }
            else {
                $prev_side = $side;
            }
        }
    }    ## tidy end: for my $patinfo ( reverse...)

    if ( Octium::in( $route, @TRANSBAY_NOLOCALS ) ) {
        my $dropoff;
        undef $prev_side;
        for my $patinfo (@all_stops) {
            if ($dropoff) {
                $patinfo->{DropOffOnly} = 1;
            }
            else {
                my $side = $patinfo->{Side};
                if ( $prev_side and ( $prev_side ne $side ) ) {
                    $dropoff = 1;
                    $patinfo->{DropOffOnly} = 1;
                }
                else {
                    $patinfo->{TransbayOnly} = 1;
                    $prev_side = $side;
                }
            }

        }

    }    ## tidy end: if ( Octium::in( $route, @TRANSBAY_NOLOCALS...))

}    ## tidy end: sub transbay_and_connections

sub build_trip_quantity_lists {
    my $hasi_db = shift;

    my $cry = cry('Building lists of trip quantities');

    my $next_trp = $hasi_db->each_row_where( 'TRP',
        q{WHERE IsPublic = 'X' OR IsPublic = '1'} );

  TRP:
    while ( my $trp = $next_trp->() ) {

        my $pat_ident = $trp->{Pattern};
        my $route     = $trp->{RouteForStatistics};
        #my $pat       = $hasi_db->row( 'PAT', jk( $route, $pat_ident ) );
        my $pat = $hasi_db->row( 'PAT', join( "\c]", $route, $pat_ident ) );
        # I redefined jk
        my $dir      = $pat->{DirectionValue};
        my $routedir = jk( $route, $dir );
        my $pat_rdi  = jk( $route, $dir, $pat_ident );
        next TRP unless exists $placelist_of{$pat_rdi};

        my $placelist = $placelist_of{$pat_rdi};

        $num_trips_of_pat{$routedir}{$placelist}++;
        $num_trips_of_routedir{$routedir}++;

    }

    $cry->done;

    return;

}    ## tidy end: sub build_trip_quantity_lists

sub cull_placepats {

    my $cry = cry('Combining duplicate place-patterns');

    foreach my $routedir ( Actium::sortbyline( keys %num_trips_of_pat ) ) {

        # combine placelists with more than one identifier

        my @placelists = keys %{ $num_trips_of_pat{$routedir} };

        @placelists
          = sort { length($b) <=> length($a) || $a cmp $b } @placelists;

        for my $placelist (@placelists) {
            my @pat_rdis = @{ $pats_of{$routedir}{$placelist} };
            next if @pat_rdis == 1;
            # we know there are duplicate identifiers now

            #$pats_of{$routedir}{$placelist} = [ shift @pat_rdis ];
            $pats_of{$routedir}{$placelist} = [ $pat_rdis[0] ];

            delete_identifiers( $routedir, @pat_rdis );
            # will keep the first one, and delete the rest

        }

    }    ## tidy end: foreach my $routedir ( Actium::sortbyline...)

    $cry->done;

    my $cullcry = cry('Culling place-patterns');

    foreach my $routedir ( Actium::sortbyline( keys %num_trips_of_pat ) ) {

        # delete subset place patterns, if possible
        my $threshold = $num_trips_of_routedir{$routedir} / $CULL_THRESHOLD;

        my @placelists = sort { length $b <=> length $a || $a cmp $b }
          keys %{ $num_trips_of_pat{$routedir} };

        my $longest = shift @placelists;

        while (@placelists) {
            foreach my $idx ( 0 .. $#placelists ) {
                my $thislist = $placelists[$idx];

                if ($longest =~ /$thislist\z/sx
                    or ( index( $longest, $thislist ) != -1
                        and $num_trips_of_pat{$routedir}{$thislist}
                        < $threshold )
                    # it culls from the threshold only if it's a short turn,
                    # not a branch. Hmm.
                  )
                {

                    delete_placelist_from_lists( $routedir, $thislist,
                        $longest );
                    undef $placelists[$idx];
                }
            }

            @placelists = grep {defined} @placelists;
            $longest = shift @placelists;
        }    ## tidy end: while (@placelists)

    }    ## tidy end: foreach my $routedir ( Actium::sortbyline...)

    $cullcry->done;

    return;

}    ## tidy end: sub cull_placepats

{
    my %pats_of_stop;

    sub dump_pats_of_one_stop {
        my $stop = shift;
        return mydump( \( $pats_of_stop{$stop} ) );
    }

    sub dump_pats_of_stop {
        return mydump( \%pats_of_stop );
    }

    sub set_pats_of_stop {
        my ( $stop_ident, $routedir, $pat_ident, $patinfo ) = @_;
        if ( exists $pats_of_stop{$stop_ident}{$routedir}{$pat_ident} ) {
            return 1;
        }
        # loop routes may end at the same stop they start at!
        # if so, this makes sure the last one doesn't overwrite the first one
        $pats_of_stop{$stop_ident}{$routedir}{$pat_ident} = $patinfo;
        return;
    }

    sub pat_idents_of {
        my ( $stop, $routedir ) = @_;
        return keys %{ $pats_of_stop{$stop}{$routedir} };
    }

    sub keys_pats_of_stop {
        return keys(%pats_of_stop);
    }

    sub routedirs_of_stop {
        my $stop = shift;
        return Actium::sortbyline( keys %{ $pats_of_stop{$stop} } );
    }

    sub patternflag {    # if *any* pattern has the flag
        my ( $flag, $stop_ident, $routedir ) = @_;

        my @results;
        foreach
          my $patinfo ( values( %{ $pats_of_stop{$stop_ident}{$routedir} } ) )
        {
            return 1 if exists $patinfo->{$flag};
        }

        return;
    }

    sub patternflag_all {    # if *all* patterns have the flag
        my ( $flag, $stop_ident, $routedir ) = @_;

        my @results;
        foreach
          my $patinfo ( values( %{ $pats_of_stop{$stop_ident}{$routedir} } ) )
        {
            return if not exists $patinfo->{$flag};
        }

        return 1;
    }

    sub connection_icons {
        my ( $stop_ident, $routedir ) = @_;

        my %conn_icon;
        foreach
          my $patinfo ( values( %{ $pats_of_stop{$stop_ident}{$routedir} } ) )
        {
            $conn_icon{$_} = 1 foreach keys %{ $patinfo->{ConnIcons} };
        }

        return Actium::joinempty( map { $ICON_OF{$_} } keys %conn_icon );

    }

    sub places_match {
        my $stop_ident = shift;
        my $routedir   = shift;
        my $place      = shift;
        my $nextplace  = shift;

        my @patinfos = patinfos_of( $stop_ident, $routedir );

        my $skip_it = 1;
        foreach my $patinfo (@patinfos) {
            if ( not( exists $patinfo->{Last} or $patinfo->{DropOffOnly} ) ) {
                $skip_it = 0;
                last;
            }
        }
        return if $skip_it;

        if ( $nextplace eq $place ) {
            foreach my $patinfo (@patinfos) {

                if ( not defined $patinfo->{Place} ) {
                    my $x = [ $patinfo, "ND $stop_ident" ];
                    p $x;
                    next;
                }

                return 1
                  if $place eq $patinfo->{Place} and exists $patinfo->{AtPlace};
            }
            return;
        }

        foreach my $patinfo (@patinfos) {

            if ( not defined $patinfo->{Place} ) {
                my $q       = exists $pats_of_stop{$stop_ident};
                my $disp_rd = keyreadable($routedir);
                cry_text( "P ${disp_rd} ${stop_ident} "
                      . join( ' ', keys %$patinfo ) );
                return;
            }

            return if $patinfo->{Place} ne $place;

            if ( not defined $patinfo->{NextPlace} ) {
                my $q       = exists $pats_of_stop{$stop_ident};
                my $disp_rd = keyreadable($routedir);
                cry_text( "NP ${disp_rd} ${stop_ident} "
                      . join( ' ', keys %$patinfo ) );
                return;
            }

            return 1
              if $patinfo->{NextPlace} eq $nextplace;

        }    ## tidy end: foreach my $patinfo (@patinfos)

        return;

    }    ## tidy end: sub places_match

    sub patinfos_of {
        my ( $stop_ident, $routedir ) = @_;

        my @results;
        foreach
          my $patinfo ( values( %{ $pats_of_stop{$stop_ident}{$routedir} } ) )
        {

            push @results, $patinfo;
        }

        if ( @results == 0 ) {
            cry_text("No results: $stop_ident $routedir");
        }

        return @results;
    }

    sub delete_identifiers {
        # delete identifiers in lists for identical place patterns

        my ( $routedir, $replacement_rdi, @pat_rdis ) = @_;
        my ( $route, $dir ) = routedir($routedir);

        my $replacement_ident = $replacement_rdi;
        $replacement_ident =~ s/.*$NEW_KEY_SEPARATOR//sx;

        # %placelist_of, %stops_of_pat, %pats_of_stop
        foreach my $pat_rdi (@pat_rdis) {
            my $pat_ident = $pat_rdi;
            $pat_ident =~ s/.*$NEW_KEY_SEPARATOR//sx;
            my @stops = @{ $stops_of_pat{$pat_rdi} };
            delete $placelist_of{$pat_rdi};
            delete $stops_of_pat{$pat_rdi};
            foreach my $stop_ident (@stops) {

                if (scalar
                    keys %{ $pats_of_stop{$stop_ident}{$routedir} } == 1 )
                {
                    $pats_of_stop{$stop_ident}{$routedir}{$replacement_ident}
                      = $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                }
                else {
                    $routes_of_stop{$stop_ident}{$route}--;
                }

                delete $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                #$routes_of_stop{$stop_ident}{$route}--;
            }

        }    ## tidy end: foreach my $pat_rdi (@pat_rdis)

        return;

    }    ## tidy end: sub delete_identifiers

    sub delete_last_stops {

        my $cry = cry('Deleting final stops');

        foreach my $stop ( keys %pats_of_stop ) {

            foreach my $routedir ( keys %{ $pats_of_stop{$stop} } ) {
                my ( $route, $dir ) = routedir($routedir);
                foreach
                  my $pat_ident ( keys %{ $pats_of_stop{$stop}{$routedir} } )

                {
                    delete_a_last_stop( $pats_of_stop{$stop},
                        $routes_of_stop{$stop}, $routedir, $pat_ident, $stop,
                        $route );

#                    next
#                      unless
#                      exists $pats_of_stop{$stop}{$routedir}{$pat_ident}{Last};
#
#                    next if $routes_of_stop{$stop}{$route} == 1;
#
#                    delete $pats_of_stop{$stop}{$routedir}{$pat_ident};
#                    if ( not %{ $pats_of_stop{$stop}{$routedir} } ) {
#                        delete $pats_of_stop{$stop}{$routedir};
#                    }
#                    $routes_of_stop{$stop}{$route}--;

                }    ## tidy end: foreach my $pat_ident ( keys...)
            }    ## tidy end: foreach my $routedir ( keys...)
        }    ## tidy end: foreach my $stop ( keys %pats_of_stop)
        $cry->done;

        return;

    }    ## tidy end: sub delete_last_stops

}

sub delete_a_last_stop {
    my ( $pat_infos, $routes_r, $routedir, $pat_ident, $stop, $route ) = @_;

    return
      unless exists $pat_infos->{$routedir}{$pat_ident}{Last}
      or exists $pat_infos->{$routedir}{$pat_ident}{DropOffOnly};
    #### The last line added very late, needs testing!

    return if $routes_r->{$route} == 1;

    delete $pat_infos->{$routedir}{$pat_ident};
    if ( not %{ $pat_infos->{$routedir} } ) {
        delete $pat_infos->{$routedir};
    }
    $routes_r->{$route}--

}

sub delete_placelist_from_lists {

    # Delete entries from lists for deleted place patterns

    my ( $routedir, $placelist, $longest ) = @_;

    # $num_trips_of_pat and %pats_of
    my $replacement_rdi = $pats_of{$routedir}{$longest}[0];
    my @pat_rdis        = @{ $pats_of{$routedir}{$placelist} };
    delete $pats_of{$routedir}{$placelist};
    delete $num_trips_of_pat{$routedir}{$placelist};

    delete_identifiers( $routedir, $replacement_rdi, @pat_rdis );

    return;

}

{

    my %combos;
    my %override_of;
    my %comments_of;
    my %preserved_override_of;
    #my %short_code_of;

    sub build_pat_combos {
        my $cry = cry('Building pattern combinations');

      STOP:
        foreach my $stop ( keys_pats_of_stop() ) {

            foreach my $routedir ( routedirs_of_stop($stop) ) {

                my ( $route, $dir ) = routedir($routedir);

                my @pat_idents = pat_idents_of( $stop, $routedir );

                my @placelists
                  = map { $placelist_of{ jk( $routedir, $_ ) } } @pat_idents;

                if ( not defined $placelists[0] ) {
                    $cry->text(
                        "No placelist for $stop, $route, $dir, [@pat_idents]");
                    next STOP;
                }

                @placelists
                  = uniq( sort { length($b) <=> length($a) || $a cmp $b }
                      @placelists );

                my $combokey = Octium::jointab(@placelists);
                my $shortkey = Octium::jointab( $routedir, $combokey );

                $combos{$routedir}{$combokey} = \@placelists;
                push @{ $shortkeys_of_stop{$stop}{$routedir} }, $shortkey;

                make_destination_of( $cry, $routedir, $combokey, @placelists );

            }    ## tidy end: foreach my $routedir ( routedirs_of_stop...)
        }    ## tidy end: STOP: foreach my $stop ( keys_pats_of_stop...)

        #say dump_destinations();

        $cry->done;
        return;

    }    ## tidy end: sub build_pat_combos

    sub process_combo_overrides {
        my $flagfolder = shift;
        my $file
          = File::Spec->catfile( $flagfolder->path(), $OVERRIDE_FILENAME );
        my $newfile = "$file.new";
        my $bakfile = "$file.bak";

        # first, we input the file, receiving the user overrides

        my $oldexists = -e $file;

        read_combo_overrides($file) if $oldexists;

        # then, we output the file, including all current overrides and
        # all the old ones, too

        write_combo_overrides($newfile);

        if ($oldexists) {
            if ( -e $bakfile ) {
                unlink $bakfile or die "Can't unlink $bakfile: $OS_ERROR";
            }
            rename $file, $bakfile
              or die "Can't rename $file to $bakfile: $OS_ERROR";
            rename $newfile, $file
              or die "Can't rename $newfile to $file: $OS_ERROR";
        }

        foreach my $shortkey ( keys %override_of ) {
            #my ( $routedir, $combokey ) = split( "\t", $shortkey );
            override_destination_of( $shortkey, $override_of{$shortkey} );
        }

        read_tp_overrides($flagfolder);

        read_plain_overrides($flagfolder);

        return;

    }    ## tidy end: sub process_combo_overrides

    const my $ENTRY_DIVIDER => ( q{=} x 78 );

    sub write_combo_overrides {
        my $file = shift;

        my $cry = cry("Writing override file $OVERRIDE_FILENAME");

        open my $out, '>', $file or die "Can't open $file for writing";

        const my $PATTERNPAD => $SPACE x 7;

        my $oldfh = select($out);

        local $Text::Wrap::unexpand = 1;    ## no critic (ProhibitPackageVars)

        my $short = 'aa';
        my %short_code_of;

        foreach my $routedir ( Actium::sortbyline keys %combos ) {

            my ( $route, $dir ) = routedir($routedir);

            my @thesecombos = keys %{ $combos{$routedir} };

            foreach my $combokey (@thesecombos) {
                my $shortkey = Octium::jointab( $routedir, $combokey );
                $short_code_of{$shortkey} = $short++;
                printf "Line %-3s %68s\n", $route, $short_code_of{$shortkey};
                my @placelists = @{ $combos{$routedir}{$combokey} };
                #say $PATTERNPAD, 'Pattern',
                #  ( scalar @placelists ? '(s)' : $EMPTY ),
                #  q{:};
                foreach my $placelist (@placelists) {
                    say wrap (
                        q{=} . $PATTERNPAD,
                        q{=} . $PATTERNPAD . $PATTERNPAD,
                        description_of( $routedir, $placelist ),
                    );
                }
                say '= Computer: ', destination_of($shortkey);
                say $comments_of{$shortkey} if $comments_of{$shortkey};
                say Actium::joinempty (
                    $OVERRIDE_STRING, $SPACE, $override_of{$shortkey} || $EMPTY
                );
                say $ENTRY_DIVIDER;
            }    ## tidy end: foreach my $combokey (@thesecombos)

        }    ## tidy end: foreach my $routedir ( Actium::sortbyline...)

        say '! The following are no longer in use';
        foreach my $shortkey ( Actium::sortbyline keys %preserved_override_of )
        {
            my ( $route, $dir ) = routedir($shortkey);
            $short_code_of{$shortkey} = $short++;
            printf "Line %-3s %68s\n", $route, $short_code_of{$shortkey};
            say $preserved_override_of{$shortkey};
            say $ENTRY_DIVIDER;
        }

        say 'Codes:';
        foreach my $shortkey (
            sort { $short_code_of{$a} cmp $short_code_of{$b} }
            keys %short_code_of
          )
        {
            say "$short_code_of{$shortkey}\t$shortkey";
        }

        select($oldfh);

        $cry->done;
        return;

    }    ## tidy end: sub write_combo_overrides

    sub read_combo_overrides {

        my $file = shift;

        my %input_override_of;
        my %input_descriptions_of;
        my %input_comments_of;
        my $chunk;

        my $cry = cry("Reading override file $OVERRIDE_FILENAME");

        open my $in, '<', $file
          or die "Can't open $file for input: $OS_ERROR";

        local $/ = $ENTRY_DIVIDER . "\n";
        #local $INPUT_RECORD_SEPARATOR = $ENTRY_DIVIDER . "\n";

        while ( $chunk = <$in> ) {
            last if $chunk =~ /^Codes:/sx;
            chomp $chunk;

            my @lines = split( /\n/, $chunk );
            my $comments    = join( "\n", grep {/\A#/} @lines );
            my $description = join( "\n", grep {/\A=/} @lines );
            @lines = grep { $_ and not(m/\A[#=!]/) } @lines;

            my $topline = shift @lines;
            my ( undef, $line, $short ) = split( q{ }, $topline );

            my $override = shift @lines;
            $override =~ s/ \A  $OVERRIDE_STRING  \s* //sx;
            $override =~ s/ \s+ \z //sx;

            $input_override_of{$short}     = $override    if $override;
            $input_comments_of{$short}     = $comments    if $comments;
            $input_descriptions_of{$short} = $description if $description;

        }    ## tidy end: while ( $chunk = <$in> )

        close $in or die "Can't close $file for input: $OS_ERROR";

        # read codes

        my @lines = split( /\n/sx, $chunk );
        shift @lines;    # the word "Codes:"

        my %shortkey_of;
        foreach my $line (@lines) {
            my ( $short, $shortkey ) = split( /\t/sx, $line, 2 );
            $shortkey_of{$short} = $shortkey;
        }

        # if there is either an override or a comment for an entry,
        # preserve it.
        my @keys
          = uniq( sort ( keys %input_override_of, keys %input_comments_of ) );

        foreach my $short (@keys) {
            my $shortkey = $shortkey_of{$short};
            my ( $routedir, $combokey ) = split( /\t/sx, $shortkey, 2 );
            if ( exists( $combos{$routedir}{$combokey} ) ) {
                my $override = $input_override_of{$short};
                $override_of{ $shortkey_of{$short} } = $override if $override;

                $comments_of{$shortkey} = $input_comments_of{$short};
            }
            else {
                my @preserved = $input_descriptions_of{$short};
                push @preserved, $input_comments_of{$short}
                  if $input_comments_of{$short};
                push @preserved,
                  Actium::joinempty( $OVERRIDE_STRING, $SPACE,
                    $input_override_of{$short} );
                $preserved_override_of{$shortkey} = Octium::joinlf(@preserved);
            }
        }

        foreach my $short ( keys %input_comments_of ) {
            $comments_of{ $shortkey_of{$short} } = $input_comments_of{$short};
        }

        $cry->done;

        return;

    }    ## tidy end: sub read_combo_overrides

}

sub relevant_places {
    my @placelists = @_;
    my @place_arys;
    foreach my $placelist (@placelists) {
        push @place_arys, [ sk($placelist) ];
    }
    my @relevants = distinguish(@place_arys);
    #my @relevant_places = map { jk( @{$_} ) } @relevants;
    my @results;
    for my $idx ( 0 .. $#placelists ) {
        push @results, $placelists[$idx], jk( @{ $relevants[$idx] } );
    }
    return @results;
}

{

    my $places_r;

    sub load_timepoint_data {
        $places_r = shift;
        return;
    }

    my %destination_of;

    sub dump_destinations {
        return mydump( \%destination_of );
    }

    sub make_destination_of {
        my $cry      = shift;
        my $routedir = shift;
        my ( $route, $dir ) = routedir($routedir);
        my $combokey   = shift;
        my @placelists = @_;

        my %destinations;
        my @place_arys;

        foreach my $placelist (@placelists) {
            if ( not defined $placelist ) {
                $cry->over('!!!');
            }
            push @place_arys, [ sk($placelist) ];
        }

        my @union = ordered_union(@place_arys);
        my %order;

        foreach ( 0 .. $#union ) {
            $order{ $union[$_] } = $_;
        }

        foreach my $placelist (@placelists) {
            my $place = $placelist;
            $place =~ s/.*$NEW_KEY_SEPARATOR//sx;
            my $dest = $places_r->{$place}{c_destination};
            $destinations{$dest} = $order{$place};
        }

        my $destination = join( q{ / },
            sort { $destinations{$b} <=> $destinations{$a} }
              keys %destinations );

        #       8 CW    9 CC

        $destination = (
              $dir eq '8'  ? 'Clockwise to '
            : $dir eq '9'  ? 'Counterclockwise to '
            : $dir eq '14' ? 'A Loop to '
            : $dir eq '15' ? 'B Loop to '
            :                'To '
        ) . $destination;

        $destination_of{ Octium::jointab( $routedir, $combokey ) }
          = $destination;

        return;

    }    ## tidy end: sub make_destination_of

    sub override_destination_of {
        my ( $shortkey, $override ) = @_;
        $destination_of{$shortkey} = $override;
        return;
    }

    sub destination_of {
        my ($shortkey) = @_;
        return $destination_of{$shortkey};
    }

    my %description_of;

    sub build_placelist_descriptions {

        foreach my $routedir ( keys %pats_of ) {
            my @theselists;
            foreach my $placelist ( keys %{ $pats_of{$routedir} } ) {
                push @theselists, $placelist;
            }
            my %relevant_places = relevant_places(@theselists);

            while ( my ( $placelist, $relevant ) = each %relevant_places ) {

                my @descriptions;
                foreach my $place ( sk($relevant) ) {
                    push @descriptions, $places_r->{$place}{c_description};
                    warn "Unknown description for $place"
                      unless $descriptions[-1];
                }

                $description_of{$routedir}{$placelist}
                  = join( ' -> ', @descriptions );

            }

        }    ## tidy end: foreach my $routedir ( keys...)

        return %description_of;

    }    ## tidy end: sub build_placelist_descriptions

    sub description_of {
        my ( $routedir, $placelist ) = @_;
        return $description_of{$routedir}{$placelist};
    }

    sub override_description_of {
        my ( $override, $routedir, $placelist ) = @_;
        $description_of{$routedir}{$placelist} = $override;
        return;
    }

    sub all_descriptions_of {
        my ( $routedir, $combokey ) = @_;
        my @placelists = split( /\t/sx, $combokey );
        my @descs;
        foreach my $placelist (@placelists) {
            push @descs, $description_of{$routedir}{$placelist};
        }
        return @descs;
    }

}

sub output_specs {
    my $flagfolder = shift;
    my $stops_r    = shift;

    my $stop_decal_cry = cry('Writing stop and decal info');

    my $decal_cry = cry("Writing stop decal file $STOP_SPEC_FILENAME");

    my $file = File::Spec->catfile( $flagfolder->path(), $STOP_SPEC_FILENAME );

    open my $out, '>encoding(UTF-8)', $file
      or die "Can't open $file for writing: $OS_ERROR";
    my $oldfh = select $out;

    foreach my $stop ( sort keys %routes_of_stop ) {
        my $row      = $stops_r->{$stop};
        my $stopdesc = $row->{c_description_full};

        next if $stopdesc =~ /Virtual Stop/si;
        next if $stopdesc =~ /^Transbay Terminal/si;
        next if $stopdesc =~ /^Transbay Temp Terminal/si;
        next if $stopdesc =~ /^Salesforce/si;

        print "$stop\t$stopdesc";

        foreach
          my $route ( Actium::sortbyline keys %{ $routes_of_stop{$stop} } )
        {
            if ( exists( $plainroutes_of_stop{$stop}{$route} ) ) {
                print "\t$route";
            }
            else {
                print "\t", join( "\t", decals( $stop, $route ) );
            }
        }
        #        print "\tOVERRIDDEN" if $tp_overridden{$stop};
        print "\n";
    }    ## tidy end: foreach my $stop ( sort keys...)

    select $oldfh;

    close $out or die "Can't close $file for writing: $OS_ERROR";

    $decal_cry->done;
    output_decal_specs($flagfolder);
    $stop_decal_cry->done;

    return;

}    ## tidy end: sub output_specs

sub make_decal_spec {
    my ( $shortkey, $stop, $routedir ) = @_;
    my ( $route, $dir ) = routedir($routedir);
    my $icons = $EMPTY;

    # Transbay and All_Nighter icons are used even
    # when no connection icons are used
    my $transbay_debug;
    for ($route) {
        if (/\A F \z/sx) {
            $transbay_debug = 1;
            next;
        }
        if (/\A 7\d\d/sx) {
            $icons .= $ICON_OF{'Early Bird'};
            next;
        }
        if (/\A 8\d\d/sx) {
            $icons .= $ICON_OF{'All Nighter'};
            next;
        }
        if (/\A DB/sx) {
            $icons .= $ICON_OF{'DB'};
            next;
        }
        if (/\d R \z/sx) {
            $icons .= $ICON_OF{'Rapid'};
            next;
        }
    }

    for ($dir) {
        if ( $_ eq '8' ) {
            $icons .= $ICON_OF{Clockwise};
            next;
        }
        if ( $_ eq '9' ) {
            $icons .= $ICON_OF{Counterclockwise};
            next;
        }
        if ( $_ eq '14' ) {
            $icons .= $ICON_OF{'A Loop'};
            next;
        }
        if ( $_ eq '15' ) {
            $icons .= $ICON_OF{'B Loop'};
            next;
        }
    }

    my $destination;

    if ( patternflag_all( 'Last', $stop, $routedir ) ) {
        $destination = $LASTSTOP;
    }
    elsif ( patternflag_all( 'DropOffOnly', $stop, $routedir ) ) {
        $destination = $DROPOFFONLY;
    }
    else {
        $destination = destination_of($shortkey);

        if ( patternflag( 'TransbayIcon', $stop, $routedir )
            and $icons !~ /$ICON_OF{'Early Bird'}/ )
        {
            $icons .= $ICON_OF{Transbay};
        }

        if ( patternflag_all( 'TransbayOnly', $stop, $routedir ) ) {
            $destination .= ' (Transbay riders only)';
        }
        else {

            $icons .= connection_icons( $stop, $routedir )
              unless $icons =~ /$ICON_OF{'All Nighter'}/
              or $icons =~ /$ICON_OF{'Early Bird'}/;
            #$icons = "A$icons" if $icons =~ /C/;
            # no longer define Amtrak as Amtrak/ACE
        }
    }

    if ( $destination =~ /\ALimited (?:weekday )hours\z/ ) {
        $icons = $EMPTY;
    }

    $icons = Actium::joinempty( sort split( //, $icons ) );

    my $spec = jk( $route, $destination, $icons );
    return $spec;

}    ## tidy end: sub make_decal_spec

{
    my %decal_of;
    my %next_decal_of;

    sub read_decal_specs {

        my $flagfolder = shift;
        my $file
          = File::Spec->catfile( $flagfolder->path(), $DECAL_SPEC_FILENAME );

        # first, we input the file, receiving the user overrides

        return unless -e $file;

        my $bakfile = "$file.bak";

        open my $in, '<', $file or die "Can't open $file for reading";

        while (<$in>) {
            chomp;
            my ( $decal, $route, $color, $style, $destination, $icons )
              = split(/\t/);
            next unless $decal =~ /-/;
            my ( undef, $letter ) = split( /\-/, $decal );
            $next_decal_of{$route} = ++$letter;

            $icons = Actium::joinempty( sort split( //, $icons ) );

            $decal_of{ jk( $route, $destination, $icons ) } = $decal;
        }

        if ( -e $bakfile ) {
            unlink $bakfile
              or die "Can't unlink $bakfile: $OS_ERROR";
        }
        rename $file, $bakfile
          or die "Can't rename $file to $bakfile: $OS_ERROR";

    }    ## tidy end: sub read_decal_specs

    sub make_decal_from_spec {
        my $spec  = shift;
        my $route = shift;

        if ( not exists $next_decal_of{$route} ) {
            $next_decal_of{$route} = 'a';
        }

        my $decal;
        if ( exists $decal_of{$spec} ) {
            $decal = $decal_of{$spec};
        }
        else {
            #$decal = $next_decal++;
            $decal = "$route-" . $next_decal_of{$route}++;
            $decal_of{$spec} = $decal;
        }
    }

    sub decals {
        my ( $stop, $route ) = @_;

        my @decals;

      ROUTEDIR:
        for my $routedir ( grep {/\A $route $NEW_KEY_SEPARATOR/sx}
            routedirs_of_stop($stop) )
        {
            if ( exists $tp_override_of{$routedir} ) {
                foreach my $placepair ( keys %{ $tp_override_of{$routedir} } ) {
                    if ( places_match( $stop, $routedir, sk($placepair) ) ) {
                        $tp_overridden{$stop} = 1;
                        my $spec = $tp_override_of{$routedir}{$placepair};
                        if ( not $spec =~ /${NEW_KEY_SEPARATOR}\@DELETE/ ) {
                            push @decals, make_decal_from_spec( $spec, $route );
                        }
                        next ROUTEDIR;
                    }
                }
            }

            foreach my $shortkey ( @{ $shortkeys_of_stop{$stop}{$routedir} } ) {
                my $spec = make_decal_spec( $shortkey, $stop, $routedir );
                push @decals, make_decal_from_spec( $spec, $route );
            }
        }    ## tidy end: for my $routedir ( grep...)

        @decals = uniq @decals;

        return @decals;
    }    ## tidy end: sub decals

    sub output_decal_specs {

        my $flagfolder = shift;

        my $cry = cry("Writing decal specification file $DECAL_SPEC_FILENAME");

        my $file
          = File::Spec->catfile( $flagfolder->path(), $DECAL_SPEC_FILENAME );

        open my $out, '>', $file or die "Can't open $file for writing";
        my $oldfh = select $out;

        foreach ( Actium::sortbyline keys %routes ) {    # plain decals
            print Octium::jointab ( $_, $_, ( $color_of{$_} || 'grey30' ),
                style_of_route($_) );
            if ( $plain_override_of{$_} ) {
                print "\t$plain_override_of{$_}\t";
                print $ICON_OF{'All Nighter'} if /\A8\d\d/;
                print $ICON_OF{Rapid} if /R\z/;
            }
            print "\n";
        }

        my %spec_of = reverse %decal_of;
        foreach my $decal ( Actium::sortbyline keys %spec_of ) {
            print "$decal\t";
            my ( $route, $destination, $icons ) = sk( $spec_of{$decal} );
            my $style = style_of_route($route);

            say Octium::jointab (
                $route, ( $color_of{$route} || 'grey30' ),
                $style, $destination, $icons
            );
        }

        select $oldfh;
        close $out or die "Can't close $file for writing: $OS_ERROR";

        $cry->done;

        return;

    }    ## tidy end: sub output_decal_specs

}    ## tidy end: sub decals

sub style_of_route {
    my $route = shift;
    state %cache;
    return $cache{$route} if exists $cache{$route};

    return 'Route' if length($route) < 2;

    my $val = 0;
    my @chars = split( //, $route );
    foreach my $char (@chars) {
        for ($char) {
            if ( Octium::in( $_, qw/ 3 4 8 0 A B C D / ) ) {
                $val += 15;    # 1 1/4
                next;
            }
            if ( Octium::in( $_, qw/ N O X R / ) ) {
                $val += 18;    # 1 1/2
                next;
            }
            if ( Octium::in( $_, qw/M W/ ) ) {
                $val += 24;    # 2
                next;
            }

            $val += 12;        # 1

        }
    }

    my $style;
    for ($val) {
        if ( $_ < 36 ) {       # 3
            $style = 'Route';
            next;
        }
        if ( $_ < 42 ) {       # 3.5
            $style = 'RouteCon';
            next;
        }
        if ( $_ < 48 ) {       # 4
            $style = 'RouteExCon';
            next;
        }

        $style = 'RouteUltCon';

    }

    $cache{$route} = $style;
    return $style;

}    ## tidy end: sub style_of_route

sub build_color_of {
    my $signup   = shift;
    my $actiumdb = shift;

    my %lines;

    $actiumdb->load_tables(
        requests => { Lines => { hash => \%lines, index_field => 'Line' }, } );

    foreach my $line ( keys %lines ) {
        $color_of{ $lines{$line}{Line} } = $lines{$line}{Color};
    }

}

sub read_plain_overrides {
    my $flagfolder = shift;

    my $file
      = File::Spec->catfile( $flagfolder->path(), $PLAIN_OVERRIDE_FILENAME );

    my $cry = cry("Reading plain override file $PLAIN_OVERRIDE_FILENAME");

    open my $in, '<', $file or die "Can't open $file for input: $OS_ERROR";

    while ( my $line = <$in> ) {
        chomp $line;
        my ( $route, $destination ) = split /\t/, $line;

        $plain_override_of{$route} = $destination;

    }

    close $in or die "Can't close $file for input: $OS_ERROR";

    $cry->done;

}    ## tidy end: sub read_plain_overrides

sub read_tp_overrides {
    my $flagfolder = shift;

    my $file
      = File::Spec->catfile( $flagfolder->path(), $TP_OVERRIDE_FILENAME );

    my $cry = cry("Reading timepoint override file $TP_OVERRIDE_FILENAME");

    open my $in, '<', $file or die "Can't open $file for input: $OS_ERROR";

    while ( my $line = <$in> ) {
        chomp $line;
        my ( $route, $dir, $place, $nextplace, $destination, $icons )
          = split /\t/, $line;
        my $routedir = jk( $route, $dir );
        my $places   = jk( $place, $nextplace );
        my $spec     = jk( $route, $destination, $icons );

        $tp_override_of{$routedir}{$places} = $spec;

    }

    close $in or die "Can't close $file for input: $OS_ERROR";

    $cry->done;

}    ## tidy end: sub read_tp_overrides

sub routedir {
    my $routedir = shift;
    my ( $route, $dir ) = sk($routedir);
    return ( $route, $dir );
}

sub mydump {
    require Data::Dumper;    ### DEP ###
    local $Data::Dumper::Indent = 1;
    return Data::Dumper::Dumper(@_);
}

sub HELP {
    say 'actium.pl flagspecs';
    say '  (takes no arguments)';

    return;
}

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

