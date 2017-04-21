package Actium::Cmd::MakePoints 0.013;

use warnings;    ### DEP ###
use strict;      ### DEP ###

use 5.022;

use sort ('stable');    ### DEP ###

# add the current program directory to list of files to include

use Actium::Preamble;

use Actium::Union('ordered_union');

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

use File::Slurper('read_text');    ### DEP ###
use Text::Trim;                    ### DEP ###

use Actium::O::Points::Point;

const my $LISTFILE_BASE    => 'pl';
const my $ERRORFILE_BASE   => 'err';
const my $HEIGHTSFILE_BASE => 'ht';
#const my $SIGNIDS_IN_A_FILE => 250;

const my $FALLBACK_AGENCY      => 'ACTransit';
const my $FALLBACK_AGENCY_ABBR => 'AC';

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
    my ( $class, $env ) = @_;
    return (
        qw/actiumdb signup/,
        {   spec        => 'output_heights',
            description => 'Will output a file with the heights of each column',
            fallback    => 0,
        },
        {   spec => 'update',
            description =>
              'Will only process signs that have the status "Needs Update."',
            fallback => 0
        },
        {   spec => 'type=s',
            description =>
              'Will only process signs that have a given signtype.'
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

        {   spec        => 'cluster=s',
            description => 'Sign cluster used for this run. '
              . 'If specified, only signs in this cluster will be '
              . 'produced. Use _ for no cluster',
            fallback => $EMPTY,
        },

        {   spec        => 'agency=s',
            description => 'Agency ID used for this run. '
              . 'Only signs of this agency will be produced',
            display_default => 1,
            fallback        => $FALLBACK_AGENCY,
        },
    );
} ## tidy end: sub OPTIONS

