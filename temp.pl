#!/ActivePerl/bin/perl

use 5.016;
use Actium::Preamble;
use Actium::O::Sked;
use Actium::O::Sked::Trip;
use Actium::Util('joinseries');
use List::MoreUtils('mesh');

use Spreadsheet::XLSX;
use List::Compare::Functional (qw/is_LsubsetR/);

const my @used_sheets      => qw[intro tpsked stopsked];
const my @mandatory_intros => qw[id days dir];
const my $mandatory_introtext => joinseries(@mandatory_intros);

my $file = '/Users/apriven/Dev/signups/su12/s/xlsx/P_WB_12345.xlsx';

my $xlsx = Spreadsheet::XLSX->new($file);

_check_sheets($xlsx);

my %intros = _get_intros($xlsx);

my @trips = _get_trips($xlsx);

sub _get_trips {
    my $xlsx = shift;
    my $tpsheet = $xlsx->worksheet('tpsked');
    my $stopsheet = $xlsx->worksheet('stopsked');
    
    
 
 
}


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

    unless (is_LsubsetR [ \@mandatory_intros, [ keys %intros ] ] ) {
        croak "Did not find all the mandatory attributes" . 
              "($mandatory_introtext) in intro sheet of file $file";
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
