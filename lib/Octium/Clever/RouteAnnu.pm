package Octium::Clever::RouteAnnu 0.019;

use Actium;
use Array::2D;
use Text::CSV;
use DDP;

# things to overwrite:
# - Audio - Audio1 through Audio10 (route  /destination audios)
# - Attr - TCHRouteVariantDescription, (on TCH)
#          DestinationSign, (just remove repeated line #)
#          BusTimePublicRouteDirection,  (direction destination)
#          BusTimePublicRouteDescription (pattern destination)

my $csv     = Text::CSV->new( { binary => 1 } );
my $csv_out = Text::CSV->new( { binary => 1, eol => "\r\n" } );

const my $ATTRIBUTE_IMPORT_FILE => 'route_attribute_import.csv';
const my $AUDIO_IMPORT_FILE     => 'route_aaudio_import.csv';

func routeannu (:$signupfolder, :$actiumdb, :$getaudios) {

    my $xheatabfolder = $signupfolder->subfolder('xhea/tab');
    my $cwfolder      = $signupfolder->ensure_subfolder('cleverworks');

    my $maincry = env->cry(
        $getaudios
        ? 'Assembling route audio from Clever file'
        : 'Producing route audio Clever files'
    );

    _read_clever_files(
        cwfolder  => $cwfolder,
        audio_of  => \my %audio_of,
        getaudios => $getaudios,
        attr_rows => \my %attr_rows,
    );

    if ($getaudios) {
        _write_route_audios( cwfolder => $cwfolder, audio_of => \%audio_of );
        $maincry->done;
        exit 0;
    }

    \my %routeinfo = $actiumdb->all_in_columns_key( 'Lines',
        qw/annu_sign_text NoLocalsOnTransbay/ );
    \my %annu_of = $actiumdb->all_in_column_key( 'annu', 'annu_audios' );

    _write_clever_files( attr_rows => \%attr_rows, );

    $maincry->done;

}

func _write_clever_files (
    :%attr_rows! is ref_alias,
) {

    my$writecry=env->cry('Writing files for import into CleverWorks');

    foreach my $var_fullid  (sort keys %attr_rows) {
        


    }

}

func _read_clever_files (
    :$cwfolder, 
    :%audio_of! is ref_alias, 
    :$getaudios , 
    :%attr_rows is ref_alias ,
) {

    my ( $audio_fh, $attr_fh ) = _open_clever_files($cwfolder);

    my ( %attr_row, %audio_row, %route_audios, %dest_audios, %in_service );

    my $attr_headertexts = _clever_headers(
        fh             => $attr_fh,
        column_indexes => \my %attrcol,
        cry            => 'attr'
    );

    my $attr_cry = env->cry('Getting rows from attr file');
    while ( my $row_r = $csv->getline($attr_fh) ) {
        my ( $route, $variant, $in_service )
          = @{$row_r}[ @attrcol{qw/RouteName RouteVariant InService/} ];

        my $var_fullid = "$route-$variant";

        next unless $in_service or $getaudios;
        $in_service{$var_fullid} = 1;
        $attr_row{$var_fullid}   = [@$row_r];
        # copy needed because csv reuses reference
        # or does it? Am I thinking of something from DBI?
        # oh well, it doesn't take that long
    }
    close $attr_fh;
    $attr_cry->done;

    my $audio_headertexts = _clever_headers(
        fh             => $audio_fh,
        column_indexes => \my %audiocol,
        cry            => 'audio'
    );
    my $audio_cry = env->cry('Getting rows from audio file');
    while ( my $row_r = $csv->getline($audio_fh) ) {
        my ( $route, $variant, $messagetype, $sign )
          = @{$row_r}[ @audiocol{qw/RouteID RouteVar MessageType/} ];

        my @audiocols = @audiocol{ map { 'Audio' . $_ } ( 1 .. 10 ) };
        my @audios    = @{$row_r}[@audiocols];

        @audios = grep {$_} @audios;
        @audios = grep { !/(?:Local|Transbay) Fare/ } @audios;
        # no blank entries or fare entries

        my $var_fullid = "$route-$variant";
        next unless $in_service{$var_fullid};

        $audio_row{$var_fullid}{$messagetype} = [@$row_r];

        my $audios = join( ',', @audios );
        if ( $messagetype eq 'Route' ) {
            #$audio_cry->wail( "[[$audios]]   ", join( ",", @$row_r ) );
            $audio_of{$route}{$audios} = 1 if $audios and $route;
            $route_audios{$var_fullid} = \@audios;
        }
        elsif ( $messagetype eq 'Destination' ) {
            my $sign = $attr_row{$var_fullid}[ $attrcol{DestinationSign} ];
            $sign =~ s/$route //g;
            if ($sign) {
                $audio_of{$sign}{$audios} = 1 if $audios and $sign;
                $dest_audios{$var_fullid} = \@audios;
            }
        }

    }
    close $attr_fh;
    $audio_cry->done;

}

func _clever_headers (:$fh, :%column_indexes! is ref_alias, :$cry ) {

    my $header_cry   = env->cry("Getting headers from $cry file");
    my $header_texts = '';
    $header_texts .= ( scalar readline $fh ) . ( scalar readline $fh );
    # metadata and version lines
    my $header_fields = scalar readline $fh;
    $header_texts .= $header_fields;
    $csv->parse($header_fields);
    my @column_names = $csv->fields();

    s/\s*\*// foreach @column_names;    # remove asterisks in field names
    foreach my $i ( 0 .. $#column_names ) {
        $column_indexes{ $column_names[$i] } = $i;
    }

    $header_cry->done;

    return $header_texts;
}

func _open_clever_files ($cwfolder) {

    my $cry = env->cry('Opening files');

    my @audio_files = sort ( $cwfolder->glob('MA_Route_Audio*') );
    my $audio_file  = $audio_files[-1];    # last file should be newest
    $cry->wail( $audio_file->basename );
    my $audio_fh = $audio_file->openr_text;

    my @attr_files = sort ( $cwfolder->glob('MA_Route_Attribute*') );
    my $attr_file  = $attr_files[-1];      # last file should be newest
    $cry->wail( $attr_file->basename );
    my $attr_fh = $attr_file->openr_text;

    $cry->done;

    return $audio_fh, $attr_fh;

}

func _write_route_audios (:$cwfolder, :%audio_of, ) {

    my $fh = $cwfolder->file('route_audios.txt')->openw_text;

    my @texts = sort { length($a) <=> length($b) || $a cmp $b }
      keys %audio_of;

    my ( @one, @multi );

    foreach my $text (@texts) {
        my @audios = sort keys $audio_of{$text}->%*;
        my $audios = join( "|", @audios );
        my $line   = "$text\t$audios";
        if ( @audios == 1 ) {
            push @one, $line;
        }
        else {
            push @multi, $line;
        }
    }

    foreach my $line ( @one, @multi ) {
        say $fh join( "\t", $line );
    }

    close $fh;
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

