# Actium/Flagspecs.pm

# Subversion: $Id$

1;
__END__

use warnings;
use strict;

package Actium::Flagspecs;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Actium::Sorting ('sortbyline');
use Actium::Util qw(sk jk jt keyreadable);
use Actium::Union ('ordered_union');
use Actium::HastusASI::Util(':ALL');
use Actium::HastusASI::Db;
use Actium::Constants;
use Actium::Term;
use Actium::Signup;
use Actium::Flagspecs::RelevantPlaces(':ALL');

use English('-no_match_vars');
use Text::Wrap ('wrap');
use Algorithm::Diff('sdiff');
use List::MoreUtils('any');
use File::Spec;
use Text::Trim;

use Data::Dumper;

use Readonly;

Readonly my $CULL_THRESHOLD    => 10;
Readonly my $OVERRIDE_FILENAME => 'flagspec_override.txt';

my %placelist_of;    # $placelist_of{$pat_rdi} = list of places
my %pats_of;         # $pats_of{$routedir}{$placelist} = PAT identifier
my %num_trips_of_pat;
my %num_trips_of_routedir;
my %plainroutes_of_stop;
# $plainroutes_of_stop{$stop_ident}{$route} = number of times used
my %stops_of_pat;
my %routes_of_stop;
# $routes_of_stop{$stop_ident}{$route} = number of times used
#my %pats_of_stop;    # $pats_of_stop{$stop_ident}{$routedir}{$pat_ident} =
# $patinfo anonhash (Place, NextPlace, Connections)
my %combos_of_stop;

#my $stopdata;

sub flagspecs_START {

    my $signup = Actium::Signup->new();

    {
        my $hasidir = $signup->subdir('hasi');
        my $hasi_db = Actium::HastusASI::Db->new( $hasidir->get_dir(),
            ( '/tmp/' . $hasidir->get_signup() . '_' ) );
        $hasi_db->load(qw(PAT TRP));
        build_place_and_stop_lists($hasi_db);
        build_trip_quantity_lists($hasi_db);
    }

    cull_placepats();

    # free up memory - no longer needed
    %num_trips_of_pat      = ();
    %num_trips_of_routedir = ();
    %stops_of_pat          = ();

    delete_last_stops();

    load_timepoint_data($signup);
    build_placelist_descriptions($signup);

    build_pat_combos($signup);

    my $overrides_of_r = process_combo_overrides($signup);

    return;

} ## tidy end: sub flagspecs_START

sub stop_obj {
    state %stop_obj;
    my $stop_ident = shift;

    if ( exists $stop_obj{$stop_ident} ) {
        $stop_obj{$stop_ident}
          = Actium::Flagspecs::Stop->new($stop_ident);
    }
    return Actium::Flagspecs::Stop->new($stop_ident);
}

