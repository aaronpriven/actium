package Octium::Clever::RouteAnnu 0.019;
# vimcolor: #002200

use Actium;
use Actium::Dir;
use Octium::Clever::RouteAttribute;
use Octium::Clever::RouteAudio;
#use Lingua::EN::Titlecase;
use Text::CSV;

# things to overwrite:
# - Audio - Audio1 through Audio10 (route  /destination audios)
# - Attr - TCHRouteVariantDescription, (on TCH)
#          DestinationSign, (just remove repeated line #)
#          BusTimePublicRouteDirection,  (direction destination)
#          BusTimePublicRouteDescription (pattern destination)

const my $ATTRIBUTE_IMPORT_FILE => 'route_attribute_import.csv';
const my $AUDIO_IMPORT_FILE     => 'route_audio_import.csv';
const my $MAX_AUDIOS            => 10;

func routeannu (:$signupfolder, :$actiumdb ) {

    my $cwfolder = $signupfolder->ensure_subfolder('cleverworks');

    my $maincry = env->cry('Producing route audio and attribute Clever files');
    my ( $attr, $audio ) = _read_clever_files($cwfolder);

    #\my %annu_of = $actiumdb->all_in_column_key( 'annu', 'annu_audios' );

    \my %dests_of = _read_dest_files($signupfolder);

    my ( $new_attr, $sign_of_rdp_r ) = _adjust_attr(
        attr     => $attr,
        dests    => \%dests_of,
        actiumdb => $actiumdb,
    );

    my $new_audio = _adjust_audio(
        audio       => $audio,
        sign_of_rdp => $sign_of_rdp_r,
        actiumdb    => $actiumdb,
    );

    $new_audio->store_csv( $cwfolder->file($AUDIO_IMPORT_FILE) );
    $new_attr->store_csv( $cwfolder->file($ATTRIBUTE_IMPORT_FILE) );

    $maincry->done;

}

