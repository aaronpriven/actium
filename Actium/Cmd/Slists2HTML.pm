# Actium/Cmd/Slists2HTML.pm

# Produces HTML tables of stop lists

# Subversion: $Id$

use 5.016;
use warnings;

package Actium::Cmd::Slists2HTML 0.007;

use Actium::Preamble;

use Actium::O::Folders::Signup;
use Actium::O::Dir;
#use Actium::Constants;
use Actium::Sorting::Line ('sortbyline');
use Actium::Util('filename');
use Actium::Term;

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

    emit 'Getting stop descriptions from FileMaker export';

    my $dbh = $actiumdb->dbh;

    my $stops_row_of_r
      = $actiumdb->all_in_columns_key
      (qw/Stops_Neue c_description_short h_loca_latitude h_loca_longtitude 
          c_city/);

    emit_done;

    emit "Creating HTML versions of stop lists";

    my @files = $stoplists_line_folder->glob_plain_files('*.txt');
    @files = map { filename($_) } @files;

    my %dirs_of;

    foreach my $file (@files) {
        my ( $route, $dir, $ext ) = split( /[-.]/, $file );
        push @{ $dirs_of{$route} }, $dir;
    }

    my %table_of;
    my %tables_of_type;
    my %routes_of_type;

    foreach my $route ( sortbyline keys %dirs_of ) {

        next if $LINE_SHOULD_BE_SKIPPED{$route};

        emit_over $route;

        my @dirs = @{ $dirs_of{$route} };
        @dirs = sort { $order_of{$a} <=> $order_of{$b} } @dirs;
        my %stops_of;
        my %stoplines_of;

        foreach my $dir (@dirs) {

            my $file = "$route-$dir.txt";
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
                    $stops_row_of_r->{$stopid}{h_loca_latitude} . ',' . 
                    $stops_row_of_r->{$stopid}{h_loca_longitude} 
                     ;
                my $url =  'http://maps.google.com/maps?q=@' . $latlong . "&z=18";
                    
                my $city = encode_entities( $stops_row_of_r->{$stopid}{c_city} );

                my $citytext = $EMPTY_STR;

                if ( $prevcity ne $city ) {
                    $citytext
                      = '<span style="text-decoration: underline; font-weight: bold;">'
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
            } ## tidy end: while ( defined( my $stopline...))

            close $ifh or die "Can't close $file: $OS_ERROR";

        } ## tidy end: foreach my $dir (@dirs)

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
<h3><span id="$route">$route</span></h3>
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

        $table_of{$route} = $outdata;

        my $type;
        for ($route) {
            if (/BS[DHN]/) {
                $type = 'Broadway Shuttle';
                next;
            }
            if ($_ eq '800') {
                $type = 'Transbay';
                next;
            }
            if (/^DB/) {
                $type = 'Dumbarton Express';
                next;
            }
            if (/^[A-Z].*/) {
                $type = 'Transbay';
                next;
            }
            if (/6\d\d/) {
                $type = 'Supplementary';
                next;
            }
            if (/8\d\d/) {
                $type = 'All Nighter';
                next;
            }
                $type = 'Local';
        } ## tidy end: given

        push @{ $routes_of_type{$type} }, $route;
        push @{ $tables_of_type{$type} }, $outdata;

    } ## tidy end: foreach my $route ( sortbyline...)

    my %display_type_of = map { $_, $_ } keys %routes_of_type;
    my %subtypes_of = map { $_, [$_] } keys %routes_of_type;

    # display and group type same as type, for now

    foreach my $type ( keys %routes_of_type ) {
        my $final_idx = $#{ $routes_of_type{$type} };
        my $total     = $final_idx + 1;
        next unless ( $total > 50 );

        $subtypes_of{$type} = [];    # clear subtypes

        my @routes = @{ $routes_of_type{$type} };
        my @tables = @{ $tables_of_type{$type} };

        my $num_pages = ceil( $total / 40 );

        my $lists_per_page = ceil( $total / $num_pages );

        my $count = 0;
        my $it = natatime $lists_per_page, ( 0 .. $final_idx );
        while ( my @indexes = $it->() ) {
            my $initial_route = $routes[ $indexes[0] ];
            my $final_route   = $routes[ $indexes[-1] ];
            $count++;

            my $newtype = "${type}$count";
            $display_type_of{$newtype}
              = encode_entities("$type (${initial_route}\x{2013}$final_route)");
            # 2013 is en dash

            $routes_of_type{$newtype} = [ @routes[@indexes] ];
            $tables_of_type{$newtype} = [ @tables[@indexes] ];
            push @{ $subtypes_of{$type} }, $newtype;

        }

        delete $routes_of_type{$type};
        delete $tables_of_type{$type};
        #delete $display_type_of{$type};

    } ## tidy end: foreach my $type ( keys %routes_of_type)

    foreach my $type ( keys %tables_of_type ) {

        my $ofh = $stoplists_folder->open_write("$type.html");

        my @routes_and_urls
          = map {"<a href='#$_'>$_</a>"} @{ $routes_of_type{$type} };

        say $ofh contents(@routes_and_urls);


=for comment
        say $ofh '<table border="0" cellspacing="0" cellpadding="10">';
        say $ofh '<tr>';

        my @routes = @{ $routes_of_type{$type} };

        for my $i ( 0 .. $#routes ) {
            my $route = $routes[$i];
            print $ofh "<td><a href='#$route'>$route</a></td>";
            if ( not( ( $i + 1 ) % 10 ) ) {
                print $ofh "</tr>\n<tr>";
            }

        }
        say $ofh "</tr></table>";
        
=cut

        say $ofh join( "\n", @{ $tables_of_type{$type} } );
        close $ofh or die "Can't close $type.html: $OS_ERROR";
    } ## tidy end: foreach my $type ( keys %tables_of_type)

    my $indexfh = $stoplists_folder->open_write("stop_index.html");
    
    
    #for my $type (keys %subtypes_of) {
    for my $type ('Local', 'All Nighter' , 'Transbay', 'Supplementary') {
    my @links;
        #next if ($type =~ /Broadway/ or $type =~ /Dumbarton/);
         for my $subtype (@{$subtypes_of{$type}}) {
             for my $route ( @{$routes_of_type{$subtype}} ) {
                 
                my $url_type = $subtype =~ s/ /-/gr;
             
                my $url = lc("/rider-info/stops/$url_type/#") . $route;
                my $link = qq{<a href="$url">$route</a>};
                push @links, $link;
                
             }
             
         }
         
         say $indexfh "<p><strong>$type</strong></p>";
         say $indexfh contents(@links);

    }
    
   
    