sub build_place_and_stop_lists {

    my $hasi_db = shift;

    emit 'Building lists of places and stops';

    my $eachpat = $hasi_db->each_row_where( 'PAT',
        q{WHERE NOT IsInService = '' ORDER BY Route} );

    my $dbh = $hasi_db->dbh();
    my $tps_sth
      = $dbh->prepare('SELECT * FROM TPS WHERE PAT_id = ? ORDER BY TPS_id');

    my $prevroute = $EMPTY_STR;
  PAT:
    while ( my $pat = $eachpat->() ) {

        my $pat_ident = $pat->{Identifier};
        my $route     = $pat->{Route};
        if ( $route ne $prevroute ) {
            emit_over $route ;
            $prevroute = $route;
        }

        next PAT if $route eq 'BSH' or $route eq '399';
        # skip Broadway Shuttle

        my @tps = @{
            $dbh->selectall_arrayref( $tps_sth, { Slice => {} },
                $pat->{PAT_id} )
          };

        # SKIP 600 ROUTES
        if ( $route =~ /\A 6\d\d \z/sx ) {
            for my $tps_row (@tps) {
                my $stop_obj = stop_obj($tps_row->{StopIdentifier});
                    $stop_obj->add_plainroute($route);
                    $stop_obj->add_route($route);
                    }
                    next PAT;
            }

            my $routedir = jk( $route,    $pat->{DirectionValue} );
            my $pat_rdi  = jk( $routedir, $pat_ident );

            my $prevplace = $EMPTY_STR;
            my $prevstop  = $EMPTY_STR;
            my (@places, @intermediate_stops, @all_stops );
            
            # goes through list, making up place patterns and establishing
            # where stops fall in that place pattern.
            
          TPS:

            for my $tps_row (@tps) {

                my $place = $tps_row->{Place};
                $place =~ s/-[AD12]\z//sx;
                my $stop_ident = $tps_row->{StopIdentifier};
                my $stop_obj = stop_obj($tps_row->{StopIdentifier});
                
                if ( $stop_ident eq $prevstop ) {    # same stop
                    next TPS if ( not $place ) or ( $place eq $prevplace );

                    # skip stop entirely unless place is changed
                    
                    $all_stops[-1]->{Place} = $place;

                    # if place changed, make previous stop this new place

                    push @places, $place;
                    $prevplace = $place;

                    next TPS;
                }

                if ( $place and $place ne $prevplace ) {    # different place
                    push @places, $place;
                    $prevplace = $place;

                    foreach (@intermediate_stops) {
                        $_->{NextPlace} = $place;
                    }
                    @intermediate_stops = ();
                }

           # TODO - ADD CONNECTIONS
           # Check this stop for connections. If it finds one, do something like
           # foreach my $patinfo (@all_stops) {
           #     $patinfo->{Connections}{BART} = 1;
           # }

                my $patinfo = { Place => $prevplace };
                push @all_stops, $patinfo;
                set_pats_of_stop( $stop_ident, $routedir, $pat_ident,
                    $patinfo );
                #$pats_of_stop{$stop_ident}{$routedir}{$pat_ident} = $patinfo;
                $routes_of_stop{$stop_ident}{$route}++;
                push @{ $stops_of_pat{$pat_rdi} }, $stop_ident;
                push @intermediate_stops, $patinfo if not $place;

                # references to the same anonymous hash

            } ## tidy end: for my $tps_row (@tps)
            $all_stops[-1]->{Last} = 1;

            # Place lists

            my $placelist = jk(@places);

            push @{ $pats_of{$routedir}{$placelist} }, $pat_rdi;
            $placelist_of{$pat_rdi} = $placelist;

            # now we have cross-indexed the pattern ident
            # and its place listing

        } ## tidy end: while ( my $pat = $eachpat...)
        emit_done;

        return;

    } ## tidy end: sub build_place_and_stop_lists

    sub build_trip_quantity_lists {
        my $hasi_db = shift;

        emit 'Building lists of trip quantities';

        my $next_trp = $hasi_db->each_row_eq(qw(TRP IsPublic X));

      TRP:
        while ( my $trp = $next_trp->() ) {

            my $pat_ident = $trp->{Pattern};
            my $route     = $trp->{RouteForStatistics};
            my $pat       = $hasi_db->row( 'PAT', jk( $route, $pat_ident ) );
            my $dir       = $pat->{DirectionValue};
            my $routedir  = jk( $route, $dir );
            my $pat_rdi   = jk( $route, $dir, $pat_ident );
            next TRP unless exists $placelist_of{$pat_rdi};

            my $placelist = $placelist_of{$pat_rdi};

            $num_trips_of_pat{$routedir}{$placelist}++;
            $num_trips_of_routedir{$routedir}++;

        }

        emit_done;

        return;

    } ## tidy end: sub build_trip_quantity_lists

    sub cull_placepats {

        emit 'Combining duplicate place-patterns';

        foreach my $routedir ( sortbyline( keys %num_trips_of_pat ) ) {

            # combine placelists with more than one identifier

            my @placelists = keys %{ $num_trips_of_pat{$routedir} };

            for my $placelist (@placelists) {
                my @pat_rdis = @{ $pats_of{$routedir}{$placelist} };
                next if @pat_rdis == 1;
                # we know there are duplicate identifiers now

                #$pats_of{$routedir}{$placelist} = [ shift @pat_rdis ];
                $pats_of{$routedir}{$placelist} = [ $pat_rdis[0] ];

                delete_identifiers( $routedir, @pat_rdis );
                # will keep the first one, and delete the rest

            }

        } ## tidy end: foreach my $routedir ( sortbyline...)

        emit_done;

        emit 'Culling place-patterns';

        foreach my $routedir ( sortbyline( keys %num_trips_of_pat ) ) {

            # delete subset place patterns, if possible
            my $threshold = $num_trips_of_routedir{$routedir} / $CULL_THRESHOLD;
            my @placelists = sort { length $b <=> length $a }
              keys %{ $num_trips_of_pat{$routedir} };

            my $longest = shift @placelists;

            while (@placelists) {
                foreach my $idx ( 0 .. $#placelists ) {
                    my $thislist = $placelists[$idx];

                    if ($longest =~ /$thislist$/sx
                        or ( index( $longest, $thislist ) != -1
                            and $num_trips_of_pat{$routedir}{$thislist}
                            < $threshold )
                      )
                    {
             #say keyreadable("DELETING: [[$routedir\n$thislist\n$longest\n]]");
                        delete_placelist_from_lists( $routedir, $thislist,
                            $longest );
                        undef $placelists[$idx];
                    }
                }

                @placelists = grep {defined} @placelists;
                $longest = shift @placelists;
            } ## tidy end: while (@placelists)

        } ## tidy end: foreach my $routedir ( sortbyline...)

        emit_done;

        return;

    } ## tidy end: sub cull_placepats

    {
        my %pats_of_stop;

        sub dump_pats_of_stop {
            return Dumper(%pats_of_stop);
        }

        sub set_pats_of_stop {
            my ( $stop_ident, $routedir, $pat_ident, $patinfo ) = @_;
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
            my $routedir = shift;
            return keys %{ $pats_of_stop{$routedir} };
        }

        sub delete_identifiers {
            # delete identifiers in lists for identical place patterns

            my ( $routedir, $replacement_rdi, @pat_rdis ) = @_;
            my ( $route, $dir ) = sk($routedir);

            my $replacement_ident = $replacement_rdi;
            $replacement_ident =~ s/.*$KEY_SEPARATOR//sx;

            # %placelist_of, %stops_of_pat, %pats_of_stop
            foreach my $pat_rdi (@pat_rdis) {
                my $pat_ident = $pat_rdi;
                $pat_ident =~ s/.*$KEY_SEPARATOR//sx;
                my @stops = @{ $stops_of_pat{$pat_rdi} };
                delete $placelist_of{$pat_rdi};
                delete $stops_of_pat{$pat_rdi};
                foreach my $stop_ident (@stops) {

                    if (scalar
                        keys %{ $pats_of_stop{$stop_ident}{$routedir} } == 1 )
                    {
                        $pats_of_stop{$stop_ident}{$routedir}
                          {$replacement_ident}
                          = $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                    }

                    delete $pats_of_stop{$stop_ident}{$routedir}{$pat_ident};
                    $routes_of_stop{$stop_ident}{$route}--;
                }

            } ## tidy end: foreach my $pat_rdi (@pat_rdis)

            return;

        } ## tidy end: sub delete_identifiers

        sub delete_last_stops {

            emit 'Deleting final stops';

            foreach my $stop ( keys %pats_of_stop ) {
                foreach my $routedir ( keys %{ $pats_of_stop{$stop} } ) {
                    my ( $route, $dir ) = sk($routedir);
                    foreach my $pat_ident (
                        keys %{ $pats_of_stop{$stop}{$routedir} } )
                    {

                        next
                          unless
                            exists $pats_of_stop{$stop}{$routedir}{$pat_ident}
                              {Last};

                        next if $routes_of_stop{$stop}{$route} == 1;

                        delete $pats_of_stop{$stop}{$routedir}{$pat_ident};
                        if ( not %{ $pats_of_stop{$stop}{$routedir} } ) {
                            delete $pats_of_stop{$stop}{$routedir};
                        }
                        $routes_of_stop{$stop}{$route}--;

                    }
                } ## tidy end: foreach my $routedir ( keys...)
            } ## tidy end: foreach my $stop ( keys %pats_of_stop)
            emit_done;

            return;

        } ## tidy end: sub delete_last_stops

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
        my %short_code_of;

        sub build_pat_combos {
            my $signup = shift;

            emit 'Building pattern combinations';

            my $short = 'aa';

            foreach my $stop ( keys_pats_of_stop() ) {
                foreach my $routedir ( routedirs_of_stop($stop) ) {

                    my @pat_idents = pat_idents_of( $stop, $routedir );

                    my @placelists
                      = map { $placelist_of{ jk( $routedir, $_ ) } }
                      @pat_idents;

                    my $combokey = jt(@placelists);
                    my $shortkey = jt( $routedir, $combokey );
                    $short_code_of{$shortkey} = $short++
                      unless exists $short_code_of{$shortkey};

                    $combos{$routedir}{$combokey} = \@placelists;
                    push @{ $combos_of_stop{$stop}{$routedir} }, $combokey;

                }
            }

            emit_done;
            return;

        } ## tidy end: sub build_pat_combos

        sub process_combo_overrides {
            my $signup = shift;
            my $file
              = File::Spec->catfile( $signup->get_dir(), $OVERRIDE_FILENAME );
            my $bakfile = "$file.bak";

            # first, we input the file, receiving the user overrides

            read_combo_overrides($file);

            # then, we output the file, including all current overrides and
            # all the old ones, too

            unlink $bakfile if -e $bakfile;
            if ( -e $file ) {
                rename $file, $bakfile;
            }

            write_combo_overrides($file);

            return \%override_of;

        } ## tidy end: sub process_combo_overrides

        Readonly my $ENTRY_DIVIDER => ( "=" x 78 );

        sub write_combo_overrides {
            my $file = shift;

            emit "Writing override file $OVERRIDE_FILENAME";

            open my $out, '>', $file or die "Can't open $file for writing";

            Readonly my $patternpad => $SPACE x 7;

            my $oldfh = select($out);

            local $Text::Wrap::unexpand = 1;

            foreach my $routedir ( sortbyline keys %combos ) {

                my ( $route, $dir ) = sk($routedir);

                my @thesecombos = keys %{ $combos{$routedir} };

                foreach my $combokey (@thesecombos) {
                    my $shortkey = jt( $routedir, $combokey );
                    say $comments_of{$shortkey} if $comments_of{$shortkey};
                    printf "Line %-3s %68s\n", $route,
                      $short_code_of{$shortkey};
                    my @placelists = @{ $combos{$routedir}{$combokey} };
                    #say $patternpad, 'Pattern',
                    #  ( scalar @placelists ? '(s)' : $EMPTY_STR ),
                    #  q{:};
                    foreach my $placelist (@placelists) {
                        say wrap (
                            "=" . $patternpad,
                            "=" . $patternpad . $patternpad,
                            description_of( $routedir, $placelist ),
                        );
                    }
                    say '= Computer: ', destination_of( $dir, @placelists );
                    say 'You: ', $override_of{$shortkey} || $EMPTY_STR;
                    say $ENTRY_DIVIDER;
                } ## tidy end: foreach my $combokey (@thesecombos)

            } ## tidy end: foreach my $routedir ( sortbyline...)

            say 'Codes:';
            foreach my $shortkey ( sort keys %short_code_of ) {
                say "$short_code_of{$shortkey}\t$shortkey";
            }

            select($oldfh);

            emit_done;

            return;

        } ## tidy end: sub write_combo_overrides

     #    my $stopdata = $signup->mergeread('Stops.csv');
     #    my $column = $stopdata->column_order_of('DescriptionF');
     #
     #    foreach my $stop ( sort (keys_pats_of_stop()) ) {
     #       my ($row) = $stopdata->rows_where( 'PhoneID', $stop );
     #       my $stopdesc = $row->[$column] ;
     #
     #       foreach my $routedir ( routedirs_of_stop($stop) ) {
     #           foreach my $combokey ( @{$combos_of_stop{$stop}{$routedir}} ) {
     #              print "$stop\t$stopdesc\t" ;
     #              say $combolong{$combokey};
     #           }
     #
     #       }
     #
     #    }

        sub read_combo_overrides {

            my $file = shift;

            my %input_override_of;
            my %input_descriptions_of;
            my %input_comments_of;
            my $chunk;

            open my $in, '<', $file
              or die "Can't open $file for input: $OS_ERROR";

            local $/ = $ENTRY_DIVIDER . "\n";

            while ( $chunk = <$in> ) {
                last if $chunk =~ /^Codes:/;

                my @lines = split( "\n", $chunk );
                my $comments    = join( "\n", grep {/\A#/} @lines );
                my $description = join( "\n", grep {/\A=/} @lines );
                @lines = grep { $_ and not(m/\A[#=]/) } @lines;

                my ( undef, $line, $short ) = split( $SPACE, shift @lines );
                my $override = shift;
                $override =~ s/ \A  You:   //sx;
                $override =~ s/ \A  \s+    //sx;
                $override =~ s/ \s+ \z     //sx;

                $input_override_of{$short}     = $override    if $override;
                $input_comments_of{$short}     = $comments    if $comments;
                $input_descriptions_of{$short} = $description if $description;

            }

            close $in or die "Can't close $file for input: $OS_ERROR";

            # read codes

            my @lines = split( /\n/, $chunk );
            shift @lines;    # the word "Codes:"

            my %shortkey_of;
            foreach my $line (@lines) {
                my ( $short, $shortkey ) = split( "\t", $line, 2 );
                $shortkey_of{$short} = $shortkey;
            }

            foreach my $short ( keys %input_override_of ) {
                my ( $routedir, $combokey ) = split( "\t", $short, 2 );
                if ( exists( $combos{$routedir}{$combokey} ) ) {
                    $override_of{ $shortkey_of{$short} }
                      = $input_override_of{$short};
                }
                else {
                    $preserved_override_of{ $shortkey_of{$short} }
                      = $input_override_of{$short};
                }

            }

            foreach my $short ( keys %input_comments_of ) {
                $comments_of{ $shortkey_of{$short} }
                  = $input_comments_of{$short};
            }

        } ## tidy end: sub read_combo_overrides

    }

    {

        my $timepoint_data;

        sub load_timepoint_data {
            my $signup = shift;
            $timepoint_data = $signup->mergeread('Timepoints.csv');
            return;
        }

        sub destination_of {
            my $dir        = shift;
            my @placelists = @_;
            my $column     = $timepoint_data->column_order_of('DestinationF');

            my %destinations;
            my @place_arys;

            foreach my $placelist (@placelists) {
                push @place_arys, [ sk($placelist) ];
            }

            my @union = ordered_union(@place_arys);
            my %order;

            foreach ( 0 .. $#union ) {
                $order{ $union[$_] } = $_;
            }

            foreach my $placelist (@placelists) {
                my $place = $placelist;
                $place =~ s/.*$KEY_SEPARATOR//sx;
                my $row = $timepoint_data->rows_where( 'Abbrev4', $place );
                $destinations{ $row->[$column] } = $order{$place};
            }

            my $destination = join( q{ / },
                sort { $destinations{$b} <=> $destinations{$a} }
                  keys %destinations );

            return (
                  $dir eq 'CW' ? 'Clockwise to '
                : $dir eq 'CC' ? 'Counterclockwise to '
                : 'To '
            ) . $destination;

        } ## tidy end: sub destination_of

        my %description_of;

        sub build_placelist_descriptions {

            my $signup = shift;

            foreach my $routedir ( keys %pats_of ) {
                my @theselists;
                foreach my $placelist ( keys %{ $pats_of{$routedir} } ) {
                    push @theselists, $placelist;
                }
                my %relevant_places = relevant_places(@theselists);

                while ( my ( $placelist, $relevant ) = each %relevant_places ) {

                    my @descriptions;
                    foreach my $place ( sk($relevant) ) {
                        my $row
                          = $timepoint_data->rows_where( 'Abbrev4', $place );
                        $row = $timepoint_data->hashrow($row);
                        push @descriptions, $row->{TPName};
                    }

                    $description_of{$routedir}{$placelist}
                      = join( ' -> ', @descriptions );

                }

            } ## tidy end: foreach my $routedir ( keys...)

            return %description_of;

        } ## tidy end: sub build_placelist_descriptions

        sub description_of {
            my ( $routedir, $placelist ) = @_;
            return $description_of{$routedir}{$placelist};
        }

    }

    sub hasi2flagpat_HELP {
        say 'No help written for hasi2flagpat';

        return;

    }

    1;
