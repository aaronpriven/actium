package Octium::Clever::CSVfile 0.019;

use Actium('role');

requires qw/_load_data _key_cols/;

has file => (
    required => 1,
    is       => 'ro',
    isa      => 'Actium::Storage::File',
);

has preamble => (
    is       => 'rwp',
    init_arg => undef,
    isa      => 'Str',
);

has '_columns' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef',
    writer  => '_set_columns',
    handles => {
        column_names => 'keys',
        index_of     => 'get',
    },
);

has '_rows' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef',
    handles => { 'row_number' => 'get', },
);

has '_row_of' => (
    traits  => ['Hash'],
    is      => 'bare',
    isa     => 'HashRef',
    builder => '_build_row_of',
    handles => {
        row_of_var => 'get',
        variants   => 'elements',
    },
);

method BUILD {
    $self->_open;
}

method _open {
    my $load_cry = env->cry('Loading Clever file');
    my $file     = $self->file;
    $load_cry->wail( $file->basename );
    my $fh = $file->openr_text;

    $self->_load_headers($fh);

    $self->_load_data($fh);
    # _load_data provided by consuming classes

    close $fh;

    $load_cry->done;
}

method _load_headers ($fh) {
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
    $self->_set_columns( \%column_idx_of );
}

method _buld_row_of {
    my @columns = map { $self->index_of($_) } $self->_key_cols;
    # _key_cols provided by consuming class

    my %row_of;

    \my @rows = $self->_rows;
    foreach my $row_r (@rows) {
        my $values = $row_r->@[@columns];
        my $key    = join( "|", $values );
        $row_of{$key} = $row_r;
    }

    return \%row_of;

}

method csv {
    state $csv = Text::CSV->new( { binary => 1 } );
    return $csv;
}

method csv_out {
    state $csv_out = Text::CSV->new( { binary => 1, eol => "\r\n" } );
    return $csv_out;
}

1;
