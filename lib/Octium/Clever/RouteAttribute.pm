package Octium::Clever::RouteAttribute 0.019;

use Actium('class');

has keep_all => (
    is      => 'ro',
    isa     => 'Bool',
    default => 0,
);

method _load_data ($fh) {
    state $csv = $self->csv;
    my @rows;

    if ( $self->keep_all ) {
        @rows = getline_all($fh);
    }
    else {
        my $insvc_index = $self->index_of('InService');
        while ( my $row_r = $csv->getline($fh) ) {
            push @rows, $row_r if $row_r->[$insvc_index];
        }
    }

    $self->_set_row_r( \@rows );
}

method _key_cols {
    return qw/RouteName RouteVariant/;
}

with 'Octium::Clever::CSVfile';

1;
