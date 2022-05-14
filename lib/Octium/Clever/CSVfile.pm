package Octium::Clever::CSVfile 0.019;
# vimcolor: #000040

use Actium('role');

requires qw/_load_csv_data _key_cols/;

has preamble => (
    is  => 'rwp',
    isa => 'Str',
);

has 'column_names' => (
    traits => ['Array'],
    is     => 'rwp',
    isa    => 'ArrayRef',
);

has '_column_idx_of' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    builder => '_build_column_idx_of',
    lazy    => 1,
    handles => {
        column_names => 'keys',
        col_idx      => 'get',
    },
);

has 'rows' => (
    traits  => ['Array'],
    is      => 'rwp',
    isa     => 'ArrayRef',
    handles => { 'row' => 'get' },
);

has '_row_of' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef',
    builder => '_build_row_of',
    lazy    => 1,
    handles => {
        _row_of => 'get',
        keys    => 'keys',
    },
);
# with composite keys, the names get pointless. "route-variant-stop"?

my $csv = Text::CSV->new( { binary => 1 } );

classmethod load_csv (Actium::Storage::File $file, %args) {
    my $load_cry = env->cry('Loading Clever file');

    $load_cry->wail( $file->basename );
    my $fh = $file->openr_text;

    my $obj = $class->new(%args);
    $obj->_load_csv_headers($fh);
    $obj->_load_csv_data( fh => $fh, csv => $csv );
    # _load_data provided by consuming classes

    close $fh;

    $load_cry->done;
}

method filter ($callback!) {
    \my @rows          = $self->rows;
    \my %column_idx_of = $self->_column_idx_of;
    \my @column_names  = $self->_column_names;
    my @newrows;

    foreach \my @row(@rows) {
        my %hash     = map { $_ => $row[$_] } keys %column_idx_of;
        my $newrow_r = $callback->( \%hash );
        next unless $newrow_r;
        my @newrow = @{$newrow_r}{@column_names};
        push @newrows, \@newrow;
    }

    return $self->clone( \@newrows );

}

method clone ($rows_r) {
    my $class = Actium::blessed($self);
    $rows_r //= $self->rows;

    my $clone = $class->new(
        preamble     => $self->preamble,
        column_names => $self->column_names,
        rows         => $rows_r
    );

    return $clone;

}

method _load_csv_headers ($fh) {
    my $preamble = '';
    $preamble .= ( scalar readline $fh ) . ( scalar readline $fh );
    # metadata and version lines
    my $nameline = scalar readline $fh;
    $preamble .= $nameline;
    $self->_set_preamble($preamble);

    $self->csv->parse($nameline);
    my @column_names = $self->csv->fields();
    s/\s*\*// foreach @column_names;    # remove asterisks in field names
    my %column_idx_of = map { $column_names[$_] => $_ } @column_names;
    $self->_set_column_names( \@column_names );
    $self->_set_column_idx_of( \%column_idx_of );
}

method _build_column_idx_of {
    \my @column_names = $self->_column_names;
    my %column_idx_of = map { $column_names[$_] => $_ } @column_names;
    return \%column_idx_of;
}

method _build_row_of {
    my @col_idxs = map { $self->col_idx($_) } $self->_key_cols;
    # _key_cols provided by consuming class

    my %row_of;

    \my @rows = $self->rows;
    foreach \my @row(@rows) {
        my @values = @row[@col_idxs];
        my $key    = join( "|", @values );
        $row_of{$key} = \@row;
    }

    return \%row_of;

}

method store_csv (Actium::Storage::File $file) {
    state $csv_out = Text::CSV->new( { binary => 1, eol => "\r\n" } );

    my $cry = env->cry("Writing $file");

    my $fh = $file->openr_text;
    print $fh $self->preamble;
    \my @rows = $self->rows;
    $csv->print( $fh, $_ ) foreach @rows;
    close $fh;

    $cry->done;

}

1;
