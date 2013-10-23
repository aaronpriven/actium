#!/ActivePerl/bin/perl

use 5.016;
use Actium::Preamble;
use Actium::O::Sked;
use Actium::O::Sked::Trip;

use Spreadsheet::XLSX;

const my @used_sheets => qw[intro tpsked stopsked];
const my @mandatory_intros => qw[id days dir];

my $file = '/Users/apriven/Dev/signups/su12/s/xlsx/P_WB_12345.xlsx';

my $xlsx = Spreadsheet::XLSX->new($file);

_check_sheets($xlsx);

my %intros = _get_intros ($xlsx);

sub _get_intros {
   my $xlsx = shift;
   my %intros;
   my $introsheet = $xlsx->worksheet('intro');
   my ( $row_min, $row_max ) = $introsheet->row_range();
   my ( $col_min, $col_max ) = $introsheet->col_range(); 
   
   if ($col_max <= $col_min) {
       croak "Not enough columns in intro sheet of $file";
   } elsif ($col_max != ($col_min +1) ) {
       croak "Too many columns in intro sheet of $file";
   }
    
   
   
   
   
   
   for my $row ($row_min .. $row_max) {
       my $attribute = $introsheet->get_cell( $row, $col_min)->value;
       my $value = $introsheet->get_cell( $row, $col_min+1)->value;
       if (defined($attribute) xor defined($value) ) {
           # if only one is defined,
           
           # check all this
        
        
       }
       $intros{$attribute} = $value;
   }
   
   return %intros;
 
}

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

}
