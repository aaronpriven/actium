package Octium::Import::Xhea::ToAnnu 0.019;

use Actium;
use Array::2D;
use DDP;

my ($xheatabfolder,     %is_in_serv,   %pat_of_trip,
    %trip_of_pat,       %stops_of_pat, %is_virtual,
    $stopinfo_of_511_r, $audio_of_r,   %stopinfo_of_hastus,
    %all_audios,
);
# the ones that are _r scalars rather than hash variables is because there is a
# bug in refaliasing around changes in inner scopes not being seen by outer
# ones.

func xhea2annu (:$signupfolder, :$actiumdb) {

    $xheatabfolder = $signupfolder->subfolder('xhea/tab');

    $stopinfo_of_511_r = $actiumdb->all_in_columns_key(
        'Stops_Neue',
        qw/h_stp_identifier          c_description_fullabbr
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

    $audio_of_r = $actiumdb->all_in_column_key( 'annu', 'annu_audios' );

    # _output_pat_files($signupfolder);

    _output_audio($signupfolder);

}

func _output_audio ($signupfolder) {

    my $cry  = env->cry('Writing audio file');
    my $file = $signupfolder->ensure_subfolder('cleverworks')
      ->file('audio_intermed.txt');
    my $fh = $file->openw_text;

    say $fh join( "\t",
        qw/route pattern h_stp_identifier h_stp_511_id description sign audios/
    );

    foreach my $rp ( sort keys %stops_of_pat ) {
        $cry->over($rp);

        my @allstops = $stops_of_pat{$rp}->@*;

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

            if ( $at and ($stnum or $prev_on_compare ne $on_compare) ) {
	    # there probably won't be any actual examples of street numbers
	    # and a valid "at", but just in case...
                $sign            = "$on & $at";
                $prev_on_compare = $on_compare;
                @audios          = (
                    $audio_of_r->{$on} // 'UNDEF',
                    '+', $audio_of_r->{$at} // 'UNDEF'
                );
            }
            elsif ($at) {
                $sign   = $at;
                @audios = $audio_of_r->{$at} // 'UNDEF';
            }
            else {
                $sign            = $on;
                $prev_on_compare = $on;
                @audios          = $audio_of_r->{$on} // 'UNDEF';
            }

            if ($stnum) {
                unshift @audios, $audio_of_r->{$stnum} // 'UNDEF';
                $sign = "$stnum $sign";
            }

            if ($comment) {
                push @audios, $audio_of_r->{$comment} // 'UNDEF';
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

            my ( $route, $pat ) = split( /-/, $rp );
            say $fh join( "\t",
                $route, $pat, $h_stp_identifier, $h_stp_511_id, $desc, $sign,
                $audio );

            my $rps = "$pat-$h_stp_identifier";

        }

    }

    $cry->over('');
    $cry->done;

    my $allaudios  = env->cry('Writing all-audios file');
    my $allaudiosfile = $signupfolder->ensure_subfolder('cleverworks')
      ->file('allaudios.txt');

    my @all_audios = sort keys %all_audios;

    $allaudiosfile->spew_text( (join("\n" , @all_audios )) . "\n" );

    $allaudios->done;

}

# func _output_pat_files ($signupfolder) {
#
#     my $xsl_folder = $signupfolder->ensure_subfolder('xsl/pat');
#     my $xsl_nv     = $signupfolder->ensure_subfolder('xsl/pat-nv');
#
#     my $cry = env->cry('Writing pat files');
#
#     foreach my $pat ( sort keys %stops_of_pat ) {
#
#         my @allstops      = $stops_of_pat{$pat}->@*;
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
        my $number = $row{trp_int_number};
        my $pat    = $pat_of_trip{$number};
        next unless $pat;

        my $h_stp_identifier = $row{tstp_stop_id};
        my $position         = $row{tstp_position} - 1;
        # changing from 1 based to 0 based
        $stops_of_pat{$pat}[$position] = $h_stp_identifier;
        $is_virtual{$h_stp_identifier} = 1 if $h_stp_identifier =~ /^D/;

    }

}

func _get_trips {
    my $tripfile = $xheatabfolder->file('trip.txt');

    my $patterns_aoa = Array::2D->new_from_file( $tripfile, 'tsv' );
    \my @headers = shift @$patterns_aoa;

    foreach my $row_r (@$patterns_aoa) {
        my %row;
        @row{@headers} = @$row_r;
        my $route_pattern = $row{tpat_route} . '-' . $row{trp_pattern};
        next unless $is_in_serv{$route_pattern};
        next if ( $trip_of_pat{$route_pattern} );
        my $tripnum = $row{trp_int_number};
        $trip_of_pat{$route_pattern} = $tripnum;
        $pat_of_trip{$tripnum}       = $route_pattern;
    }

}

func _get_in_service_patterns {
    my $patternfile = $xheatabfolder->file('trip_pattern.txt');

    my $patterns_aoa = Array::2D->new_from_file( $patternfile, 'tsv' );
    \my @headers = shift @$patterns_aoa;

    foreach my $row_r (@$patterns_aoa) {
        my %row;
        @row{@headers} = @$row_r;
        next unless $row{tpat_in_serv};
        my $route_pattern = $row{tpat_route} . '-' . $row{tpat_id};
        $is_in_serv{$route_pattern} = 1;

    }

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

