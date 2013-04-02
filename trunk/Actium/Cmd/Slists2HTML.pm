# Actium/Cmd/Slists2HTML.pm

# Produces HTML tables of stop lists

# Subversion: $Id$

use 5.014;
use warnings;

package Actium::Cmd::Slists2HTML 0.002;

use Actium::O::Folders::Signup;
use Actium::O::Dir;
use Actium::Constants;
use Actium::Sorting::Line ('sortbyline');
use Actium::Util('filename');
use Actium::Term;
use English '-no_match_vars';

use HTML::Entities;

sub HELP {
    say 'No help yet, sorry.';
}

my $count;
my %order_of = map { $_ => $count++ } @DIRCODES;

sub START {

    my $signup                = Actium::O::Folders::Signup->new();
    my $stoplists_folder      = $signup->subfolder('slists');
    my $stoplists_line_folder = $stoplists_folder->subfolder('line');
    #    my $linehtml_folder       = $stoplists_folder->subfolder('linehtml');

    my $xml_db = $signup->load_xml;
    $xml_db->ensure_loaded('Stops');

    emit 'Getting stop descriptions from FileMaker export';

    my $dbh = $xml_db->dbh;

    my $stops_row_of_r
      = $xml_db->all_in_columns_key(qw/Stops DescriptionListF GoogleURL CityF/);

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

            my $headerline = readline($ifh);    # thrown away

            my $prevcity = $EMPTY_STR;

            while ( defined( my $stopline = readline($ifh) ) ) {
                chomp $stopline;
                my ( $stopid, $scheduling_desc ) = split( /\t/, $stopline );

                next if $scheduling_desc =~ /^Virtual/;

                my $desc = encode_entities(
                    $stops_row_of_r->{$stopid}{DescriptionListF} );
                my $url  = $stops_row_of_r->{$stopid}{GoogleURL};
                my $city = encode_entities($stops_row_of_r->{$stopid}{CityF});

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
                    $citytext .
                      qq{$desc (<a href="$url" target="_blank">$stopid</a>)}
                ;

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
        given ($route) {
            when (/BS[DHN]/) {
                $type = 'Broadway Shuttle';
            }
            when ('800') {
                $type = 'Transbay';
            }
            when (/^DB/) {
                $type = 'Dumbarton Express';
            }
            when (/^[A-Z].*/) {
                $type = 'Transbay';
            }
            when (/6\d\d/) {
                $type = 'Supplementary';
            }
            when (/8\d\d/) {
                $type = 'All Nighter';
            }
            default {
                $type = 'Local';
            }
        } ## tidy end: given

        push @{ $routes_of_type{$type} }, $route;
        push @{ $tables_of_type{$type} }, $outdata;

    } ## tidy end: foreach my $route ( sortbyline...)

    foreach my $type ( keys %tables_of_type ) {

        my $ofh = $stoplists_folder->open_write("$type.html");

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

        say $ofh join( "\n", @{ $tables_of_type{$type} } );
        close $ofh or die "Can't close $type.html: $OS_ERROR";
    } ## tidy end: foreach my $type ( keys %tables_of_type)

    emit_done;

} ## tidy end: sub START