{
    const my $a_rte    => 'RouteID';
    const my $a_pat    => 'Pattern';
    const my $a_var    => 'RouteVar';
    const my $a_dir    => 'Direction';
    const my $a_msg    => 'MessageType';
    const my @a_audios => map { 'Audio' . $_ } 1 .. $MAX_AUDIOS;
    const my $local_fare_msg =>
'Local Routes  Local Fare 2 50 Youth Seniors and Persons with Disabilities Fare 1 25';
    const my $transbay_fare_msg =>
'Transbay Routes Transbay Fare 6 00 Transbay Youth Seniors and Persons with Disabilities Fare is 3 00';

    my $csv = Text::CSV->new( { binary => 1 } );

    # RouteID, RouteVar, Pattern, Direction, RouteDescription, MessageType,
    # Language, Audio1, Audio2, Audio3, Audio4, Audio5, Audio6, Audio7, Audio8,
    # Audio9, Audio10

    func _adjust_audio (:$audio, :\%sign_of_rdp, :$actiumdb) {

        my $cry = env->cry("Adjusting audios");

        \my %lineinfo = $actiumdb->all_in_columns_key( 'Lines',
            qw/annu_sign_text NoLocalsOnTransbay annu_fare/ );

        my %fare_of;
        for my $line ( keys %lineinfo ) {
            my $annu_fare = $lineinfo{$line}{annu_fare};
            $annu_fare = 'Transbay' if $annu_fare eq 'Transbay2Zone';

            # not currently doing anything with 2zone, putting all fares
            # everywhere since line info the same everywhere

            $annu_fare = 'Both'
              if $annu_fare eq 'Transbay'
              and not $lineinfo{$line}{NoLocalsOnTransbay};
            $fare_of{$line} = $annu_fare;
        }

        \my %audio_of = $actiumdb->all_in_column_key( 'annu', 'annu_audios' );

        my $new_audio = $audio->filter(
            sub {

                my %row = shift->%*;
                my $msg = $row{$a_msg};
                return \%row if $msg eq 'Mid-Trip Dest';

                my ( $route, $dir, $pat ) = @row{ $a_rte, $a_dir, $a_pat };
                $dir = Actium::Dir->instance($dir)->dircode;
                my $rdp = join( ':', $route, $dir, $pat );
                my $old_audios = join( ',', grep {$_} @row{@a_audios} );
                # eliminate empty ones
                my ( $new_audios, $wailmsg );

                if ( $msg eq 'Destination' ) {
                    if ( not exists $sign_of_rdp{$rdp} ) {
                        #env->wail("No sign: $rdp");
                        # return;
                        return \%row;
                    }
                    my $sign = $sign_of_rdp{$rdp};
                    if ( not exists $audio_of{$sign} ) {
                        #env->wail("No audio: $rdp destination $sign");
                        #return;
                        return \%row;
                    }
                    $new_audios = $audio_of{$sign} || '*** NO AUDIO ***';

                    if ( exists $fare_of{$route} ) {
                        my $annu_fare = $fare_of{$route};
                        $new_audios .= ',' . $local_fare_msg
                          if $annu_fare eq 'Local' or $annu_fare eq 'Both';
                        $new_audios .= ',' . $transbay_fare_msg
                          if $annu_fare eq 'Transbay' or $annu_fare eq 'Both';
                    }

                    $wailmsg = "sign $sign";
                }
                elsif ( $msg eq 'Route' ) {
                    my $text = $lineinfo{$route}{annu_sign_text} || $route;

                    if ( not exists $audio_of{$text} ) {
                        #env->wail("No audio: $rdp route $text");

                        return \%row;

                    }

                    $new_audios = $audio_of{$text} || '*** NO AUDIO ***';
                    $wailmsg    = "route $route";
                }
                else {
                    die "Unrecognized $msg in Clever audio file";
                }

                #return if $old_audios eq $new_audios;
                #my @new_audios = split( /,/, $new_audios );

                # CSV
                my $csv_status = $csv->parse($new_audios);
                croak "Invalid CSV in audio: $new_audios" unless $csv_status;
                my @new_audios = $csv->fields;

                if ( @new_audios > $MAX_AUDIOS ) {
                    env->crier->wail("Too many audios for $wailmsg");
                    env->crier->wail($new_audios);
                }

                $#new_audios = 9;
                $_ //= '' foreach @new_audios;
                @row{@a_audios} = @new_audios;

                return \%row;

            }
        );

        $cry->done;

        return $new_audio;

    }

}

{
    const my $a_rte    => 'RouteName';
    const my $a_pat    => 'PatternID';
    const my $a_var    => 'RouteVariant';
    const my $a_dir    => 'Direction';
    const my $a_tch    => 'TCHRouteVariantDescription';
    const my $a_sign   => 'DestinationSign';
    const my $a_ddest  => 'BusTimePublicRouteDirection';
    const my $a_pdest  => 'BusTimePublicRouteDescription';
    const my $a_inserv => 'InService';

    # RouteName, RouteVariant, PatternID, Direction, RouteVariantDescription,
    # TCHRouteVariantDescription, InService, Verified, DestinationSignCode,
    # CodeBook, DestinationSign, BusTimePublicRouteDirection,
    # BusTimePublicRouteDescription, TAFareBoxRouteLogonID, FareBoxFareSetID,
    # FareBoxDirectionID, TspType, TspThreshold, TspMinPassengerCount,
    # IsHeadwayManaged, CountdownThresholdTimer, IncludeInScheduleReporting,
    # ExportToGTFS

    func _adjust_attr ( :$attr!, :$actiumdb! , :\%dests! ) {
        #        state $tc = Lingua::EN::Titlecase->new();
        my %sign_of_rdp;

        my $cry = env->cry("Adjusting attributes");

        my $new_attr = $attr->filter(
            sub {

                my %row = shift->%*;
                return \%row unless $row{$a_inserv};

                my ( $rte, $dir, $pat ) = @row{ $a_rte, $a_dir, $a_pat };
                return \%row unless $dir;

                $dir = Actium::Dir->instance($dir)->dircode;
                my $rdp = join( ':', $rte, $dir, $pat );

                my $changed;

                # DestinationSign - Remove duplicate route entries
                # TCHRouteVariantDescription - set to same as destination sign

                if ( $row{$a_sign} ) {

                    my @signwords = split( ' ', $row{$a_sign} );
                    my $line      = shift @signwords;
                    for ( reverse 0 .. $#signwords ) {
                        splice( @signwords, $_, 1 ) if $signwords[$_] eq $line;
                    }
                    my $newsign = join( ' ', $line, @signwords );
                    if ( $newsign ne $row{$a_sign} ) {
                        $row{$a_sign} = $newsign;
                        $changed = 1;
                    }
                    if ( $newsign ne $row{$a_tch} ) {
                        $row{$a_tch} = $newsign;    #
                        $changed = 1;
                    }
                }

                $sign_of_rdp{$rdp} = $row{$a_sign} =~ s/\A$rte //r;

                # BusTimePublicRouteDirection - use direction destination
                # BusTimePublicRouteDescription - use pattern destination

                if ( exists $dests{$rdp} ) {
                    my $ddest = $dests{$rdp}{d};
                    my $pdest = $dests{$rdp}{p};

                    if ( $row{$a_ddest} ne $ddest ) {
                        $row{$a_ddest} = $ddest;
                        $changed = 1;
                    }
                    if ( $row{$a_pdest} ne $pdest ) {
                        $row{$a_pdest} = $pdest;
                        $changed = 1;
                    }
                }

                #return \%row if $changed;
                return \%row;

            }
        );

        $cry->done;

        return $new_attr, \%sign_of_rdp;

    }

}

