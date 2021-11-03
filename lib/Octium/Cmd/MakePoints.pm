package Octium::Cmd::MakePoints 0.013;

use sort ('stable');    ### DEP ###

use Actium;
use Octium;

use Octium::Set(qw/ordered_union clusterize/);

use Octium::Text::InDesignTags;
const my $IDT => 'Octium::Text::InDesignTags';

use Octium::Storage::Excel('new_workbook');

use File::Slurper('read_text');    ### DEP ###
use Text::Trim;                    ### DEP ###
use List::MoreUtils;               ### DEP ###

const my $LISTFILE_BASE    => 'pl';
const my $ERRORFILE_BASE   => 'err';
const my $HEIGHTSFILE_BASE => 'ht';
const my $CHECKLIST_BASE   => 'check';
const my $INST_BASE        => 'inst';

const my @EXCEL_COLUMN_WIDTHS       => ( 2, 7, 5.33, 7.17, 46.5, 14.83 );
const my $EXCEL_MAX_WORKSHEET_CHARS => 31;

const my $MAX_CLEARCHANNEL_CLUSTER_DISPLAY_LENGTH => 28;

const my $FALLBACK_AGENCY      => 'ACTransit';
const my $FALLBACK_AGENCY_ABBR => 'AC';

const my $DEFAULT_TALLCOLUMNNUM   => 10;
const my $DEFAULT_TALLCOLUMNLINES => 50;

use constant HEIGHT_OF_FREQUENT_ICON => 5;
# if this is 4, then the icon is 4 lines long in the column

use Octium::Points::Point;
use Octium::Points::Column;

sub HELP {

    my $helptext = <<'EOF';
MakePoints reads the data written by avl2points and turns it into 
output suitable for InDesign.
It is saved in the directory "idpoints2016" in the directory for that signup.
EOF

    say $helptext;

    return;

}

