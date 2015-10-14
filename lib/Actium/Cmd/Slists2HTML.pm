package Actium::Cmd::Slists2HTML 0.010;

use Actium::Preamble;

use Actium::O::Dir;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   ('signup');

use HTML::Entities;    ### DEP ###

sub OPTIONS {
    my ( $class, $env ) = @_;
    return (
        Actium::Cmd::Config::ActiumFM::OPTIONS($env),
        Actium::Cmd::Config::Signup::options($env)
    );
}

my $count;
my %order_of = map { $_ => $count++ } @DIRCODES;

const my $HIGHEST_LINE_IN_FIRST_LOCALPAGE => 70;

const my %LONGCORNER_OF => (
    # taken from Wikipedia... all of them except the eight principal ones
    # are just for fun
    N    => 'North',
    NbE  => 'North by east',
    NNE  => 'North-northeast',
    NEbN => 'Northeast by north',
    NE   => 'Northeast',
    NEbE => 'Northeast by east',
    ENE  => 'East-northeast',
    EbN  => 'East by north',
    E    => 'East',
    EbS  => 'East by south',
    ESE  => 'East-southeast',
    SEbE => 'Southeast by east',
    SE   => 'Southeast',
    SEbS => 'Southeast by south',
    SSE  => 'South-southeast',
    SbE  => 'South by east',
    S    => 'South',
    SbW  => 'South by west',
    SSW  => 'South-southwest',
    SWbS => 'Southwest by south',
    SW   => 'Southwest',
    SWbW => 'Southwest by west',
    WSW  => 'West-southwest',
    WbS  => 'West by south',
    W    => 'West',
    WbN  => 'West by north',
    WNW  => 'West-northwest',
    NWbW => 'Northwest by west',
    NW   => 'Northwest',
    NWbN => 'Northwest by north',
    NNW  => 'North-northwest',
    NbW  => 'North by west',
);