func _read_clever_files ($cwfolder) {

    my $cry = env->cry('Reading Clever exported files');

    my $findcry = env->cry('Finding Clever files');

    my @audio_files = sort ( $cwfolder->glob('MA_Route_Audio*') );
    my $audio_file  = $audio_files[-1];    # last file should be newest
    $cry->wail( $audio_file->basename );

    my @attr_files = sort ( $cwfolder->glob('MA_Route_Attribute*') );
    my $attr_file  = $attr_files[-1];      # last file should be newest
    $cry->wail( $attr_file->basename );

    $findcry->ok;

    my $attr
      = Octium::Clever::RouteAttribute->load_csv( $attr_file, keep_all => 1 );

    my $audio = Octium::Clever::RouteAudio->load_csv( $audio_file,
        in_service_variants => [ $attr->keys ], );

    $cry->done;

    return $attr, $audio;

}

func _read_dest_files (Actium::Storage::Folder $signupfolder) {

    my $cry = env->cry("Loading pattern and direction destinations");

    my $basename = $signupfolder->basename;
    my $dirdest_fh
      = $signupfolder->file("direction-destinations-$basename.txt")->openr_text;
    my $patdest_fh
      = $signupfolder->file("pattern-destinations-$basename.txt")->openr_text;
    my ( %dirdest_of, %dests_of );

    while (<$dirdest_fh>) {
        chomp;
        my ( $route, $direction, $destination ) = split(/\t/);
        next if $route eq 'line';
        $direction = Actium::Dir->instance($direction);
        my $rd = "$route:$direction";
        $dirdest_of{$rd} = $destination;
    }
    close $dirdest_fh;

    readline($patdest_fh);    # throw away headers
    while (<$patdest_fh>) {
        chomp;
        my ( $route, $pattern, $direction, $patdest, $vdc_id, $place )
          = split(/\t/);

        $patdest =~ s/^To //;
        $direction = Actium::Dir->instance($direction);
        my $rd      = "$route:$direction";
        my $dirdest = $dirdest_of{$rd};
        my $rdp     = "$route:$direction:$pattern";
        cry->wail("dir overlong: $rd $dirdest")  if length($dirdest) > 50;
        cry->wail("pat overlong: $rdp $patdest") if length($patdest) > 50;
        $dests_of{$rdp} = { d => $dirdest, p => $patdest };
    }
    close $patdest_fh;

    $cry->done;

    return \%dests_of;

}

1;

__END__

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

