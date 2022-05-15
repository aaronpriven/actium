package Octium::Clever::CSVfile 0.019;
# vimcolor: #000040

use Actium('role');
use Text::CSV;

requires qw/_load_csv_data _key_cols/;

has preamble => (
    is  => 'rwp',
    isa => 'Str',
);

has '_column_names_r' => (
    traits   => ['Array'],
    is       => 'rw',
    isa      => 'ArrayRef',
    init_arg => 'column_names',
    handles  => { 'column_names' => 'elements', },
);

has '_column_idx_of_r' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    builder => '_build_column_idx_of',
    lazy    => 1,
    handles => { col_idx => 'get', },
);

has '_rows_r' => (
    traits   => ['Array'],
    is       => 'rw',
    isa      => 'ArrayRef',
    init_arg => 'rows',
    handles  => {
        'row'  => 'get',
        'rows' => 'elements'
    },
);

has '_row_of_r' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef',
    builder => '_build_row_of',
    lazy    => 1,
    handles => { keys => 'keys', },
);
# with composite keys, the names get pointless. "route-variant-stop"?

classmethod load_csv (Actium::Storage::File $file, %args) {
    my $csv      = Text::CSV->new( { binary => 1 } );
    my $basename = $file->basename;
    if ( Actium::u_columns($basename) > 30 ) {
        $basename
          = Actium::u_trim_to_columns( string => $basename, columns => 27 )
          . '...';
    }
    my $load_cry = env->cry(qq{Loading Clever file "$basename"});

    my $fh = $file->openr_text;

    my $obj = $class->new(%args);
    $obj->_load_csv_headers( fh => $fh, csv => $csv );
    $obj->_load_csv_data( fh => $fh, csv => $csv );
    # _load_data provided by consuming classes

    close $fh;

    $load_cry->done;
    return $obj;
}

method _load_csv_headers (:$fh!, :$csv!) {
    my $preamble = '';
    $preamble .= ( scalar readline $fh ) . ( scalar readline $fh );
    # metadata and version lines
    my $nameline = scalar readline $fh;
    $preamble .= $nameline;
    $self->_set_preamble($preamble);

    $csv->parse($nameline);
    my @column_names = $csv->fields();
    s/\s*\*// foreach @column_names;    # remove asterisks in field names
    my %column_idx_of = map { $column_names[$_] => $_ } 0 .. $#column_names;
    $self->_set_column_names_r( \@column_names );
    $self->_set_column_idx_of_r( \%column_idx_of );
}

method filter ($callback!) {
    \my @rows         = $self->_rows_r;
    \my @column_names = $self->_column_names_r;
    my @newrows;

    foreach \my @row(@rows) {
        my %hash = map { $column_names[$_] => $row[$_] } 0 .. $#column_names;
        my $newrow_r = $callback->( \%hash );
        next unless $newrow_r;
        my @newrow = @{$newrow_r}{@column_names};
        push @newrows, \@newrow;
    }

    return $self->clone( \@newrows );

}

method clone ($rows_r) {
    my $class = Actium::blessed($self);
    $rows_r //= [ $self->_rows_r->@* ];

    my $clone = $class->new(
        preamble     => $self->preamble,
        column_names => [ $self->column_names ],
        rows         => $rows_r
    );

    return $clone;

}

method _build_column_idx_of {
    \my @column_names = $self->_column_names_r;
    my %column_idx_of = map { $column_names[$_] => $_ } @column_names;
    return \%column_idx_of;
}

method _build_row_of {
    my @key_col_idxs = map { $self->col_idx($_) } $self->_key_cols;
    # _key_cols provided by consuming class

    my %row_of;

    \my @rows = $self->_rows_r;
    foreach \my @row(@rows) {
        my @values = @row[@key_col_idxs];
        my $key    = join( "|", @values );
        $row_of{$key} = \@row;
    }

    return \%row_of;

}

method store_csv (Actium::Storage::File $file) {
    state $csv_out
      = Text::CSV->new( { binary => 1, eol => "\r\n", quote_space => 0 } );

    my $cry = env->cry( "Writing " . $file->basename );

    my $fh = $file->openw_text;
    print $fh $self->preamble;
    \my @rows = $self->_rows_r;
    $csv_out->print( $fh, $_ ) foreach @rows;
    close $fh;

    $cry->done;

}

1;
