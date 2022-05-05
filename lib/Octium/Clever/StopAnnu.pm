package Octium::Clever::StopAnnu 0.019;

use Actium;
use Array::2D;
use Text::CSV;
use DDP;

my ( $xheatabfolder, %is_in_serv, %stops_of_pat_fullid,
    $stopinfo_of_511_r, %stopinfo_of_hastus, %audio_row_of, $cwfolder, );
# the ones that are _r scalars rather than hash variables is because there is a
# bug in refaliasing around changes in inner scopes not being seen by outer
# ones.

# my %is_virtual;

my $csv     = Text::CSV->new( { binary => 1 } );
my $csv_out = Text::CSV->new( { binary => 1, eol => "\r\n" } );

use constant {
    S_ROUTE       => 0,
    S_VARIANT     => 1,
    S_PATTERN     => 2,
    S_DIRECTION   => 3,
    S_STOPID      => 4,
    S_TEXT        => 9,
    S_AUDIO_START => 10,
};

# This createes the stop sign text and stop audio announcements.  It uses the
# Stops_Neue and annu tables from the database, the trip_pattern, trip, and
# trip_stops files from the Enterprise Database export, and the
# MA_Stop_Sign_Text_Audio file exported from CleverWorks, and outputs a new
# Stop_Sign_Text_Audio file that can be imported into CleverWorks

func xhea2annu (:$signupfolder, :$actiumdb) {

    $xheatabfolder = $signupfolder->subfolder('xhea/tab');
    $cwfolder      = $signupfolder->ensure_subfolder('cleverworks');

    $stopinfo_of_511_r = $actiumdb->all_in_columns_key(
        'Stops_Neue',
        qw/h_stp_identifier         c_description_fullabbr
          c_annu_on_compare
          c_annu_on                 c_annu_at
          c_annu_comment            c_annu_street_num
          /
    );

    for my $h_stp_511_id ( keys %$stopinfo_of_511_r ) {
        my $h_stp_identifier
          = $stopinfo_of_511_r->{$h_stp_511_id}{h_stp_identifier};
        $stopinfo_of_hastus{$h_stp_identifier}
          = $stopinfo_of_511_r->{$h_stp_511_id};
    }

    _get_in_service_patterns();
    _get_trips();
    _get_stop_sequences();

    \my %audio_of = $actiumdb->all_in_column_key( 'annu', 'annu_audios' );

    # _output_pat_files($signupfolder);

    _generate_audio( $signupfolder, \%audio_of );
    _make_import_file();

}

{
    my %pat_fullid_of_trip;

    func _get_in_service_patterns {
        my $patternfile = $xheatabfolder->file('trip_pattern.txt');

        my $patterns_aoa = Array::2D->new_from_file( $patternfile, 'tsv' );
        \my @headers = shift @$patterns_aoa;

        foreach my $row_r (@$patterns_aoa) {
            my %row;
            @row{@headers} = @$row_r;
            next unless $row{tpat_in_serv};
            my $pat_fullid
              = $row{tpat_route} . '-'
              . $row{tpat_id} . '-'
              . $row{tpat_direction};
            $is_in_serv{$pat_fullid} = 1;

        }

        return;
    }

    func _get_trips {
        my $tripfile = $xheatabfolder->file('trip.txt');

        my $trips_aoa = Array::2D->new_from_file( $tripfile, 'tsv' );
        \my @headers = shift @$trips_aoa;

        my %seen_pat_fullid;

        foreach my $row_r (@$trips_aoa) {
            my %row;
            @row{@headers} = @$row_r;
            my $pat_fullid = $row{tpat_route} . '-';
            $pat_fullid .= $row{trp_pattern} . '-';
            $pat_fullid .= $row{tpat_direction};

            next unless $is_in_serv{$pat_fullid};
            next if $seen_pat_fullid{$pat_fullid};

            my $tripnum = $row{trp_int_number};
            $seen_pat_fullid{$pat_fullid} = $tripnum;
            $pat_fullid_of_trip{$tripnum} = $pat_fullid;
        }

        return;

    }

    func _get_stop_sequences {
        my $tripstopfile = $xheatabfolder->file('trip_stop.txt');

        my $fh = $tripstopfile->openr_text;

        my $headerline = readline $fh;
        chomp $headerline;
        my @headers = split( /\t/, $headerline );
        while ( my $row = readline $fh ) {
            chomp $row;
            my %row;
            @row{@headers} = split( /\t/, $row );
            my $number     = $row{trp_int_number};
            my $pat_fullid = $pat_fullid_of_trip{$number};
            next unless $pat_fullid;

            my $h_stp_identifier = $row{tstp_stop_id};
            my $position         = $row{tstp_position} - 1;
            # changing from 1 based to 0 based
            $stops_of_pat_fullid{$pat_fullid}[$position] = $h_stp_identifier;
            #$is_virtual{$h_stp_identifier} = 1 if $h_stp_identifier =~ /^D/;

        }

        return;

    }

}

