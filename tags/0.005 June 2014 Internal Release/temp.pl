#!/ActivePerl/bin/perl

use 5.016;
use Actium::Preamble;
use Actium::O::Sked;
use Actium::O::Sked::Trip;
use Actium::Util(qw[joinseries tabulate]);

use Spreadsheet::XLSX;
use List::Compare::Functional (qw/is_LsubsetR/);

const my @used_sheets         => qw[intro tpsked stopsked];
const my @mandatory_intros    => qw[id days dir];
const my $mandatory_introtext => joinseries(@mandatory_intros);

#my $file = '/Users/apriven/Dev/signups/su12/s/xlsx/P_WB_12345.xlsx';
my $file = '/Users/apriven/Desktop/P_WB_12345.xlsx';
my $xlsx = Spreadsheet::XLSX->new($file);

_check_sheets($xlsx);

my %intros = _get_intros($xlsx);

my @trips = _get_trips($xlsx);

sub _get_trips {
    my $xlsx = shift;

    my @tp_rows   = _get_rows('tpsked');
    my @stop_rows = _get_rows('stopsked');

    croak q{Different number of rows in the "tpsked" sheet than the }
      . qq{ "stopsked" sheet in file $file}
      unless @tp_rows == @stop_rows;

    say jn( @{ tabulate(@tp_rows) } );
    say $EMPTY_STR;
    say jn( @{ tabulate(@stop_rows) } );

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

        next unless any { isnotblank($_) } @row;
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

    require Spreadsheet::ParseExcel::Utility;

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

        my $av = ( isblank($attribute) ? $EMPTY_STR : 'A' )
          . ( isblank($value) ? $EMPTY_STR : 'V' );

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
