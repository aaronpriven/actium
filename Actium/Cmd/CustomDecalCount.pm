# /Actium/Cmd/CustomDecalCount.pm
#
# Makes spreadsheet to calculate decal count

# Subversion: $Id$

package Actium::Cmd::CustomDecalCount 0.008;

use Actium::Preamble;
use Actium::Cmd::Config::ActiumFM ('actiumdb');
use File::Spec;
use File::Basename;
use Spreadsheet::ParseXLSX;

sub HELP {
    say "Help not implemented.";
}

sub START {

    my $class      = shift;
    my %params     = @_;
    my $config_obj = $params{config};

    my $actium_db = actiumdb($config_obj);

    my ( $input_file, $output_file ) = get_paths( $params{argv} );

    my $parser   = Spreadsheet::ParseXLSX->new;
    my $workbook = $parser->parse($input_file);

    my $sheet = $workbook->worksheet(0);

    if ( !defined $workbook ) {
        die $parser->error(), ".\n";
    }

    my ( $minrow, $maxrow ) = $sheet->row_range();
    my ( $mincol, $maxcol ) = $sheet->col_range();
    

    my $decals_of_r = $actium_db->all_in_column_key(qw/Stops_Neue p_decals/);
    
    my %routes_of;

    foreach my $row ( $minrow .. $maxrow ) {

        my @cells =
          map { $sheet->get_cell( $row, $_ ) } $mincol, $mincol + 1;

        foreach (@cells) {
            if (defined $_) {
                $_ = $_->value;
            } else {
                $_ = $EMPTY_STR;
            }
        }

        my ( $stopid, $routes ) = @cells;
        next if $stopid !~ /\d+/;
        
        my (@routes) = split (/[\W_]/, $routes);
        
        $routes_of{$stopid} = \@routes;

    }
    
    foreach my $stopid (keys %routes_of) {
        
        my $decals = $decals_of_r->{$stopid};
        say "$stopid\t$decals";
        # here is where you get only routes you want
        
    }

}    ## tidy end: sub START

sub get_paths {

    my $argv_r     = shift;
    my $input_path = shift @{$argv_r};

    my ( $volume, $folders, $input_name ) = File::Spec->splitpath($input_path);

    my ( $basename, undef, $suffix ) =
      fileparse( $input_name, qr/(?i:\.xlsx)/ );

    my $output_path =
      File::Spec->catpath( $volume, $folders, "$basename-counted$suffix" );

    return ( $input_path, $output_path );
}

1;

__END__
