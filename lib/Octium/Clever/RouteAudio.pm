package Octium::Clever::RouteAudio 0.019;

use Actium('class');

has 'in_service_variants_r' => (
    traits  => ['Array'],
    reader  => '_in_service_variants_r',
    isa     => 'ArrayRef',
    default => sub { [] },
);

with 'Octium::Clever::CSVfile';

method _load_data ($fh) {
    state $csv = $self->csv;
    my @rows;

    \my @in_service_variants = $self->_in_service_variants_r;

    if ( not @in_service_variants ) {
        @rows = getline_all($fh);
    }
    else {
        my %use_variant = map { $_ => 1 } @in_service_variants;
        my @idxs = map { $self->index_of($_) } qw/RouteName RouteVariant/;

        while ( my $row_r = $csv->getline($fh) ) {
            my ( $route, $variant ) = $row_r->@[@idxs];
            my $var_fullid = "$route|$variant";
            push @rows, $row_r if $use_variant{$var_fullid};
        }
    }

    $self->_set_rows( \@rows );
}

method _key_cols {
    return qw/RouteName RouteVariant MessageType/;
}

1;