sub START {

    my ( $class, $env ) = @_;

    our (
        $actiumdb,  %places,    %signs,   %stops, %lines,
        %signtypes, @templates, %smoking, @ssj
    );
    # this use of global variables should be refactored...

    $actiumdb = $env->actiumdb;
    my @argv = $env->argv;

    my $signup = $env->signup;
    chdir $signup->path();

    # retrieve data

    my $makepoints_cry = cry 'Making InDesign point schedule files';

    my $load_cry = cry 'Loading data from Actium database';

    %smoking = %{ $actiumdb->all_in_column_key(qw(Cities SmokingText)) };

    my ( $run_agency, $run_agency_abbr, $run_agency_row )
      = $actiumdb->agency_or_abbr_row( $env->option('agency') );

    unless ($run_agency) {
        $load_cry->d_error;
        die "Agency " . $env->option('agency') . " not found.\n";
    }

    my $effdate = $actiumdb->effective_date(agency => $run_agency);

    $actiumdb->load_tables(
        requests => {
            Places_Neue => {
                hash        => \%places,
                index_field => 'h_plc_identifier'
            },
            SignTypes => {
                hash        => \%signtypes,
                index_field => 'SignType'
            },
            Signs => {
                hash        => \%signs,
                index_field => 'SignID',
                fields      => [
                    qw[
                      SignID Active stp_511_id Status SignType Cluster Sidenote
                      Agency ShelterNum NonStopLocation NonStopCity
                      Delivery City TIDFile
                      ]
                ],
            },
            Signs_Stops_Join => { array => \@ssj },
            SignTemplates    => { array => \@templates },
            Lines            => {
                hash        => \%lines,
                index_field => 'Line'
            },
            Stops_Neue => {
                hash        => \%stops,
                index_field => 'h_stp_511_id',
                fields      => [qw[h_stp_511_id c_description_full ]],
            },
        }
    );

    our %templates_of;

    foreach \my %template (@templates) {
        my $signtype = $template{SignType};
        my $subtype  = $template{MasterPage};
        my $agency   = $template{Agency};

        next if $agency and $agency ne $run_agency;

        my @regions;
        my $tempregions = u::trim( $template{Regions} );
        $tempregions =~ s/\s+/ /;
        $tempregions =~ s/[^0-9: ]//g;

        foreach my $region ( split( ' ', $tempregions ) ) {
            my ( $columns, $height ) = split( /:/, $region );
            push @regions, { columns => $columns, height => $height };
        }

        @regions = map { $_->[0] }
          reverse sort { $a->[1] <=> $b->[1] }
          map { [ $_, $_->{height} ] } @regions;

        $templates_of{$signtype}{$subtype} = \@regions;

    } ## tidy end: foreach \my %template (@templates)

    my $ssj_cry = cry('Processing multistop entries');

    my (%stops_of_sign);
    foreach my $ssj (@ssj) {
        my $ssj_stop = $ssj->{h_stp_511_id};
        my $ssj_sign = $ssj->{SignID};

        my $ssj_omit_lines = $ssj->{OmitLines};
        my @ssj_omitted;
        if ($ssj_omit_lines) {
            @ssj_omitted = split( ' ', $ssj->{OmitLines} );
        }
        $stops_of_sign{$ssj_sign}{$ssj_stop} = \@ssj_omitted;
    }

    $ssj_cry->done;

    $load_cry->done;

    my $cluster_opt = $env->option('cluster');

    my $signtype_opt = $env->option('type');
    my @matching_signtypes;

    if ($signtype_opt) {
        @matching_signtypes = grep {m/\A$signtype_opt\z/} keys %signtypes;

        # Note that the regular expression feature, while not allowing more
        # access than is given at the command line anyway, could be problematic
        # if this used on a server.

        if ( not @matching_signtypes ) {
            $makepoints_cry->text(
                "No signtype matches $signtype_opt specified on command line.");
            $makepoints_cry->d_error;
            exit 1;
        }
    }
    else {
        @matching_signtypes = keys %signtypes;
    }
    my %signtype_matches = map { $_, 1 } @matching_signtypes;

    my $cry = cry("Now processing point schedules for sign number:");

    my $displaycolumns = 0;
    my @signstodo;

    if (@argv) {
        @signstodo = @argv;
    }
    else {
        @signstodo = keys %signs;
    }

    my ( %skipped_stops, %points_of_signtype, %errors, %heights );

  SIGN:
    foreach my $signid ( sort { $a <=> $b } @signstodo ) {

        my $stopid   = $signs{$signid}{stp_511_id};
        my $delivery = $signs{$signid}{Delivery} // $EMPTY;
        my $city     = $signs{$signid}{City} // $EMPTY;
        my $signtype = $signs{$signid}{SignType} // $EMPTY;
        my $status   = $signs{$signid}{Status};
        my $cluster  = $signs{$signid}{Cluster} // $EMPTY;

        next SIGN if $cluster_opt eq '_' and $cluster eq $EMPTY;
        next SIGN if $cluster_opt and $cluster_opt ne $cluster;

        next SIGN
          if not exists $signtype_matches{$signtype};

        next SIGN
          if $env->option('update')
          and not( u::feq( $status, 'Needs update' ) );

        my ( $nonstoplocation, $nonstopcity );
        if ( not($stopid) ) {
            $nonstopcity = $signs{$signid}{NonStopCity};
            $nonstoplocation
              = $signs{$signid}{NonStopLocation} . ', ' . $nonstopcity;
        }
        
        my $smoking;
        #if ($signtype =~ /^TID/) {
        #    $smoking = $signs{$signid}{TIDFile};
        #}    
        # before this is useful we need to give every smoking box
        # a scripting label, on every template. Sigh.

        $smoking //= $smoking{$city} // $IDT->emdash;

        my $omitted_of_stop_r;
        if ( exists $stops_of_sign{$signid} ) {

            $omitted_of_stop_r = $stops_of_sign{$signid};

            if ( not $stopid ) {
                my @allstopids = sort keys %{$omitted_of_stop_r};
                $stopid = $allstopids[0];
            }

        }
        elsif ($stopid) {
            $omitted_of_stop_r = { $stopid => [] };
        }

        my $sign_is_active = lc( $signs{$signid}{Active} );

        next SIGN
          unless $stopid
          and $sign_is_active eq 'yes'
          and $signs{$signid}{Status} !~ /no service/i;

        my $agency      = $signs{$signid}{Agency};
        my $agency_abbr = $actiumdb->agency_row_r($agency)->{agency_abbr};

        next SIGN unless $agency eq $run_agency;

        #####################
        # Following steps

        foreach my $stoptotest ( keys %{$omitted_of_stop_r} ) {

            # skip stop if file not found
            my $firstdigits = substr( $stoptotest, 0, 3 );
            my $kpointfile = "kpoints/${firstdigits}xx/$stoptotest.txt";

            unless ( -e $kpointfile ) {
                my $add = $EMPTY;
                $add = " ($agency)"
                  if $agency ne $FALLBACK_AGENCY;
                push @{ $errors{$signid} }, "Stop $stoptotest not found$add";
                $skipped_stops{$signid} = $stoptotest;
                next SIGN;
            }

        }

        $cry->over("$signid ");

        # 1) Read kpoints from file

        my $point = Actium::O::Points::Point->new_from_kpoints(
            $stopid, $signid,    $effdate,
            $agency,  $omitted_of_stop_r, $nonstoplocation,
            $smoking, $delivery,          $signup
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

        my $subtype = $point->sort_columns_and_determine_heights(
            $signs{$signid}{SignType} );

        if ( $subtype and $subtype ne '!' ) {
            #my ( $signtype, $subtype ) = split( /=/, $subtype );
            push @{ $points_of_signtype{$signtype} }, [ $signid, $subtype ];

        }
        else {
            push @{ $errors{$signid} },
              "No sign template found in $signtype for $run_agency";
        }

        # 6) Format with text and indesign tags. Includes
        #    expanding places into full place descriptions
        #    and dividing columns into ones that are
        #    the proper length (length comes from SignType),
        #    and adding footnote markers

        $point->format_columns( $signs{$signid}{SignType} );

        # 7) Format and expand the footnotes (the actual
        #    footnotes, not the footnote markers)

        $point->format_side;

        # 8) Add stop description

        $point->format_bottom;

        # 9) add blank columns in front (if needed) and
        #    output to points

        $point->output;

        my @errors = $point->errors;

        push @{ $errors{$signid} }, @errors if @errors;

        $heights{$signid} = $point->heights if defined $point->heights;

    }    ## <perltidy> end foreach my $signid ( sort {...})

    $cry->done;

    my $run_name = _get_run_name( $env, $run_agency_abbr );

    my $listfile = $LISTFILE_BASE . $run_name . '.txt';

    my $list_cry = cry "Writing list to $listfile";

    my $pointlist_folder = $signup->subfolder('pointlist');

    my $list_fh = $pointlist_folder->open_write($listfile);

    foreach my $signtype ( sort keys %points_of_signtype ) {

        my @points = @{ $points_of_signtype{$signtype} };
        @points = sort { $a->[0] <=> $b->[0] } @points;
        # sort numerically by signid

        my $signids_in_a_file = $signtypes{$signtype}{StopIDsInAFile};
        if ( $cluster_opt and $cluster_opt ne '_' ) {
            $signids_in_a_file = 9999;
        }

        my $end_signid = $signids_in_a_file;

        my $addition = "1-" . $signids_in_a_file;
        my $file_line_has_been_output;

        foreach my $point (@points) {

            my $signid         = $point->[0];
            my $subtype_letter = $point->[1];

            while ( $signid > $end_signid ) {
                $file_line_has_been_output = 0;
                $addition                  = ( $end_signid + 1 ) . "-"
                  . ( $end_signid + $signids_in_a_file );
                $end_signid += $signids_in_a_file;
            }
            # separating the addition and the print allows there to be large
            # gaps in the number of sign IDs

            if ( not $file_line_has_been_output ) {
                say $list_fh "FILE\t$signtype\t$addition";
                $file_line_has_been_output = 1;
            }

            say $list_fh "$signid\t$subtype_letter";
        } ## tidy end: foreach my $point (@points)
    } ## tidy end: foreach my $signtype ( sort...)

    close $list_fh;

    $list_cry->done;

    ### ERROR DISPLAY

    if ( scalar keys %errors ) {

        my $error_count = scalar keys %errors;

        my $error_file = $ERRORFILE_BASE . $run_name . '.txt';
        my $error_cry  = cry "Writing $error_count errors to $error_file";
        #$error_cry->text(join(" " , keys %errors) );
        my $error_fh = $pointlist_folder->open_write($error_file);

        foreach my $signid ( sort { $a <=> $b } keys %errors ) {
            foreach my $error ( @{ $errors{$signid} } ) {
                say $error_fh "$signid\t$error";
            }
        }

        $error_fh->close;
        $cry->done;

    }
    else {
        my $error_cry = cry 'No errors to log';
        $error_cry->d_ok;
    }

    ### HEIGHTS DISPLAY

    if ( $env->option('output_heights') ) {
        my $heights_file = $HEIGHTSFILE_BASE . $run_name . '.txt';
        my $heights_cry  = cry "Writing heights to $heights_file";
        my $heights_fh   = $pointlist_folder->open_write($heights_file);
        foreach my $signid ( sort { $a <=> $b } keys %heights ) {
            say $heights_fh "$signid\t" . $heights{$signid};
        }
        $heights_fh->close;
        $cry->done;
    }

    $makepoints_cry->done;

} ## tidy end: sub START

sub _get_run_name {

    my $env             = shift;
    my $run_agency_abbr = shift;
    my $nameopt         = $env->option('name');

    if ( defined $nameopt and $nameopt ne $EMPTY ) {
        return '.' . $nameopt;
    }
    if ( $nameopt eq '_' ) {
        return $EMPTY;
    }

    my @args        = $env->argv;
    my $signtype    = $env->option('type');
    my $cluster_opt = $env->option('cluster');

    my @run_pieces;
    push @run_pieces, $run_agency_abbr
      unless $run_agency_abbr eq $FALLBACK_AGENCY_ABBR;
    push @run_pieces, join( ',', @args ) if @args;
    push @run_pieces, $signtype       if $signtype;
    push @run_pieces, "C$cluster_opt" if $cluster_opt;
    push @run_pieces, 'U'             if $env->option('update');

    if (@run_pieces) {
        return '.' . join( '_', @run_pieces );
    }
    else {
        return $EMPTY;
    }

} ## tidy end: sub _get_run_name

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
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