sub START {

    my $makehtml_cry = cry('Making HTML files of stop lists');

    my ( $class, $env ) = @_;
    my $actiumdb = actiumdb($env);
    my $signup   = signup($env);

    my $stoplists_folder      = $signup->subfolder('slists');
    my $stoplists_line_folder = $stoplists_folder->subfolder('line');

    $actiumdb->ensure_loaded('Stops_Neue');

    my $stopdesc_cry = cry('Getting stop descriptions from FileMaker');

    my $stops_row_of_r = $actiumdb->all_in_columns_key(
        qw/Stops_Neue c_description_short h_loca_latitude h_loca_longitude
          c_city c_corner/
    );

    $stopdesc_cry->done;

    my $linegrouptype_of_r
      = $actiumdb->all_in_column_key(qw/Lines LineGroupType/);

    my $htmlversion_cry = cry('Creating HTML versions of stop lists');

    my @files = $stoplists_line_folder->glob_plain_files('*.txt');
    @files = map { u::filename($_) } @files;

    my %dirs_of;

    foreach my $file (@files) {
        my ( $line, $dir, $ext ) = split( /[-.]/s, $file );
        push @{ $dirs_of{$line} }, $dir;
    }

    my %corner_list_of;
    my %corner_lists_of_type;
    my %table_of;
    my %tables_of_type;
    my %lines_of_type;

    foreach my $line ( u::sortbyline keys %dirs_of ) {

        next if $LINE_SHOULD_BE_SKIPPED{$line};

        $htmlversion_cry->over($line);

        my @dirs = @{ $dirs_of{$line} };
        @dirs = sort { $order_of{$a} <=> $order_of{$b} } @dirs;
        my %stops_of;
        my %stoplines_of;
        my %stoplines_corner_of;

        foreach my $dir (@dirs) {

            my $file = "$line-$dir.txt";
            my $ifh  = $stoplists_line_folder->open_read($file);
            binmode $ifh, ':encoding(MacRoman)';

            # HORRIBLE KLUDGE BECAUSE I CAN'T GET ODBC TO READ UTF8 DATA

            my $headerline = readline($ifh);    # thrown away

            my $prevcity = $EMPTY_STR;

            while ( defined( my $stopline = readline($ifh) ) ) {
                chomp $stopline;
                my ( $stopid, $scheduling_desc ) = split( /\t/s, $stopline );

                next if $scheduling_desc =~ /^Virtual/s;

                my $desc = encode_entities(
                    $stops_row_of_r->{$stopid}{c_description_short} );

                my $corner     = $stops_row_of_r->{$stopid}{c_corner};
                my $cornertext = $EMPTY;

                if ($corner) {
                    $cornertext
                      = ', '
                      . ( $LONGCORNER_OF{$corner} // $corner )
                      . "ern corner";
                    $cornertext = encode_entities($cornertext);
                }

                my $latlong = $stops_row_of_r->{$stopid}{h_loca_latitude} . ','
                  . $stops_row_of_r->{$stopid}{h_loca_longitude};
                my $url
                  = 'http://maps.google.com/maps?q=@' . $latlong . '&z=18';

                my $city
                  = encode_entities( $stops_row_of_r->{$stopid}{c_city} );

                my $citytext = $EMPTY_STR;

                if ( $prevcity ne $city ) {
                    $citytext
                      = '<span style="text-decoration: underline; font-weight: bold;">'
                      . $city
                      . '</span><br />';
                    $citytext = '</p><p>' . $citytext if $prevcity;

                    $prevcity = $city;
                }

                push @{ $stoplines_corner_of{$dir} },
                    $citytext
                  . qq{$desc$cornertext (<a href="$url" target="_blank">$stopid</a>)};

                push @{ $stoplines_of{$dir} },
                  $citytext
                  . qq{$desc (<a href="$url" target="_blank">$stopid</a>)};

                push @{ $stops_of{$dir} }, $stopid;

            } ## tidy end: while ( defined( my $stopline...))

            close $ifh or die "Can't close $file: $OS_ERROR";

        } ## tidy end: foreach my $dir (@dirs)

        my @dir_objs  = map { Actium::O::Dir->instance($_) } @dirs;
        my @dir_bound = map { $_->as_bound } @dir_objs;

        ###########################################
        ### Corner list
        ###########################################

        my $cornerlist_outdata;
        open( my $clist_ofh, '>:encoding(UTF-8)', \$cornerlist_outdata )
          or die "Can't open memory location as file: $OS_ERROR";

        say $clist_ofh qq[<h3><span id="$line">$line</span></h3>\n],
          qq[<h4>$dir_bound[0]</h4>];
          
            say $clist_ofh q{<p>};
            say $clist_ofh join( '<br />', @{ $stoplines_corner_of{$dirs[0]} } );
            say $clist_ofh '</p>';
            
            if (@dirs == 2) {
          say qq[<h4>$dir_bound[1]</h4>];
                
            say $clist_ofh q{<p>};
            say $clist_ofh join( '<br />', @{ $stoplines_corner_of{$dirs[1]} } );
            say $clist_ofh '</p>';
                
            }
            
            close $clist_ofh or die "Can't close memory file: $OS_ERROR";
            
            $corner_list_of{$line} = $cornerlist_outdata;
          
        ##########################################
        #### ORIGINAL TABLE LIST
        #########################################

        # make dummy stop list if there's only one direction
        if ( @dirs == 1 ) {
            push @dirs, $EMPTY_STR;
            $stops_of{$EMPTY_STR}     = [$EMPTY_STR];
            $stoplines_of{$EMPTY_STR} = [$EMPTY_STR];
            push @dir_bound, $EMPTY_STR;

        }

        my $outdata;
        open( my $ofh, '>:encoding(UTF-8)', \$outdata )
          or die "Can't open memory location as file: $OS_ERROR";

        say $ofh <<"EOT";
<h3><span id="$line">$line</span></h3>
<table border="1" cellspacing="0" cellpadding="6">
<colgroup><col width="50%" /> <col width="50%" /></colgroup>
<tbody>
<tr><th>$dir_bound[0]</th><th>$dir_bound[1]</th></tr>
<tr>
EOT

        for my $dir (@dirs) {
            say $ofh q{<td valign=top><p>};
            say $ofh join( '<br />', @{ $stoplines_of{$dir} } );
            say $ofh '</p></td>';
        }

        say $ofh '</tr></tbody></table>';

        close $ofh or die "Can't close memory file: $OS_ERROR";

        $table_of{$line} = $outdata;

        my $type;
        $type = $linegrouptype_of_r->{$line};

        if ( $type eq 'Local' ) {
            no warnings 'numeric';
            if ( $line <= $HIGHEST_LINE_IN_FIRST_LOCALPAGE ) {
                $type = 'Local1';
            }
            else {
                $type = 'Local2';
            }
        }

        push @{ $lines_of_type{$type} },  $line;
        push @{ $tables_of_type{$type} }, $outdata;
        push @{ $corner_lists_of_type{$type}} , $cornerlist_outdata;

    } ## tidy end: foreach my $line ( u::sortbyline...)

    my %display_type_of = map { ( $_, $_ ) } keys %lines_of_type;
    my %subtypes_of = map { ( $_, [$_] ) } keys %lines_of_type;
    delete $subtypes_of{Local1};
    delete $subtypes_of{Local2};
    $subtypes_of{Local} = [qw/Local1 Local2/];

    # display and group type same as type, for now

    foreach my $type ( keys %tables_of_type ) {
        
        
        {
        my $ofh = $stoplists_folder->open_write("$type.html");

        my @lines_and_urls
          = map {"<a href='#$_'>$_</a>"} @{ $lines_of_type{$type} };

        say $ofh contents(@lines_and_urls);

        say $ofh join( "\n", @{ $tables_of_type{$type} } );
        close $ofh or die "Can't close $type.html: $OS_ERROR";
        
        }
        
        my $ofh = $stoplists_folder->open_write("c-$type.html");
        my @lines_and_urls
          = map {"<a href='#$_'>$_</a>"} @{ $lines_of_type{$type} };

        say $ofh contents(@lines_and_urls);

        say $ofh join( "\n", @{ $corner_lists_of_type{$type} } );
        close $ofh or die "Can't close c-$type.html: $OS_ERROR";
        
        
    }

    my $indexfh = $stoplists_folder->open_write('stop_index.html');
    my $cindexfh = $stoplists_folder->open_write('c_stop_index.html');

    for my $type ( 'Local', 'All Nighter', 'Transbay', 'Supplementary' ) {
        my @links;
        my @clinks;

        for my $subtype ( @{ $subtypes_of{$type} } ) {
            for my $line ( @{ $lines_of_type{$subtype} } ) {

                my $url_type = $subtype =~ s/ /-/grs;

                my $url  = lc("/rider-info/stops/$url_type/#") . $line;
                my $c_url  = lc("/rider-info/stops/c-$url_type/#") . $line;
                my $link = qq{<a href="$url">$line</a>};
                my $c_link = qq{<a href="$c_url">$line</a>};
                push @links, $link;
                push @clinks, $c_link;

            }

        }

        say $indexfh "<p><strong>$type</strong></p>";
        say $indexfh contents(@links);

        say $cindexfh "<p><strong>$type</strong></p>";
        say $cindexfh contents(@clinks);

    } ## tidy end: for my $type ( 'Local',...)

    close $indexfh or die "Can't close stop_index.html: $OS_ERROR";
    close $cindexfh or die "Can't close c_stop_index.html: $OS_ERROR";

    $htmlversion_cry->done;

    $makehtml_cry->done;

    return;

} ## tidy end: sub START

const my $CONTENTS_COLUMNS => 10;

sub contents {

    my @lines_and_urls = @_;
    my $contents_text;
    open my $ofh, '>', \$contents_text
      or die "Can't open memory location for writing: $OS_ERROR";

    say $ofh '<table border="0" cellspacing="0" cellpadding="10">';
    say $ofh '<tr>';

    for my $i ( 0 .. $#lines_and_urls ) {
        my $r_and_u = $lines_and_urls[$i];
        print $ofh "<td>$r_and_u</td>";
        if ( not( ( $i + 1 ) % $CONTENTS_COLUMNS ) ) {
            print $ofh "</tr>\n<tr>";
        }

    }
    say $ofh '</tr></table>';

    close $ofh or die $OS_ERROR;

    return $contents_text;

} ## tidy end: sub contents

1;