func _generate_audio ($signupfolder, \%audio_of) {

    my $cry = env->cry('Writing audio file');

    my $intermedfile = $cwfolder->file('audio_intermed.txt');
    my $intermedfh   = $intermedfile->openw_text;

    say $intermedfh join( "\t",
        qw/route pattern direction h_stp_identifier h_stp_511_id description sign audios/
    );

    my %all_audios;

    foreach my $pat_fullid ( sort keys %stops_of_pat_fullid ) {
        $cry->over($pat_fullid);

        my @allstops = $stops_of_pat_fullid{$pat_fullid}->@*;

        my $prev_on_compare = '';
        for my $stop_seq ( 0 .. $#allstops ) {
            my $h_stp_identifier = $allstops[$stop_seq];

            my $on = $stopinfo_of_hastus{$h_stp_identifier}{c_annu_on} // '';
            my $on_compare
              = $stopinfo_of_hastus{$h_stp_identifier}{c_annu_on_compare} // '';
            my $at = $stopinfo_of_hastus{$h_stp_identifier}{c_annu_at} // '';
            my $comment
              = $stopinfo_of_hastus{$h_stp_identifier}{c_annu_comment} // '';
            my $stnum
              = $stopinfo_of_hastus{$h_stp_identifier}{c_annu_street_num} // '';
            my $desc
              = $stopinfo_of_hastus{$h_stp_identifier}{c_description_fullabbr}
              // '';
            my $h_stp_511_id
              = $stopinfo_of_hastus{$h_stp_identifier}{h_stp_511_id} // '';

            my $sign;
            my @audios;

            if ( $at and ( $stnum or $prev_on_compare ne $on_compare ) ) {
                # there probably won't be any actual examples of street numbers
                # and a valid "at", but just in case...
                $sign            = "$on & $at";
                $prev_on_compare = $on_compare;
                @audios          = ( $audio_of{$on} // 'UNDEF',
                    '+', $audio_of{$at} // 'UNDEF' );
            }
            elsif ($at) {
                $sign   = $at;
                @audios = $audio_of{$at} // 'UNDEF';
            }
            else {
                $sign            = $on;
                $prev_on_compare = $on;
                @audios          = $audio_of{$on} // 'UNDEF';
            }

            if ($stnum) {
                unshift @audios, $audio_of{$stnum} // 'UNDEF';
                $sign = "$stnum $sign";
            }

            if ($comment) {
                push @audios, $audio_of{$comment} // 'UNDEF';
                $sign = "$sign ($comment)";
            }

            @audios = map { split(/,/) } @audios;
            #@audios = map { defined ? split(/,/) : '' } @audios;
            # handle embedded , in the database entries

            push @audios, 'END_OF_LINE' if ( $stop_seq == $#allstops );
            $#audios = 9;    # exactly ten audio fields in CleverWorks
            @audios  = map { $_ // '' } @audios;

            my $audio = join( ',', @audios );

            $all_audios{$_} = 1 foreach @audios;

            my ( $route, $pat, $direction ) = split( /-/, $pat_fullid );
            say $intermedfh join( "\t",
                $route, $pat, $direction, $h_stp_identifier, $h_stp_511_id,
                $desc, $sign, $audio );

            my $fullpat_and_stop = "$pat_fullid-$h_stp_identifier";

            $audio_row_of{$fullpat_and_stop} = [ $sign, @audios ];

        }

    }

    $cry->over('');
    $cry->done;

    my $allaudios_cry = env->cry('Writing all-audios file');
    my $allaudiosfile
      = $signupfolder->ensure_subfolder('cleverworks')->file('allaudios.txt');

    my @all_audios = sort keys %all_audios;

    $allaudiosfile->spew_text( ( join( "\n", @all_audios ) ) . "\n" );

    $allaudios_cry->done;

}

func _make_import_file {

    my @stopaudiofiles = sort ( $cwfolder->glob('MA_Stop_Sign_Text_Audio*') );
    my $stopaudiofile  = $stopaudiofiles[-1];    # last file should be newest

    my $import_file = $cwfolder->file('signaudio_import.csv');
    my $importfh    = $import_file->openw_text;

    my $read_stopaudioscry
      = env->cry("Reading CleverWorks export and writing CleverWorks import");
    $read_stopaudioscry->wail( "Reading " . $stopaudiofile->basename );
    $read_stopaudioscry->wail( "Writing " . $import_file->basename );

    my $stopaudio_fh = $stopaudiofile->openr_text;

    # headers
    for ( 1 .. 3 ) {
        print $importfh scalar( readline $stopaudio_fh );
    }

    while ( my $row_r = $csv->getline($stopaudio_fh) ) {
        my ( $route, $pattern, $direction, $stopid )
          = @{$row_r}[ S_ROUTE, S_PATTERN, S_DIRECTION, S_STOPID ];

        $direction = ucfirst( lc($direction) );

        s/^0+// for ( $route, $pattern );

        my $fullpat_and_stop
          = join( "-", $route, $pattern, $direction, $stopid );
        next unless $audio_row_of{$fullpat_and_stop};

        my ( $sign, @audios ) = $audio_row_of{$fullpat_and_stop}->@*;

        $row_r->[S_TEXT] = $sign;
        $#$row_r = S_TEXT;
        push @$row_r, @audios;
        $csv_out->say( $importfh, $row_r );

    }
    close $stopaudio_fh;
    close $importfh;

    $read_stopaudioscry->done;

}

# func _output_pat_files ($signupfolder) {
#
#     my $xsl_folder = $signupfolder->ensure_subfolder('xsl/pat');
#     my $xsl_nv     = $signupfolder->ensure_subfolder('xsl/pat-nv');
#
#     my $cry = env->cry('Writing pat files');
#
#     foreach my $pat ( sort keys %stops_of_pat_fullid ) {
#
#         my @allstops      = $stops_of_pat_fullid{$pat}->@*;
#         my @nonvirt_stops = grep { not $is_virtual{$_} } @allstops;
#
#         $cry->over($pat);
#
#         {
#             my $all_file = $xsl_folder->file("$pat.txt");
#             my $all_fh   = $all_file->openw_text;
#             _output_stops( $all_fh, @allstops );
#             close $all_fh;
#         }
#
#         {
#             my $nv_file = $xsl_nv->file("$pat.txt");
#             my $nv_fh   = $nv_file->openw_text;
#             _output_stops( $nv_fh, @nonvirt_stops );
#             close $nv_fh;
#         }
#
#     }
#
# }
#
# func _output_stops ($fh, @stops) {
#     foreach my $stop (@stops) {
#         say $fh $stopinfo_of_511_r->{$stop}->{h_stp_511_id},
#           "\t", $stopinfo_of_511_r->{$stop}->{c_description_fullabbr};
#     }
# }

# get which patterns are in service from trip_pattern.txt
# get which trips are associated with which patten from trip.txt
# get sequence of stops for a sample trip from trip_stops.txt

# end result should be route, pattern ID, sequence of stops

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

