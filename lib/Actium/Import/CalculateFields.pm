package Actium::Import::CalculateFields 0.012;

# Routines for calculating fields based on imported data.
# Does things like break up "description" into "on" and "at". Etc.
# This is probably a terrible name for this.

use Actium;
use Text::Trim;                                    ### DEP ###
use Lingua::EN::Titlecase::Simple('titlecase');    ### DEP ###

const my $CALC_PREFIX => 'i_';
const my $ORIG_PREFIX => 'h_';

my %HASTUS_CITY_OF = (
    "01" => "Alameda",
    "02" => "Albany",
    "03" => "Berkeley",
    "04" => "Castro Valley",
    "05" => "El Cerrito",
    "06" => "Emeryville",
    "07" => "Fremont",
    "08" => "Hayward",
    "09" => "Newark",
    "10" => "Oakland",
    "11" => "Piedmont",
    "12" => "Pinole",
    "13" => "Richmond",
    "14" => "San Francisco",
    "15" => "San Leandro",
    "16" => "San Pablo",
    "17" => "Union City",
    "18" => "Foster City",
    "19" => "San Mateo",
    "20" => "San Lorenzo",
    "21" => "Orinda",
    "22" => "Palo Alto",
    "23" => "Milpitas",
    "24" => "Menlo Park",
    "25" => "Redwood City",
    "26" => "East Palo Alto",
    "97" => "Santa Clara County",
    "98" => "Alameda County",
    "99" => "Contra Costa County",

);

foreach ( 1 .. 9 ) {
    $HASTUS_CITY_OF{$_} = $HASTUS_CITY_OF{"0$_"};
}    # add single-digit versions as well

sub hastus_places_import {

    my $cry = cry('Calculating fields derived from Hastus place data');

    my @place_headers = @{ +shift };
    my @place_records = @{ +shift };

    my @returned_headers = (
        ( map { $ORIG_PREFIX . $_ } @place_headers ),
        map { $CALC_PREFIX . $_ } (qw (city abbrev9 description ))
    );

    # adds the "h_" prefix to the original headers and the "i_" prefix
    # to the ones it creates

    my @returned_records;
    my $count     = 0;
    my $total     = scalar(@place_records);
    my $increment = $total / 15;

    foreach my $place_record (@place_records) {
        $count++;
        if ( not $count % $increment ) {
            $cry->over( int( ( $count / $total ) * 100 ) . "%" );
        }

        my %field;
        @field{@place_headers} = @{$place_record};

        my $city = $HASTUS_CITY_OF{ $field{plc_district} };

        my $abbrev9 = _abbrev9( $field{plc_number}, $field{plc_identifier} );

        my $description = titlecase( $field{plc_description} );

        my @new_record
          = ( @field{@place_headers}, $city, $abbrev9, $description );
        trim(@new_record);
        push @returned_records, \@new_record;

    } ## tidy end: foreach my $place_record (@place_records)

    $cry->over('100%');
    $cry->done;

    return \@returned_headers, \@returned_records;

} ## tidy end: sub hastus_places_import

sub _abbrev9 {
    my $number     = shift;
    my $identifier = shift;

    $number = $identifier if not defined $number or $number eq $EMPTY;

    return $number if length($number) <= 4;

    my $first = substr( $number, 0, 4 );
    my $second = substr( $number, 4 );
    trim( $first, $second );
    my $abbrev9 = "$first $second";

}

