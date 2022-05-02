package Octium::Cmd::AnnuPopulate 0.019;

use Actium;
use Actium::Storage::Folder;
use Array::2D;
use DDP;

sub HELP {

    say <<'HELP' or die q{Can't open STDOUT for writing};
actium annupopulate  -- initial list of annu values
HELP

    return;

}

sub OPTIONS {
    return ( 'actiumdb', 'signup' );
}

use constant {
    SAF_IN_SERVICE => 0,
    SAF_SIGN_ON    => 1,
    SAF_SIGN_AT    => 2,
    SAF_AUDIO_ON   => 3,
    SAF_AUDIO_AT   => 4,

    TA_SIGN  => 0,
    TA_AUDIO => 1,
};

sub START {
    my $actiumdb           = env->actiumdb;
    my $signup_folder      = Actium::folder( env->signup->path );
    my $cleverworks_folder = $signup_folder->existing_subfolder('cleverworks');

    \my %sa_of = get_sa($cleverworks_folder);

    $actiumdb->load_tables(
        requests => {
            Stops_Neue => {
                hash        => \my %stops,
                index_field => 'h_stp_identifier',
                fields =>
                  [qw/h_stp_identifier c_street_num c_on c_at c_comment/],
            },
        }
    );

    my $bystop = Array::2D->new();
    push @$bystop, [
        qw/StopID On SignOn AudioOn At SignAt AudioAt
          Comment SignComment AudioComment SignStNum AudioStNum/
    ];
    my %texts_of;
    foreach my $stopid ( keys %stops ) {
        # skipping street numbers for now

        my ( $on, $at, $comment, $stnum )
          = $stops{$stopid}->@{qw/c_on c_at c_comment c_street_num/};

        my ( $sign_on, $sign_at, $audio_on, $audio_at )
          = $sa_of{$stopid}
          ->@[ SAF_SIGN_ON, SAF_SIGN_AT, SAF_AUDIO_ON, SAF_AUDIO_AT ];

        my ( $sign_stnum, $audio_stnum, $sign_comment, $audio_comment );

        if ($stnum) {
            if ( $audio_on and $audio_on =~ /^No_/ ) {
                ( $audio_stnum, $audio_on ) = split( /,/, $audio_on, 2 );
            }
            if ( $sign_on and $sign_on =~ /^[0-9]+\s/ ) {
                ( $sign_stnum, $sign_on ) = split( /\s/, $sign_on, 2 );
            }

        }

        if ($comment) {
            if ($sign_at) {
                ( $sign_at, $sign_comment ) = split( /\./, $sign_at, 2 );
            }
            elsif ($sign_on) {
                ( $sign_on, $sign_comment ) = split( /\./, $sign_on, 2 );
            }
            if ($audio_at) {
                ( $audio_at, $audio_comment ) = split( /\,/, $audio_at, 2 );
            }
            elsif ($audio_on) {
                ( $audio_on, $audio_comment ) = split( /\,/, $audio_on, 2 );
            }
        }

        $sign_on =~ s/Ave?\.?\z/Ave./ if $sign_on;
        $sign_at =~ s/Ave?\.?\z/Ave./ if $sign_at;

        $texts_of{$on}[TA_SIGN]{$sign_on}           = 1 if $on and $sign_on;
        $texts_of{$on}[TA_AUDIO]{$audio_on}         = 1 if $on and $audio_on;
        $texts_of{$at}[TA_SIGN]{$sign_at}           = 1 if $at and $sign_at;
        $texts_of{$at}[TA_AUDIO]{$audio_at}         = 1 if $at and $audio_at;
        $texts_of{$comment}[TA_SIGN]{$sign_comment} = 1
          if $comment and $sign_comment;
        $texts_of{$comment}[TA_AUDIO]{$audio_comment} = 1
          if $comment and $audio_comment;
        $texts_of{$stnum}[TA_SIGN]{$sign_stnum}   = 1 if $stnum and $sign_stnum;
        $texts_of{$stnum}[TA_AUDIO]{$audio_stnum} = 1
          if $stnum and $audio_stnum;

        push @$bystop,
          [ $stopid,       $on,            $sign_on,    $audio_on,
            $at,           $sign_at,       $audio_at,   $comment,
            $sign_comment, $audio_comment, $sign_stnum, $audio_stnum,
          ];

    }

    $bystop->xlsx( output_file => $cleverworks_folder . "/bystop.xlsx" );

    my %concat_texts_of;

    for my $text ( keys %texts_of ) {
        my @sign_keys;
        @sign_keys = keys $texts_of{$text}[TA_SIGN]->%*
          if $texts_of{$text}[TA_SIGN];
        $concat_texts_of{$text}[TA_SIGN] = join( "!", sort @sign_keys );
        my @audio_keys;
        @audio_keys = keys $texts_of{$text}[TA_AUDIO]->%*
          if $texts_of{$text}[TA_AUDIO];
        $concat_texts_of{$text}[TA_AUDIO] = join( "!", sort @audio_keys );

    }

    my $annu_file = $cleverworks_folder->file('annu.txt');
    my $annu_fh   = $annu_file->openw_text();

    say $annu_fh "annu_label\tannu_sign_text\tannu_audios";

    for my $text ( keys %concat_texts_of ) {

        my $newsigntext = $concat_texts_of{$text}[TA_SIGN];
        $newsigntext =~ s/(Bl|Blvd|Ct|St|Dr|Pl|Cir)\.?\z/$1./;
        $newsigntext =~ s/Wy\.?\z/Way/;
        $newsigntext =~ s/Rd\.?\z/Road/;
        $newsigntext =~ s/Ln\.?\z/Lane/;
        say $annu_fh
          join( "\t", $text, $newsigntext, $concat_texts_of{$text}[TA_AUDIO] );
    }

    $annu_fh->close;

    return;

}

func get_sa ($cleverworks_folder) {

    my $stop_audio_fields_file
      = $cleverworks_folder->file('stop_audio_fields.txt');

    my $sa_fields = Array::2D->new_from_file( $stop_audio_fields_file, 'tsv' );
    \my %sa_of = $sa_fields->hash_of_rows;
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