sub OPTIONS {
    return (
        qw/actiumdb signup/,
        {   spec        => 'output_heights',
            description => 'Will output a file with the heights of each column',
            fallback    => 0,
        },
        {   spec => 'update',
            description =>
              q{Will exclude signs that don't have the status "Needs Update."},
            fallback => 0
        },
        {   spec => 'newsigns',
            description =>
q{Will exclude signs that don't have the status "Needs new sign."},
            fallback => 0,

        },
        {   spec => 'type=s',
            description =>
              'Will only process signs that have a given signtype.'
              . ' (Accepts a regular expression.)',
            fallback => $EMPTY
        },
        {   spec => 'delivery=s',
            description =>
              'Will only process signs that have a given delivery.'
              . ' (Accepts a regular expression.)',
            fallback => $EMPTY
        },

        # Note that the regular expression feature, while not allowing more
        # access than is given at the command line anyway, could be problematic
        # if this used on a server.

        {   spec        => 'name=s',
            description => 'Name given to this run. Defaults to a combination '
              . 'of the signtype given (if any), the signIDs given (if any), '
              . 'and whether or not -update was given. '
              . '"-name _" will use no special name.',
            fallback => $EMPTY,
        },
        {   spec        => 'tag=s',
            description => 'Only signs with this tag  will be included.',
            fallback    => $EMPTY,
        },
        {   spec        => 'clusterize!',
            description => 'If specified, will group signs first by delivery, '
              . 'then by stop work zone for polecrew or city for Clear Channel. '
              . 'Default is on; specify -no-clusterize to turn off.',
            fallback => 1,
        },

        {   spec => 'minimum-cluster=i',
            description =>
              'The number of signs that makes up a satisfactory cluster. '
              . '(Work zones that differ in their first digits '
              . 'will never be combined, '
              . 'even if they are smaller than this value.)',

            display_default => 1,
            fallback        => 40,
        },

        {   spec        => 'agency=s',
            description => 'Agency ID used for this run. '
              . 'Only signs of this agency will be produced',
            display_default => 1,
            fallback        => $FALLBACK_AGENCY,
        },
    );
}

sub START {

    our ( %places, %lines );
    # this use of global variables should be refactored...

    my $actiumdb        = env->actiumdb;
    my @specified_signs = env->argv;

    my $signup = env->signup;
    chdir $signup->path();

    # retrieve data

    my $makepoints_cry = env->cry('Making InDesign point schedule files');

    my $load_cry = env->cry('Loading data from Actium database');

    my %smoking = %{ $actiumdb->all_in_column_key(qw(Cities SmokingText)) };

    my ( $run_agency, $run_agency_abbr, $run_agency_row )
      = $actiumdb->agency_or_abbr_row( env->option('agency') );
    # allows specifying either the agency or the agency abbreviation
    # on the command line

    unless ($run_agency) {
        $load_cry->error;
        die 'Agency ' . env->option('agency') . " not found.\n";
    }

    my $agency_effdate = $actiumdb->effective_date( agency => $run_agency );

    $actiumdb->load_tables(
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
            SignTypes => {
                hash        => \my %signtypes,
                index_field => 'SignType'
            },
            Signs => {
                hash        => \my %signs,
                index_field => 'SignID',
                fields      => [
                    qw[
                      SignID Active stp_511_id Status SignType Tag Sidenote
                      Agency ShelterNum NonStopLocation NonStopCity
                      Delivery City TIDFile CopyQuantity OverrideEffDate
                      Stop_id_suffix
                      ]
                ],
            },
            Signs_Stops_Join => { array => \my @ssj },
            SignTemplates    => { array => \my @templates },
            Lines            => {
                hash        => \%lines,
                index_field => 'Line'
            },
            Stops_Neue => {
                hash        => \my %stops,
                index_field => 'h_stp_511_id',
                fields      => [
                    qw[h_stp_511_id c_city c_description_full
                      c_description_nocity u_work_zone]
                ],
            },
            Cities => {
                hash        => \my %cities,
                index_field => 'City',
                fields      => [qw[City CityWorkZone]],
            },
        }
    );

    \my ( %new_signid, %signs_of_stopid )
      = new_signid( signs => \%signs, run_agency => $run_agency );

    my %city_of_workzone;
    foreach my $city ( keys %cities ) {
        my $workzone = $cities{$city}{CityWorkZone};
        $city_of_workzone{$workzone} = $city;
    }

    my %templates_of;

    foreach \my %template (@templates) {
        my $signtype = $template{SignType};
        my $subtype  = $template{MasterPage};
        my $agency   = $template{Agency};

        next if $agency and $agency ne $run_agency;

        my @regions;
        my $regionspec = Actium::trim( $template{Regions} );
        $regionspec =~ s/\s+/ /;
        $regionspec =~ s/[^0-9: ]//g;

        foreach my $region ( split( $SPACE, $regionspec ) ) {
            my ( $columns, $height ) = split( /:/, $region );
            push @regions, { columns => $columns, height => $height };
        }

        @regions = map { $_->[0] }
          reverse sort { $a->[1] <=> $b->[1] }
          map { [ $_, $_->{height} ] } @regions;

        $templates_of{$signtype}{$subtype} = \@regions;

    }

    my $ssj_cry = env->cry('Processing multistop entries');

    my (%stops_of_sign);
    foreach my $ssj (@ssj) {
        my $ssj_stop = $ssj->{h_stp_511_id};
        my $ssj_sign = $ssj->{SignID};

        my $ssj_omit_lines = $ssj->{OmitLines};
        my @ssj_omitted;
        if ($ssj_omit_lines) {
            @ssj_omitted = split( $SPACE, $ssj->{OmitLines} );
        }
        $stops_of_sign{$ssj_sign}{$ssj_stop} = \@ssj_omitted;
    }

    $ssj_cry->done;

    $load_cry->done;

    my @signstodo;
    if (@specified_signs) {
        foreach my $specsign (@specified_signs) {
            if ( $specsign =~ /^N/ ) {
                my $old_signid = substr( $specsign, 1 );
                push @signstodo, $old_signid;
            }
            else {
                push @signstodo, $signs_of_stopid{$specsign}->@*;
            }
        }
    }
    else {
        @signstodo = keys %new_signid;
    }

    my %sortkey_of_old_signid
      = map { $_, Actium::linekeys( $new_signid{$_} ) } @signstodo;

    @signstodo
      = sort { $sortkey_of_old_signid{$a} cmp $sortkey_of_old_signid{$b} }
      @signstodo;

    my $signtype_opt   = env->option('type');
    my $tag_opt        = env->option('tag');
    my $delivery_opt   = env->option('delivery');
    my $clusterize_opt = env->option('clusterize');

    my ( %signtype_matches, %delivery_matches );

    if ( $signtype_opt or $delivery_opt ) {

        # Note that the regular expression feature, while not allowing more
        # access than is given at the command line anyway, could be problematic
        # if this used on a server.

        my ( %seen_signtype, %seen_delivery );

        $seen_delivery{TID} = 1;

        foreach my $old_signid (@signstodo) {
            my $delivery = $signs{$old_signid}{Delivery} // $EMPTY;
            my $signtype = $signs{$old_signid}{SignType} // $EMPTY;
            $seen_delivery{$delivery} = 1;
            $seen_signtype{$signtype} = 1;
        }

        if ($signtype_opt) {
            my @matching_signtypes
              = grep {m/\A $signtype_opt \z/x} keys %seen_signtype;

            if ( not @matching_signtypes ) {
                $makepoints_cry->wail(
                    "No signtype of signs to generate matches $signtype_opt "
                      . 'specified on command line.' );
                $makepoints_cry->error;
                exit 1;
            }
            %signtype_matches = map { ( $_, 1 ) } @matching_signtypes;
            $makepoints_cry->wail("Using sign types: @matching_signtypes");
        }

        if ($delivery_opt) {
            my @matching_deliveries
              = grep {m/\A $delivery_opt \z/x} keys %seen_delivery;

            if ( not @matching_deliveries ) {
                $makepoints_cry->wail(
                    "No delivery of signs to generate matches $delivery_opt "
                      . 'specified on command line.' );
                $makepoints_cry->error;
                exit 1;
            }
            %delivery_matches = map { $_, 1 } @matching_deliveries;
            $makepoints_cry->wail("Using deliveries: @matching_deliveries");
        }

    }

    my $cry = env->cry('Now processing point schedules for sign:');

    my ( %skipped_stops, %points_of_delivery, @finished_points, %errors,
        %heights, %workzone_count );

  SIGN:
    foreach my $old_signid (@signstodo) {

        my $stopid     = $signs{$old_signid}{stp_511_id};
        my $new_signid = $new_signid{$old_signid};
        my $delivery   = $signs{$old_signid}{Delivery} // $EMPTY;
        my $signtype   = $signs{$old_signid}{SignType} // $EMPTY;
        if ( $signtype =~ /^TID/ ) {
            $delivery = 'TID';
        }
        my $tallcolumnnum = $signtypes{$signtype}{TallColumnNum}
          || $DEFAULT_TALLCOLUMNNUM;
        my $tallcolumnlines = $signtypes{$signtype}{TallColumnLines}
          || $DEFAULT_TALLCOLUMNLINES;
        my $status         = $signs{$old_signid}{Status};
        my $tag            = $signs{$old_signid}{Tag}          // $EMPTY;
        my $shelternum     = $signs{$old_signid}{ShelterNum}   // $EMPTY;
        my $sidenote       = $signs{$old_signid}{Sidenote}     // $EMPTY;
        my $copyquantity   = $signs{$old_signid}{CopyQuantity} // 1;
        my $templates_of_r = $templates_of{$signtype}          // {};

        my $effdate = $signs{$old_signid}{OverrideEffDate};
        if ( defined $effdate ) {
            my ( $year, $month, $day ) = split( /-/, $effdate );
            $effdate = Actium::DateTime->new( ymd => [ $year, $month, $day ], );
        }
        else {
            $effdate = $agency_effdate;
        }

        next SIGN
          if $signtype_opt and not exists $signtype_matches{$signtype};

        next SIGN
          if $tag_opt and Actium::fne( $tag, $tag_opt );

        next SIGN
          if $delivery_opt and not exists $delivery_matches{$delivery};

        if ( env->option('update') or env->option('newsigns') ) {
            next SIGN
              unless ( Actium::feq( $status, 'Needs update' )
                and env->option('update') )
              or ( Actium::feq( $status, 'Needs new sign' )
                and env->option('newsigns') );
        }

        my ( $description, $description_nocity, $city, $nonstop );

        if ($stopid) {
            $description        = $stops{$stopid}{c_description_full};
            $description_nocity = $stops{$stopid}{c_description_nocity};
            $city               = $stops{$stopid}{c_city};
        }
        else {
            $nonstop            = 1;
            $description_nocity = $signs{$old_signid}{NonStopLocation};
            $city               = $signs{$old_signid}{NonStopCity};
            $description        = $description_nocity;
            $description .= ", $city" if $city;
        }

        my $smoking;

        $smoking //= $smoking{$city} // $IDT->emdash;

        my $omitted_of_stop_r;
        if ( exists $stops_of_sign{$old_signid} ) {

            $omitted_of_stop_r = $stops_of_sign{$old_signid};

            if ( not $stopid ) {
                my @allstopids = sort keys %{$omitted_of_stop_r};
                $stopid = $allstopids[0];
            }

        }
        elsif ($stopid) {
            $omitted_of_stop_r = { $stopid => [] };
        }

        my $sign_is_active = lc( $signs{$old_signid}{Active} );

        next SIGN if $signs{$old_signid}{Status} =~ /no service/i;
        next SIGN if $sign_is_active ne 'yes';
        next SIGN unless $stopid;

        my $workzone = $stops{$stopid}{u_work_zone} // $EMPTY;

        my $agency      = $signs{$old_signid}{Agency};
        my $agency_abbr = $actiumdb->agency_row_r($agency)->{agency_abbr};

        my $tidfile = $signs{$old_signid}{TIDFile} // $EMPTY;

        next SIGN unless $agency eq $run_agency;

        #####################
        # Following steps

        const my $KPOINT_FOLDER_PREFIX_CHARS => 3;

        foreach my $stoptotest ( keys %{$omitted_of_stop_r} ) {

            # skip stop if file not found
            my $firstdigits
              = substr( $stoptotest, 0, $KPOINT_FOLDER_PREFIX_CHARS );
            my $kpointfile = "p/final/kpoints/${firstdigits}xx/$stoptotest.txt";

            unless ( -e $kpointfile ) {
                push @{ $errors{$new_signid} },
                  "Stop $stoptotest not found"
                  . (
                    $agency ne $FALLBACK_AGENCY
                    ? " ($agency)"
                    : $EMPTY
                  );
                $skipped_stops{$new_signid} = $stoptotest;
                next SIGN;
            }

        }

        $cry->over("$new_signid ");

        # 1) Read kpoints from file

        my $point = Octium::Points::Point->new_from_kpoints(
            {   stopid             => $stopid,
                signid             => $old_signid,
                effdate            => $effdate,
                agency             => $agency,
                omitted_of_stop_r  => $omitted_of_stop_r,
                nonstop            => $nonstop,
                description        => $description,
                city               => $city,
                description_nocity => $description_nocity,
                smoking            => $smoking,
                delivery           => $delivery,
                signup             => $signup,
                workzone           => $workzone,
                signtype           => $signtype,
                city               => $city,
                actiumdb           => $actiumdb,
                shelternum         => $shelternum,
                sidenote           => $sidenote,
                tallcolumnnum      => $tallcolumnnum,
                tallcolumnlines    => $tallcolumnlines,
                templates_of_r     => $templates_of_r,
                copyquantity       => $copyquantity,
                tidfile            => $tidfile,
                new_signid         => $new_signid,
            }
        );
        # 2) Change kpoints to the kind of data that's output in
        #    each column (that is, separate what's in the header
        #    from the times and what's in the footnotes)

        $point->make_headers_and_footnotes;

        # 3) Adjust times to make sure it estimates on the side of

        $point->adjust_times;

        # 4) Combine footnotes across columns, if necessary - may not need
        #    to do this

        # $point->combine_footnotes;

        # 5) Sort columns into order

        #$point->sort_columns_by_route_etc;

        $heights{$new_signid} = $point->heights if defined $point->heights;

        my $subtype = $point->sort_columns_and_determine_heights(
            $signs{$old_signid}{SignType} );

        if ( $subtype and $subtype ne '!' ) {
            #my ( $signtype, $subtype ) = split( /=/, $subtype );
            push @finished_points, $point;
            push $points_of_delivery{$delivery}->@*, $point;
            $workzone_count{$delivery}{$workzone}++;
        }
        else {
            if ( $point->columns ) {
                push @{ $errors{$new_signid} },
                  "No sign template found in $signtype for $run_agency";
            }
            else {
                push $errors{$new_signid}->@*, "No columns for this sign";
            }
        }

        # 6) Format with text and indesign tags. Includes
        #    expanding places into full place descriptions
        #    and dividing columns into ones that are
        #    the proper length (length comes from SignType),
        #    and adding footnote markers

        $point->format_columns( $signs{$old_signid}{SignType} );

        # 7) Format and expand the footnotes (the actual
        #    footnotes, not the footnote markers)

        $point->format_side;

        # 8) Add stop description

        $point->format_bottom;

        # 9) add blank columns in front (if needed) and
        #    output to points

        $point->output;

        my @errors = $point->errors;

        push @{ $errors{$new_signid} }, @errors if @errors;

        $heights{$new_signid} = $point->heights if defined $point->heights;

    }

    $cry->done;

    my $run_name = _get_run_name($run_agency_abbr);

    my $listfile       = $LISTFILE_BASE . $run_name . '.txt';
    my $excelfile      = $CHECKLIST_BASE . $run_name . '.xlsx';
    my $instfoldername = $INST_BASE . $run_name;
    my $list_cry       = env->cry("Writing list to $listfile");

    my $pointlist_folder = $signup->subfolder('pointlist');

    my $list_fh = $pointlist_folder->open_write($listfile);

    my %pages_of;

    if ( defined $points_of_delivery{TID} ) {

        my @tidpoints = $points_of_delivery{'TID'}->@*;

        delete $points_of_delivery{'TID'};
        foreach my $point (@tidpoints) {

            my $tidfile = $point->tidfile;

            $tidfile =~ s#.*/##;
            my $signtype = $point->signtype;

            push $pages_of{$signtype}{$tidfile}->@*,
              [ $point->new_signid, $point->subtype, $point ];

        }

    }

    if ($clusterize_opt) {

        if ( exists $points_of_delivery{'Polecrew'} ) {

            my %seen_workzone;
            foreach my $stopid ( keys %stops ) {
                if (   not exists $stops{$stopid}{u_work_zone}
                    or not defined $stops{$stopid}{u_work_zone} )
                {
                    $list_cry->wail("Work zone not found in stop id $stopid");
                }
                else {
                    $seen_workzone{ $stops{$stopid}{u_work_zone} } = 1;
                }
            }

            my $delivery = 'Polecrew';

            \my @these_points = $points_of_delivery{$delivery};

            \my %cluster_of_workzone = clusterize(
                count_of   => $workzone_count{$delivery},
                size       => env->option('minimum-cluster'),
                all_values => [ keys %seen_workzone ],
                return     => 'runlist',
            );

            %cluster_of_workzone = _letterize(%cluster_of_workzone);

            my $skip_cluster;

            if ( ( scalar keys %cluster_of_workzone ) == 1 ) {
                $skip_cluster = 1;
            }

            foreach my $point (@these_points) {

                my $addition = 'Crew_'
                  . (
                    $skip_cluster
                    ? 'all'
                    : $cluster_of_workzone{ $point->workzone }
                  );

                $addition = substr( $addition, 0, $EXCEL_MAX_WORKSHEET_CHARS );
                # truncate to 31 characters

                push @{ $pages_of{ $point->signtype }{$addition} },
                  [ $point->new_signid, $point->subtype, $point ];

            }

        }

        if ( exists $points_of_delivery{'Clear Channel'} ) {

            my $delivery = 'Clear Channel';

            \my @these_points = $points_of_delivery{$delivery};

            my (%city_workzone_count);
            foreach my $point (@these_points) {
                my $city     = $point->city;
                my $workzone = $cities{$city}{CityWorkZone};

                if ( not defined $workzone ) {
                    die "Work zone code not defined for $city in "
                      . $point->new_signid;
                }

                $city_workzone_count{$workzone}++;
            }

            \my %cluster_of_cityworkzone = clusterize(
                count_of => \%city_workzone_count,
                size     => env->option('minimum-cluster'),
                return   => 'values',
            );

            my %cluster_of_city;

            my $skip_cluster;
            if ( ( scalar keys %cluster_of_cityworkzone ) == 1 ) {
                $skip_cluster = 1;
            }

            else {

                foreach my $workzone ( keys %cluster_of_cityworkzone ) {
                    my $city = $city_of_workzone{$workzone};
                    \my @cluster_zones = $cluster_of_cityworkzone{$workzone};

                    my @cities = map { $city_of_workzone{$_} } @cluster_zones;
                    my $max_length
                      = Actium::max( map { length($_) } @cities );

                    my $cluster_display;

                    do {
                        $_ = substr( $_, 0, $max_length ) foreach @cities;
                        $cluster_display = join( ',', sort @cities );
                        $max_length--;
                    } until length($cluster_display)
                      <= $MAX_CLEARCHANNEL_CLUSTER_DISPLAY_LENGTH;

                    $cluster_of_city{$city} = $cluster_display;
                }
            }

            foreach my $point (@these_points) {

                my $addition = 'CC_'
                  . (
                    $skip_cluster
                    ? 'all'
                    : $cluster_of_city{ $point->city }
                  );

                push @{ $pages_of{ $point->signtype }{$addition} },
                  [ $point->new_signid, $point->subtype, $point ];

            }
        }

        foreach my $delivery ( keys %points_of_delivery ) {
            next
              if $delivery eq 'Polecrew'
              or $delivery eq 'Clear Channel';

            \my @these_points = $points_of_delivery{$delivery};

            foreach my $point (@these_points) {
                push $pages_of{ $point->signtype }{$delivery}->@*,
                  [ $point->new_signid, $point->subtype, $point ];
            }

        }

    }
    else {

        foreach my $point (@finished_points) {
            push $pages_of{ $point->signtype }{'all'}->@*,
              [ $point->new_signid, $point->subtype, $point ];
        }

    }

    # should we need to break up files because they are too big,
    # here is where one would go through %pages_of and add _1, _2, etc.
    # to the addition

    my %checklist_of;
    my %inst_signids_of;
    my %inst_desc_of;
    my %has_shelternum;

    foreach my $signtype ( sort keys %pages_of ) {

        foreach my $addition ( sort keys $pages_of{$signtype}->%* ) {

            my @pages = @{ $pages_of{$signtype}{$addition} };

            @pages = sort { Actium::byline( $a->[0], $b->[0] ) } @pages;

            my $thisfile = $addition;
            $thisfile .= $run_name unless $signtype =~ /^TID/;

            #say $list_fh "FILE\t$signtype\t${addition}$run_name";
            say $list_fh "FILE\t$signtype\t$thisfile";

            foreach my $page (@pages) {

                my ( $new_signid, $subtype_letter, $point ) = $page->@*;
                my $map_page = $new_signid =~ s/[A-Za-z]+\z//r;

                say $list_fh "$new_signid\t$subtype_letter\t$map_page";

                my $copyquantity = $point->copyquantity;
                $copyquantity = $EMPTY if $copyquantity == 1;

                my $sheet;
                if ( $signtype =~ /^TID/ ) {
                    $sheet = 'TID';
                }
                else {
                    $sheet = $addition;
                }

                my $stopid = $point->stopid;
                my $desc   = $point->description_nocity;

                my @checklist_entry = (
                    $copyquantity, $new_signid, $stopid,
                    $point->signtype, $desc, $point->city,
                );

                my $shelternum = $point->shelternum;
                if ($shelternum) {
                    push @checklist_entry, $shelternum;
                    $has_shelternum{$sheet} = 1;
                }

                push $checklist_of{$sheet}->@*, \@checklist_entry;

                next unless Actium::feq( $point->delivery, 'PoleCrew' );

                push $inst_signids_of{$addition}{$stopid}->@*, $new_signid;

            }
        }

    }

    close $list_fh or croak "Can't close $listfile: $ERRNO";
    $list_cry->done;

    my $excel_cry = env->cry("Writing checklist to $excelfile");

    {

        my $workbook_fh = $pointlist_folder->open_write_binary($excelfile);
        my $workbook    = new_workbook($workbook_fh);
        my $body_fmt    = $workbook->add_format(
            text_wrap => 1,
            align     => 'left',
            valign    => 'top'
        );
        my $header_fmt = $workbook->add_format( bold => 1 );

        foreach my $addition ( sort keys %checklist_of ) {

            my @header_row = qw/x SignID StopID SignType Location City/;
            push @header_row, "ShelterNum" if $has_shelternum{$addition};

            my $worksheet = $workbook->add_worksheet($addition);
            $worksheet->set_header('&A');          # header = worksheet name
            $worksheet->set_footer('&P of &N');    # footer - page #
            $worksheet->hide_gridlines(0);         # don't hide gridlines
            $worksheet->write_row( 'A1', \@header_row, $header_fmt );
            $worksheet->repeat_rows(0);
            $worksheet->write_col( 'A2', $checklist_of{$addition}, $body_fmt );

            my $column = 0;
            for my $columnwidth (@EXCEL_COLUMN_WIDTHS) {
                $worksheet->set_column( $column, $column, $columnwidth );
                $column++;
            }
        }

    }

    $excel_cry->done;

    my $inst_folder = $pointlist_folder->ensure_subfolder($instfoldername);

    my @header_row = qw/StopID Location Instructions/;

    foreach my $addition ( sort keys %inst_signids_of ) {

        my $workbook_fh
          = $pointlist_folder->open_write_binary( $addition . '.xlsx' );
        my $workbook = new_workbook($workbook_fh);
        my $body_fmt = $workbook->add_format(
            text_wrap => 1,
            align     => 'left',
            valign    => 'top'
        );
        my $header_fmt = $workbook->add_format( bold => 1 );
        my $worksheet  = $workbook->add_worksheet($addition);
        $worksheet->hide_gridlines(0);    # don't hide gridlines
        $worksheet->write_row( 'A1', \@header_row, $header_fmt );
        $worksheet->repeat_rows(0);

        my @entries;

        foreach my $stopid ( sort keys $inst_signids_of{$addition}->%* ) {

            my @signids = sort $inst_signids_of{$addition}{$stopid}->@*;
            my $inst;
            if ( @signids > 1 ) {
                $inst = "Install pole scheule " . $signids[0];
            }
            else {
                $inst = "Install pole schedules " . Actium::joincomma(@signids);
            }
            push @entries, [ $stopid, $inst_desc_of{$stopid}, $inst ];

        }

        $worksheet->write_col( 'A2', \@entries, $body_fmt );

    }

    ### ERROR DISPLAY

    if ( scalar keys %errors ) {

        my $error_count = scalar keys %errors;

        my $error_file = $ERRORFILE_BASE . $run_name . '.txt';
        my $error_cry  = env->cry("Writing $error_count errors to $error_file");
        my $error_fh   = $pointlist_folder->open_write($error_file);

        foreach my $new_signid ( Actium::sortbyline keys %errors ) {
            foreach my $error ( @{ $errors{$new_signid} } ) {
                say $error_fh "$new_signid\t$error";
            }
        }

        $error_fh->close;
        $error_cry->error;

    }
    else {
        my $error_cry = env->cry('No errors to log');
        $error_cry->valid;
    }

    ### HEIGHTS DISPLAY

    if ( env->option('output_heights') ) {
        my $heights_file = $HEIGHTSFILE_BASE . $run_name . '.txt';
        my $heights_cry  = env->cry("Writing heights to $heights_file");
        my $heights_fh   = $pointlist_folder->open_write($heights_file);
        foreach my $new_signid ( Actium::sortbyline keys %heights ) {
            say $heights_fh "$new_signid\t" . $heights{$new_signid};
        }
        $heights_fh->close;
        $heights_cry->done;
    }

    $makepoints_cry->done;
    return;

}

sub _letterize {
    my %cluster_of_workzone = @_;
    my %return;
    my %letter_of_cluster;
    my $letter = 'A';
    foreach my $key ( sort keys %cluster_of_workzone ) {
        my $cluster = $cluster_of_workzone{$key};
        $return{$key} = ( $letter_of_cluster{$cluster} //= $letter++ );

    }
    return %return;
}

sub _get_run_name {

    my $run_agency_abbr = shift;
    my $nameopt         = env->option('name');

    if ( defined $nameopt and $nameopt ne $EMPTY ) {
        if ( $nameopt eq '_' ) {
            return $EMPTY;
        }
        return '.' . $nameopt;
    }

    my @args     = env->argv;
    my $signtype = env->option('type');
    my $tag      = env->option('tag');

    my @run_pieces;
    push @run_pieces, $run_agency_abbr
      unless $run_agency_abbr eq $FALLBACK_AGENCY_ABBR;
    push @run_pieces, join( ',', @args ) if @args;
    push @run_pieces, $signtype          if $signtype;
    push @run_pieces, $tag               if $tag;
    push @run_pieces, 'N'                if env->option('newsigns');
    push @run_pieces, 'U'                if env->option('update');

    if (@run_pieces) {
        return '.' . join( '_', @run_pieces );
    }
    else {
        return $EMPTY;
    }

}

func new_signid (:\%signs, :$run_agency) {
    my %new_signid;
    my %signs_of_stopid;

    foreach my $signid ( keys %signs ) {
        next unless lc( $signs{$signid}{Active} ) eq 'yes';
        my $stopid = $signs{$signid}{stp_511_id};
        if ( not defined $stopid ) {
            my $new_signid = "N" . $signid;
            $new_signid{$signid}          = $new_signid;
            $signs_of_stopid{$new_signid} = [$signid];
            next;
        }
        push $signs_of_stopid{$stopid}->@*, $signid;
    }

    foreach my $stopid ( sort keys %signs_of_stopid ) {
        my @signids = $signs_of_stopid{$stopid}->@*;
        if ( @signids == 1 ) {
            my $signid = $signids[0];
            my $suffix = $signs{$signid}{Stop_id_suffix};
            $suffix = Actium::define($suffix);
            $new_signid{$signid} = $stopid . $suffix;
            next;
        }

        my ( $without_suffix, $with_suffix ) = List::MoreUtils::part {
            exists $signs{$_}{Stop_id_suffix}
              and ( !!$signs{$_}{Stop_id_suffix} )
        }
        sort { $a <=> $b } @signids;

        my %seen_suffix;
        foreach my $signid ( $with_suffix->@* ) {
            my $suffix = $signs{$signid}{Stop_id_suffix};
            die "Duplicate suffix $suffix "
              . "in stop ID $stopid, sign ID $signid"
              if $seen_suffix{$suffix};
            $seen_suffix{$suffix} = 1;
            $new_signid{$signid}  = $stopid . $suffix;
        }

        my $suffix = 'A';
        foreach my $signid ( sort { $a <=> $b } $without_suffix->@* ) {
            $suffix++ while $seen_suffix{$suffix};
            $new_signid{$signid}  = $stopid . $suffix;
            $seen_suffix{$suffix} = 1;
        }
    }

    return \%new_signid, \%signs_of_stopid;
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

