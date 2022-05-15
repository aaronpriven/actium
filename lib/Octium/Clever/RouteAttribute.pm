package Octium::Clever::RouteAttribute 0.019;

use Actium('class');

has keep_all => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

method _load_csv_data (:$fh, :$csv) {
    my @rows;

    if ( $self->keep_all ) {
        @rows = getline_all($fh);
    }
    else {
        my $insvc_index = $self->col_idx('InService');
        my $route_index = $self->col_idx('RouteName');
        while ( my $row_r = $csv->getline($fh) ) {
            my $route = $row_r->[$route_index];
            push @rows, $row_r
              if $row_r->[$insvc_index]
              and not( $route eq '99999' or $route =~ /\A39[23469]\z/ );
        }
    }

    $self->_set_rows_r( \@rows );
}

method _key_cols {
    return qw/RouteName RouteVariant/;
}

with 'Octium::Clever::CSVfile';

1;
