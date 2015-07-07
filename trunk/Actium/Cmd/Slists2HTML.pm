# Actium/Cmd/Slists2HTML.pm

# Produces HTML tables of stop lists

use 5.016;
use warnings;

package Actium::Cmd::Slists2HTML 0.010;

use Actium::Preamble;

use Actium::O::Folders::Signup;
use Actium::O::Dir;

#use Actium::Constants;
use Actium::Sorting::Line ('sortbyline');
use Actium::Util('filename');
use Actium::Term;
use Actium::Cmd::Config::ActiumFM ('actiumdb');

use HTML::Entities;

sub HELP {
    say 'No help yet, sorry.';
}

my $count;
my %order_of = map { $_ => $count++ } @DIRCODES;

sub START {

    emit "Making HTML files of stop lists";

    my $class  = shift;
    my %params = @_;

    my $config_obj = $params{config};

    my $signup   = Actium::O::Folders::Signup->new;
    my $actiumdb = actiumdb($config_obj);

    my $stoplists_folder      = $signup->subfolder('slists');
    my $stoplists_line_folder = $stoplists_folder->subfolder('line');

    #    my $linehtml_folder       = $stoplists_folder->subfolder('linehtml');

    $actiumdb->ensure_loaded('Stops_Neue');

    emit 'Getting stop descriptions from FileMaker';

    my $stops_row_of_r = $actiumdb->all_in_columns_key(
        qw/Stops_Neue c_description_short h_loca_latitude h_loca_longitude
          c_city/
    );

    emit_done;

    my $linegrouptype_of_r =
      $actiumdb->all_in_column_key(qw/Lines LineGroupType/);

    emit "Creating HTML versions of stop lists";

    my @files = $stoplists_line_folder->glob_plain_files('*.txt');
    @files = map { filename($_) } @files;

    my %dirs_of;

    foreach my $file (@files) {
        my ( $line, $dir, $ext ) = split( /[-.]/, $file );
        push @{ $dirs_of{$line} }, $dir;
    }

    my %table_of;
    my %tables_of_type;
    my %lines_of_type;

    foreach my $line ( sortbyline keys %dirs_of ) {

        next if $LINE_SHOULD_BE_SKIPPED{$line};

        emit_over $line;

        my @dirs = @{ $dirs_of{$line} };
        @dirs = sort { $order_of{$a} <=> $order_of{$b} } @dirs;
        my %stops_of;
        my %stoplines_of;

        foreach my $dir (@dirs) {

            my $file = "$line-$dir.txt";
            my $ifh  = $stoplists_line_folder->open_read($file);
            binmode $ifh, ':encoding(MacRoman)';

            # HORRIBLE KLUDGE BECAUSE I CAN'T GET ODBC TO READ UTF8 DATA

            my $headerline = readline($ifh);    # thrown away

            my $prevcity = $EMPTY_STR;

            while ( defined( my $stopline = readline($ifh) ) ) {
                chomp $stopline;
                my ( $stopid, $scheduling_desc ) = split( /\t/, $stopline );

                next if $scheduling_desc =~ /^Virtual/;

                my $desc = encode_entities(
                    $stops_row_of_r->{$stopid}{c_description_short} );

                my $latlong =
                    $stops_row_of_r->{$stopid}{h_loca_latitude} . ','
                  . $stops_row_of_r->{$stopid}{h_loca_longitude};
                my $url =
                  'http://maps.google.com/maps?q=@' . $latlong . "&z=18";

                my $city =
                  encode_entities( $stops_row_of_r->{$stopid}{c_city} );

                my $citytext = $EMPTY_STR;

                if ( $prevcity ne $city ) {
                    $citytext =
'<span style="text-decoration: underline; font-weight: bold;">'
                      . $city
                      . '</span><br />';
                    $citytext = '</p><p>' . $citytext if $prevcity;

                    $prevcity = $city;
                }

                #push @{ $stoplines_of{$dir} }, $stopid . ' =&gt; ' . $desc;
                push @{ $stoplines_of{$dir} },
                  $citytext
                  . qq{$desc (<a href="$url" target="_blank">$stopid</a>)};

                push @{ $stops_of{$dir} }, $stopid;

                #my $savedline = $stopline =~ s/\t/ =&gt; /r;
                #push @{ $stoplines_of{$dir} }, $savedline;
            }    ## tidy end: while ( defined( my $stopline...))

            close $ifh or die "Can't close $file: $OS_ERROR";

        }    ## tidy end: foreach my $dir (@dirs)

        my @dir_objs  = map { Actium::O::Dir->new($_) } @dirs;
        my @dir_bound = map { $_->as_bound } @dir_objs;

        # make dummy stop list if there's only one direction
        if ( @dirs == 1 ) {
            push @dirs, $EMPTY_STR;
            $stops_of{$EMPTY_STR}     = [$EMPTY_STR];
            $stoplines_of{$EMPTY_STR} = [$EMPTY_STR];
            push @dir_bound, $EMPTY_STR;

        }

        my $outdata;
        open( my $ofh, '>:utf8', \$outdata )
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
            say $ofh join( "<br />", @{ $stoplines_of{$dir} } );
            say $ofh '</p></td>';
        }

        say $ofh "</tr></tbody></table>";

        close $ofh or die "Can't close memory file: $OS_ERROR";

        $table_of{$line} = $outdata;
        
        my $type;
        $type = $linegrouptype_of_r->{$line};

        if ( $type eq 'Local' ) {
            no warnings 'numeric';
            if ( $line <= 70 ) {
                $type = 'Local1';
            }
            else {
                $type = 'Local2';
            }
        }

        push @{ $lines_of_type{$type} }, $line;
        push @{ $tables_of_type{$type} }, $outdata;

    }    ## tidy end: foreach my $line ( sortbyline...)

    my %display_type_of = map { $_, $_ } keys %lines_of_type;
    my %subtypes_of = map { $_, [$_] } keys %lines_of_type;
    delete $subtypes_of{Local1};
    delete $subtypes_of{Local2};
    $subtypes_of{Local} = [qw/Local1 Local2/];

    # display and group type same as type, for now

    foreach my $type ( keys %tables_of_type ) {

        my $ofh = $stoplists_folder->open_write("$type.html");

        my @lines_and_urls =
          map { "<a href='#$_'>$_</a>" } @{ $lines_of_type{$type} };

        say $ofh contents(@lines_and_urls);

=for comment
        say $ofh '<table border="0" cellspacing="0" cellpadding="10">';
        say $ofh '<tr>';

        my @lines = @{ $lines_of_type{$type} };

        for my $i ( 0 .. $#lines ) {
            my $line = $lines[$i];
            print $ofh "<td><a href='#$line'>$line</a></td>";
            if ( not( ( $i + 1 ) % 10 ) ) {
                print $ofh "</tr>\n<tr>";
            }

        }
        say $ofh "</tr></table>";
        
=cut

        say $ofh join( "\n", @{ $tables_of_type{$type} } );
        close $ofh or die "Can't close $type.html: $OS_ERROR";
    }    ## tidy end: foreach my $type ( keys %tables_of_type)

    my $indexfh = $stoplists_folder->open_write("stop_index.html");

    #for my $type (keys %subtypes_of) {
    for my $type ( 'Local', 'All Nighter', 'Transbay', 'Supplementary' ) {
        my @links;

        #next if ($type =~ /Broadway/ or $type =~ /Dumbarton/);
        for my $subtype ( @{ $subtypes_of{$type} } ) {
            for my $line ( @{ $lines_of_type{$subtype} } ) {

                my $url_type = $subtype =~ s/ /-/gr;

                my $url  = lc("/rider-info/stops/$url_type/#") . $line;
                my $link = qq{<a href="$url">$line</a>};
                push @links, $link;

            }

        }

        say $indexfh "<p><strong>$type</strong></p>";
        say $indexfh contents(@links);

    }

    close $indexfh or die "Can't close stop_index.html: $OS_ERROR";

    emit_done;

    emit_done;

}    ## tidy end: sub START

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
        if ( not( ( $i + 1 ) % 10 ) ) {
            print $ofh "</tr>\n<tr>";
        }

    }
    say $ofh "</tr></table>";

    close $ofh;

    return $contents_text;

}    ## tidy end: sub contents