sub hastus_stops_import {

    my $cry = cry('Calculating fields derived from Hastus stop data');

    my @stop_headers = @{ +shift };
    my @stop_records = @{ +shift };

    my @returned_headers = (
        ( map { $ORIG_PREFIX . $_ } @stop_headers ),
        (   map { $CALC_PREFIX . $_ }
              (qw[on at street_num comment city direction])
        ),
    );

    my @returned_records;

    my $count     = 0;
    my $total     = scalar(@stop_records);
    my $increment = $total / 15;

    foreach my $stop_record (@stop_records) {
        $count++;
        if ( not $count % $increment ) {
            $cry->over( int( ( $count / $total ) * 100 ) . "%" );
        }

        my %field;
        @field{@stop_headers} = @{$stop_record};

        my ( $on, $at, $stnum, $comment )
          = _stops_description( $field{stp_description} );

        _street_name( $on, $at );

        my $direction = _direction( $field{stp_corner}, $field{stop_site} );

        # stop_site is correct, unlike all other stp_ fields

        my $city = $HASTUS_CITY_OF{ $field{stp_district} };

        my @new_record = (
            @field{@stop_headers},
            u::define( $on, $at, $stnum, $comment, $city, $direction )
        );
        trim(@new_record);
        push @returned_records, \@new_record;

    } ## tidy end: foreach my $stop_record (@stop_records)

    $cry->over('100%');

    $cry->done;

    return \@returned_headers, \@returned_records;

} ## tidy end: sub hastus_stops_import

const my %ENDING_OF => (
    Av   => 'Ave.',
    Ave  => 'Ave.',
    Cir  => 'Cir.',
    Cr   => 'Cr.',          # this one is ambiguous
    Ct   => 'Ct.',
    Com  => 'Com.',         # Common or Commons?
    Dr   => 'Dr.',
    E    => 'East',
    Ext  => 'Extension',
    Fwy  => 'Fwy.',
    Ln   => 'Lane',
    Lp   => 'Loop',
    Pkwy => 'Pkwy.',
    Pl   => 'Pl.',
    Rd   => 'Road',
    St   => 'St.',
    Blvd => 'Blvd.',
    S    => 'South',
    N    => 'North',
    W    => 'West',
    Sch  => 'School',
    Sq   => 'Square',
    Ter  => 'Terr.',
    Terr => 'Terr.',
    Apts => 'Apartments',
);

const my %BEGINNING_OF => (
    S => 'South',
    N => 'North',
    W => 'West',
    E => 'East',
);

sub _street_name {

    foreach (@_) {

        for my $bad ( keys %ENDING_OF ) {
            my $good = $ENDING_OF{$bad};
            s/\s+$bad\.?\z/ $good/i;
        }

        for my $bad ( keys %BEGINNING_OF ) {
            my $good = $BEGINNING_OF{$bad};
            next if $_ eq "$bad St." or $_ eq "$bad Ave.";
            s/\A$bad\.?\b/$good/i;
        }

        s/Amtrak Station/Amtrak/i;
        s/Caltrain Station/Caltrain/i;
        s/N Berkeley BART/North Berkeley BART/i;
        s/BART Station/BART/i;
        s/\bBart\b/BART/i;
        s/Martin Luther King Jrway/Martin Luther King Jr. Way/i;
        s/\AMlk Jr\z/Martin Luther King Jr. Way/i;
        s/\AMlk Way\z/Martin Luther King Jr. Way/i;
        s/\AFwy /Highway /i;
        s/\b(Mc) ([A-Z])/$1$2/i;
        s/\bAlvarado Niles\b/Alvarado-Niles/i;
        s/P\s*\&\s*R/Park & Ride/i;
        # changes “P&R” or “P & R” to “Park and Ride”
        s/Bayfair BART/Bay Fair BART/i;
        s/\ADel Norte BART/El Cerrito del Norte BART/i;
        s/\bJr\b/Jr./i;
        s/(I-[0-9]{1,3}) Fwy/$1/i;
        s/MacDonald/Macdonald/i;
        s/Northport Lp\b/Northport Loop/i;

    } ## tidy end: foreach (@_)

    return;

} ## tidy end: sub _street_name

