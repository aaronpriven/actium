package Actium::Cmd::ReadXLSXSchedule 0.012;

# This is very much in progress and not a complete program yet.

use Actium::Preamble;
use Actium::O::Sked;
use Actium::O::Sked::Trip;
use Actium::Util(qw[joinseries ]);
use Actium::O::2DArray;

our $VERSION = 0.010;

use Spreadsheet::XLSX;    ### DEP ###
use List::Compare::Functional (qw/is_LsubsetR/);    ### DEP ###

const my @used_sheets         => qw[intro tpsked stopsked];
const my @mandatory_intros    => qw[id days dir];
const my $mandatory_introtext => joinseries(@mandatory_intros);

my $file;
my $xlsx;

sub START {

  #my $file = '/Users/apriven/Dev/signups/su12/s/xlsx/P_WB_12345.xlsx';
    $file = '/Users/apriven/Desktop/P_WB_12345.xlsx';
    $xlsx = Spreadsheet::XLSX->new($file);

    _check_sheets($xlsx);

    my %intros = _get_intros($xlsx);

    my @trips = _get_trips($xlsx);

    return;

}

sub _get_trips {
    my $xlsx = shift;

    my @tp_rows   = _get_rows('tpsked');
    my @stop_rows = _get_rows('stopsked');

    croak q{Different number of rows in the "tpsked" sheet than the }
      . qq{ "stopsked" sheet in file $file}
      unless @tp_rows == @stop_rows;

    #say u::joinlf( @{ tabulate(@tp_rows) } );
    say Actium::O::2DArray->new(@tp_rows)->tabulated();
    say $EMPTY_STR;
    #say u::joinlf( @{ tabulate(@stop_rows) } );
    say Actium::O::2DArray->new->(@stop_rows)->tabulated();

}

sub _get_rows {
    my $sheetname = shift;
    my @rows;

    my $sheet = $xlsx->worksheet($sheetname);
    my ( $top,  $bottom ) = $sheet->row_range();
    my ( $left, $right )  = $sheet->col_range();

    for my $row_idx ( $top .. $bottom ) {
        my @row = map { $sheet->get_cell( $row_idx, $_ ) } ( $left .. $right );

        for my $cell (@row) {
            my $value = defined $cell ? $cell->value : $EMPTY_STR;

            $value = _excel_to_timestr( $cell->unformatted )
              if (  Scalar::Util::looks_like_number $value
                and $value >= -.5
                and $value <= 1.5 );
            # Excel time fraction

            $cell = $value;

        }

        next if u::all { u::isempty($_) } @row;
        # skip blank rows
        push @rows, \@row;
    } ## tidy end: for my $row_idx ( $top ...)

    return @rows;
} ## tidy end: sub _get_rows

sub _excel_to_timestr {

    my $timefraction = shift;
    my $ampm         = $EMPTY_STR;

    if ( $timefraction < 0 ) {
        $timefraction += 0.5;
        $ampm = "b";
    }

    require Spreadsheet::ParseExcel::Utility;    ### DEP ###

    my ( $minutes, $hours )
      = ( Spreadsheet::ParseExcel::Utility::ExcelLocaltime($timefraction) )
      [ 1, 2 ];
#    my @localtimes = Spreadsheet::ParseExcel::Utility::ExcelLocaltime($timefraction);
#    my $minutes = $localtimes[1];
#    my $hours = $localtimes[2];

    return $hours . sprintf( "%02d", $minutes ) . $ampm;

} ## tidy end: sub _excel_to_timestr

sub _get_intros {
    my $xlsx = shift;
    my %intros;
    my $introsheet = $xlsx->worksheet('intro');
    my ( $row_min, $row_max ) = $introsheet->row_range();
    my ( $col_min, $col_max ) = $introsheet->col_range();

    if ( $col_max != ( $col_min + 1 ) ) {
        if ( $col_max <= $col_min ) {
            croak "Not enough columns in intro sheet of $file";
        }
        else {
            croak "Too many columns in intro sheet of $file";
        }
    }

    for my $row ( $row_min .. $row_max ) {
        my $attribute = $introsheet->get_cell( $row, $col_min )->value;
        my $value     = $introsheet->get_cell( $row, $col_min + 1 )->value;

        my $av = ( u::isempty($attribute) ? $EMPTY_STR : 'A' )
          . ( u::isempty($value) ? $EMPTY_STR : 'V' );

        if ( $av eq 'AV' ) {
            $intros{$attribute} = $value;
        }
        elsif ( $av eq 'A' ) {
            croak "No value for $attribute in intro sheet of $file";
        }
        elsif ( $av eq 'V' ) {
            croak "No attribute name for value $value in intro sheet of $file";
        }

    }

    unless ( is_LsubsetR [ \@mandatory_intros, [ keys %intros ] ] ) {
        croak "Did not find all the mandatory attributes"
          . "($mandatory_introtext) in intro sheet of file $file";
    }

    return %intros;

} ## tidy end: sub _get_intros

sub _check_sheets {
    my $xlsx = shift;

    my @names = sort map { $_->get_name } $xlsx->worksheets;

    my %is_a_sheet;
    $is_a_sheet{$_} = 1 foreach @names;

    foreach my $sheetname (@used_sheets) {
        unless ( $is_a_sheet{$sheetname} ) {
            croak "Can't locate sheet in $file: $sheetname";
        }
    }

    delete @is_a_sheet{@used_sheets};

    foreach my $sheetname ( keys %is_a_sheet ) {
        carp "Unrecognized sheet: $sheetname";
    }

    return;

} ## tidy end: sub _check_sheets

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