=for comment
    
    say $indexfh '<ul>';
    
    foreach my $type (sort keys %display_type_of) {
        
        next if ($type =~ /Broadway/ or $type =~ /Dumbarton/);
        
        my $url_type = lc($type);
        $url_type =~ s/ /-/g;
        
        print $indexfh qq{<li><a href="/rider-info/stops/$url_type/">};
        say $indexfh qq{$display_type_of{$type}</a></li>};
        
    }
    say $indexfh '</ul>';
    
=cut

    close $indexfh or die "Can't close stop_index.html: $OS_ERROR";

    emit_done;
    
    emit_done;

} ## tidy end: sub START

sub contents {

    my @routes_and_urls = @_;
    my $contents_text;
    open my $ofh, '>', \$contents_text
      or die "Can't open memory location for writing: $OS_ERROR";

    say $ofh '<table border="0" cellspacing="0" cellpadding="10">';
    say $ofh '<tr>';

    for my $i ( 0 .. $#routes_and_urls ) {
        my $r_and_u = $routes_and_urls[$i];
        print $ofh "<td>$r_and_u</td>";
        if ( not( ( $i + 1 ) % 10 ) ) {
            print $ofh "</tr>\n<tr>";
        }

    }
    say $ofh "</tr></table>";

    close $ofh;

    return $contents_text;

} ## tidy end: sub contents
