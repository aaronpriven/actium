# /Actium/Import/CalculateFields.pm
#
# Routines for calculating fields based on imported data.
# Does things like break up "description" into "on" and "at". Etc.
# This is probably a terrible name for this.

# Subversion: $Id$

package Actium::Import::CalculateFields 0.004;

use Actium::Preamble;
use Text::Trim;
use Actium::Term;
use Lingua::EN::Titlecase::Simple('titlecase');

const my $CALC_PREFIX => 'i_';
const my $ORIG_PREFIX => 'h_';

sub hastus_places_import {

    emit 'Calculating fields derived from Hastus place data';

    my @place_headers = @{ +shift };
    my @place_records = @{ +shift };

    my @returned_headers = (
        map { $ORIG_PREFIX . $_ } @place_headers,
        map { $CALC_PREFIX . $_ } (qw (city abbrev9 description ))
    );

    my @returned_records;
    my $count     = 0;
    my $total     = scalar(@place_records);
    my $increment = $total / 15;

    foreach my $place_record (@place_records) {
        $count++;
        if ( not $count % $increment ) {
            emit_over( int( ( $count / $total ) * 100 ) . "%" );
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

    emit_over '100%';
    emit_done;

    return \@returned_headers, \@returned_records;

} ## tidy end: sub hastus_places_import

sub _abbrev9 {
    my $number     = shift;
    my $identifier = shift;

    $number = $identifier if not defined $number or $number eq $EMPTY_STR;

    return $number if length($number) <= 4;

    my $first = substr( $number, 0, 4 );
    my $second = substr( $number, 4 );
    trim( $first, $second );
    my $abbrev9 = "$first $second";

}

sub hastus_stops_import {

    emit 'Calculating fields derived from Hastus stop data';

    my @stop_headers = @{ +shift };
    my @stop_records = @{ +shift };

    my @returned_headers = (
        (map { $ORIG_PREFIX . $_ } @stop_headers),
        (map { $CALC_PREFIX . $_ } 
           (qw[on at street_num comment city direction])),
    );

    my @returned_records;

    my $count     = 0;
    my $total     = scalar(@stop_records);
    my $increment = $total / 15;

    foreach my $stop_record (@stop_records) {
        $count++;
        if ( not $count % $increment ) {
            emit_over( int( ( $count / $total ) * 100 ) . "%" );
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
            doe( $on, $at, $stnum, $comment, $city, $direction )
        );
        trim(@new_record);
        push @returned_records, \@new_record;

    } ## tidy end: foreach my $stop_record (@stop_records)

    emit_over '100%';

    emit_done;

    return \@returned_headers, \@returned_records;

} ## tidy end: sub hastus_stops_import

const my %ENDING_OF => (
    Av   => 'Ave.',
    Ave  => 'Ave.',
    Cir  => 'Cir.',
    Cr   => 'Cr.',          # this one is ambiguous
    Ct   => 'Ct.',
    Com  => 'Commons',
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
    Terr => 'Terr',
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
        s/Caltrain Station/Amtrak/i;
        s/N Berkeley BART/North Berkeley BART/i;
        s/BART Station/BART/i;
        s/Bart/BART/i;
        s/Martin Luther King Jrway/Martin Luther King Jr. Way/i;
        s/\AMlk Jr\z/Martin Luther King Jr. Way/i;
        s/\AMlk Way\z/Martin Luther King Jr. Way/i;
        s/\AFwy /Highway /i;
        s/\b(Mc) ([A-Z])/$1$2/;
        s/\bAlvarado Niles\b/Alvarado-Niles/;
        s/P\s*\&\s*R/Park and Ride/;
        s/Bayfair BART/Bay Fair BART/i;
        s/\ADel Norte BART/El Cerrito del Norte BART/i;
        s/\bJr\b/Jr./i;
        s/(I-[0-9]{1,3}) Fwy/$1/;
        s/MacDonald/Macdonald/;
        s/Northport Lp\b/Northport Loop/i;

    } ## tidy end: foreach (@_)

    return;

} ## tidy end: sub _street_name

sub _stops_description {
    my $desc = shift;

    my ( $on, $at, $stnum, $comment )
      = ( $EMPTY_STR, $EMPTY_STR, $EMPTY_STR, $EMPTY_STR );

    my $rest;
    ( $on, $rest ) = split( /:/, $desc, 2 );

    if ( $on =~ / at / and not $rest ) {
        ( $on, $rest ) = split( / at /i, $desc, 2 );
    }

    if ( $on =~ /\#/ and not $rest ) {
        ( $on, $rest ) = split( /\#/i, $desc, 2 );
        $rest = '#' . $rest;
    }

    if ($rest) {
        $rest =~ s{  \( ( .* ) \) } {}sx;
        $comment = $1;

        if ( $rest =~ /Berkley/ and $comment and $comment =~ /20th/ ) {
            $rest .= " ($comment)";
            $comment = $EMPTY_STR;
        }    # Thomas L. Berkley Way (20th St.) is "at"...

        if ( $rest =~ /\A\s*#/s or $rest =~ /\A[0-9]+\z/s ) {
            $stnum = $rest;
            $stnum =~ s/\A#//s;
        }
        else {
            $at = $rest;
        }

        $at =~ s/\bat //i;
    }

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

    return $EMPTY_STR unless exists $DIRECTION_OF{$cornersite};
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

==> place_pc.txt <==

i_city	

Takes the numeric district code and returns the city.

i_abbrev9	

Takes the eight-character place abbreviation (confusingly called
plc_number in the Hastus export) and adds a space in the middle
to make it nine characters. This is primarily for compatibility
with old actium programs and routines that use this.
Ideally it should be phased out and the plc_identifier used instead.

i_description

A titlecased version (using Lingua::EN::Titlecase::Simple) of
the provided description.

==> stop_pc.txt <==
stp_511_id	stp_pc_on	stp_pc_at	stp_pc_stnum	stp_pc_comment	stp_pc_city	stp_pc_direction


