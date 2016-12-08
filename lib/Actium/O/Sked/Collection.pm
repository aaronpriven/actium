package Actium::O::Sked::Collection 0.012;

use Actium::Moose;

use Actium::O::Sked;
use Actium::Sorting::Skeds ('skedsort');

around BUILDARGS => sub {
    my $orig  = shift;
    my $class = shift;

    # if they're all objects, treat them as though they were skeds
    if ( u::all { u::blessed($_) } @_ ) {
        return $class->$orig( skeds => \@_ );
    }

    # otherwise, normal
    return $class->$orig(@_);

};

has skeds_r => (
    is       => 'ro',
    writer   => '_set_skeds_r',
    isa      => 'ArrayRef[Skedlike]',
    traits   => ['Array'],
    required => 1,
    init_arg => 'skeds',
    handles  => { skeds => 'elements' },
);

sub BUILD {
    my $self  = shift;
    my @skeds = skedsort( $self->skeds );
    
    $self->_set_skeds_r( \@skeds );
}

has '_sked_obj_by_id_r' => (
    is      => 'bare',
    isa     => 'HashRef[Skedlike]',
    traits  => ['Hash'],
    builder => '_build_sked_obj_by_id_r',
    lazy    => 1,
    handles => {
        _set_sked_obj => 'set',
        sked_obj      => 'get',
        #ids => 'keys',
    },
);

sub _build_sked_obj_by_id_r {
    my $self  = shift;
    my @skeds = $self->skeds;
    my %sked_obj_by_id;
    foreach my $sked (@skeds) {
        my $id = $sked->id;
        $sked_obj_by_id{$id}->@* = $sked;
    }
    return \%sked_obj_by_id;
}

has '_sked_transitinfo_ids_of_lg' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    traits  => ['Hash'],
    builder => '_build_sked_transitinfo_ids_of_lg',
    lazy    => 1,
    handles => { _sked_transitinfo_ids_of_lg => 'get' },
);

sub _build_sked_transitinfo_ids_of_lg {
    my $self  = shift;
    my @skeds = $self->skeds;
    my %sked_transitinfo_ids_of_lg;
    foreach my $sked (@skeds) {

        my $t_id      = $sked->transitinfo_id;
        my $linegroup = $sked->linegroup;
        push $sked_transitinfo_ids_of_lg{$linegroup}->@*, $t_id;

    }

    return \%sked_transitinfo_ids_of_lg;

}

sub sked_transitinfo_ids_of_lg {
    my $self      = shift;
    my $linegroup = shift;
    my @skedids   = $self->_sked_transitinfo_ids_of_lg($linegroup)->@*;
    return sort @skedids;
}

has '_sked_ids_of_lg' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    traits  => ['Hash'],
    builder => '_build_sked_ids_of_lg',
    lazy    => 1,
    handles => { _sked_ids_of_lg => 'get' },
);

sub _build_sked_ids_of_lg {
    my $self  = shift;
    my @skeds = $self->skeds;
    my %sked_ids_of_lg;
    foreach my $sked (@skeds) {

        my $id        = $sked->id;
        my $linegroup = $sked->linegroup;
        push $sked_ids_of_lg{$linegroup}->@*, $id;

    }

    return \%sked_ids_of_lg;

}

sub sked_ids_of_lg {
    my $self      = shift;
    my $linegroup = shift;
    my @skedids   = $self->_sked_ids_of_lg($linegroup)->@*;
    return @skedids;
}

#sub add_sked {
#    my $self = shift;
#    my @objs = shift;
#    $self->_set_sked_obj( map { $_->id, $_ } @objs );
#}

sub load_storable {
    my $class           = shift;
    my $storable_folder = shift;
    return $storable_folder->retrieve('skeds.storable');
}

sub write_tabxchange {

    my $self = shift;

    my %params = u::validate(
        @_,
        {   tabfolder    => 1,
            commonfolder => 1,
            actiumdb     => 1,
        }
    );

    my $destination_code
      = Actium::O::DestinationCode->load( $params{commonfolder} );
      
    my @skeds = grep { $_->linegroup !~ /^(?:BS|4\d\d)/ } $self->skeds;

    $params{tabfolder}->write_files_with_method(
        OBJECTS         => \@skeds ,
        METHOD          => 'tabxchange',
        EXTENSION       => 'tab',
        FILENAME_METHOD => 'transitinfo_id',
        ARGS            => [
            destinationcode => $destination_code,
            actiumdb        => $params{actiumdb},
            collection      => $self,
        ],
    );

    $destination_code->store;

} ## tidy end: sub write_tabxchange

##################
##### OUTPUT ######
###################

sub _output_skeds_all {

    my $self    = shift;
    my $skeds_r = $self->skeds_r;

    my $signup       = shift;
    my $skeds_folder = $signup->subfolder('s');

    $skeds_folder->store( $self, 'skeds.storable' );

    my $dumpfolder = $skeds_folder->subfolder('dump');
    $dumpfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'dump',
        EXTENSION => 'dump',
    );

    my $xlsxfolder = $skeds_folder->subfolder('xlsx');
    $xlsxfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'xlsx',
        EXTENSION => 'xlsx',
    );

    my $spacedfolder = $skeds_folder->subfolder('spaced');
    $spacedfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'spaced',
        EXTENSION => 'txt',
    );

    Actium::O::Sked->write_prehistorics( $skeds_r,
        $skeds_folder->subfolder('prehistoric') );

} ## tidy end: sub _output_skeds_all

u::immut;

__END__