sub _stops_description {
    my $desc = shift;

    my ( $on, $at, $stnum, $comment ) = ( $EMPTY, $EMPTY, $EMPTY, $EMPTY );
    # assign these the empty streets to avoid
    # "Undefined value in comparison errors

    my $rest;
    ( $on, $rest ) = split( /:/, $desc, 2 );
    # on is everything before colon, if there's a colon
    # the rest is everything else

    if ( $on =~ / at / and not $rest ) {
        ( $on, $rest ) = split( / at /i, $desc, 2 );
    }
    # or if there's not a colon, then on is everything before " at ",
    # and $rest is everything else

    if ( $on =~ /\#/ and not $rest ) {
        ( $on, $rest ) = split( /\#/i, $desc, 2 );
        $rest = '#' . $rest;
    }
    # if there's no colon or " at ", but there is a number sign,
    # add a number sign to
    # the rest, so the following code recognizes it as a street number

    if ($rest) {
        $rest =~ s{  \( ( .* ) \) } {}sx;
        $comment = $1;
        # remove the comment from $rest and put it in $comment

        if ( $rest =~ /Berkley/ and $comment and $comment =~ /20th/ ) {
            $rest .= " ($comment)";
            $comment = $EMPTY;
        }    # Thomas L. Berkley Way (20th St.) is "at"...

        # But put it back if it's Thomas L. Berkley Way (20th St.)

        if ( $rest =~ /\A\s*#/s or $rest =~ /\A[0-9]+\z/s ) {
            $stnum = $rest;
            $stnum =~ s/\A#//s;
        }
        # if the rest has a number sign (possibly with spaces), or
        # it consists entirely of numbers, put the rest into the street
        # number
        else {
            $at = $rest;
        }
        # otherwise put it in "at"

        $at =~ s/\bat //i;
        # remove any literal word "at" (followed by a word break, and including
        # a subsequent space, and
    } ## tidy end: if ($rest)

    if ($comment) {
        for ($comment) {
            s/\bJctn\b/junction/i;
            s/BART Station/BART/i;

        }
    }

    return trim( $on, $at, $stnum, $comment );

} ## tidy end: sub _stops_description

const my %DIRECTION_OF => (
    NEFS => "N",
    NENS => "W",
    NWNS => "S",
    NWFS => "W",
    SENS => "N",
    SEFS => "E",
    SWNS => "E",
    SWFS => "S",
);

sub _direction {
    my $corner = uc(shift);
    my $site   = uc(shift);

    my $cornersite = $corner . $site;

    return $EMPTY unless exists $DIRECTION_OF{$cornersite};
    return $DIRECTION_OF{$cornersite};

}

1;

__END__


=encoding utf8

=head1 NAME

Actium::Import::CaclulateFields - Routines for adding fields based on 
Hastus exports

=head1 FIELDS

Builds the following fields:

=head2 places

=head3 i_city	

Takes the numeric district code and returns the city.

=head3 i_abbrev9	

Takes the eight-character place abbreviation (confusingly called
plc_number in the Hastus export) and adds a space in the middle to make
it nine characters. This is primarily for compatibility with old Actium
programs and routines that use this. Ideally it should be phased out
and the plc_identifier used instead, since Actium doesn't use this for
display anywhere.

=head4 i_description

A titlecased version (using the Lingua::EN::Titlecase::Simple) of the
provided description.

=head2 stops

The i_on, i_at, i_comment, and i_street_num fields are the result of
parsing  the stp_description field from Hastus.

=head3 i_on

This is the street the stop is on, and is the only one that should
never be  blank. It generally consists of the portion of the
description before the  colon.

=head3 i_at

This is the cross-street of the stop. It can be blank, and often is.

=head3 i_comment

If there is a portion of the description in parentheses, that is
extracted  into i_comment.

=head3 i_street_num

If there is a portion of the description after a number sign, that is
extracted into i_street_num.

=head3 i_city

Takes the numeric district code and returns the name for that district.
(Note that some districts are counties or other areas.)

=head3 i_direction

Combines the corner (northwest corner, southwest corner, etc.)  and
site (nearside / farside) information and deduces the direction of
travel from it.

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

