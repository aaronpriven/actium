package Actium::O::DestinationCode 0.012;

use Actium::Moose;

const my $JSON_FILE => 'destcodes.json';

has '_destination_code_of_r' => (
    is       => 'ro',
    init_arg => 'destination_code_of',
    isa      => 'Skedlike',
    traits   => ['Hash'],
    default  => sub { {} },
    handles  => {
        _set_code_of => 'set',
        _get_code_of => 'get',
        _codes       => 'values',
    },
);

has '_folder' => (
    is       => 'ro',
    isa      => 'Actium::O::Folder',
    init_arg => 'folder',
);

sub load {
    my $class        = shift;
    my $commonfolder = shift;

    my %destination_code_of = $commonfolder->json_retrieve($JSON_FILE)->%*;

    return $class->new(
        destination_code_of => \%destination_code_of,
        folder              => $commonfolder,
    );

}

sub store {
    my $self = shift;

    \my %destination_code_of = $self->_destination_code_of_r;
    my $folder = $self->folder;

    my $filespec = $folder->make_filespec($JSON_FILE);

    rename $filespec, "$filespec.bak";

    $folder->json_store_pretty( \%destination_code_of, $JSON_FILE );

}

sub code_of {

    my $self = shift;
    my $dest = shift;

    my $code = $self->_get_code_of($dest);

    if ( not defined $code ) {
        $code = $self->highest_code;
        $code++;    # magic increment
        _set_code_of( $dest => $code );
    }

    return $code;

}

sub _highest_code {
    my $self = shift;
    \my %destination_code_of = $self->_destination_code_of_r;

    my @sorted_codes
      = sort { length($b) <=> length($a) || $b cmp $a } $self->_codes;

    return $sorted_codes[0];

}

1;
__END__