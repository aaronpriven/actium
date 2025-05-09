package Octium::Clever::RouteAudio 0.019;

use Actium('class');

has '_in_service_variants_r' => (
    traits   => ['Array'],
    is       => 'ro',
    init_arg => 'in_service_variants',
    isa      => 'ArrayRef',
    default  => sub { [] },
);

method _load_csv_data (:$fh, :$csv) {
    my @rows;

    \my @in_service_variants = $self->_in_service_variants_r;

    if ( not @in_service_variants ) {
        @rows = @{ $csv->getline_all($fh) };
    }
    else {
        my %use_variant = map { $_ => 1 } @in_service_variants;
        my @idxs        = map { $self->col_idx($_) } qw/RouteID RouteVar/;

        while ( my $row_r = $csv->getline($fh) ) {
            my ( $route, $variant ) = $row_r->@[@idxs];
            my $var_fullid = "$route|$variant";
            push @rows, $row_r if $use_variant{$var_fullid};
        }
    }

    $self->_set_rows_r( \@rows );
}

method _key_cols {
    return qw/RouteName RouteVariant MessageType/;
}

with 'Octium::Clever::CSVfile';

1;
