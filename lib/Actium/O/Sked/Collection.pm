package Actium::O::Sked::Collection 0.014;

use Actium ('class');

use Actium::O::Sked;
use Actium::Sorting::Skeds ('skedsort');

use Actium::Excel;

use MooseX::Storage;

with Storage(
    traits   => ['OnlyWhenBuilt'],
    'format' => 'Storable',
    io       => 'File',
);

const my $PHYLUM => 's';

has skeds_r => (
    is       => 'ro',
    writer   => '_set_skeds_r',
    isa      => 'ArrayRef[Skedlike]',
    traits   => ['Array'],
    required => 1,
    init_arg => 'skeds',
    handles  => { skeds => 'elements' },
);

has name => (
    is       => 'rwp',
    isa      => 'Str',
    required => 1,
    traits   => ['DoNotSerialize'],
);

has signup => (
    is       => 'rwp',
    isa      => 'Actium::O::Folders::Signup',
    required => 1,
    traits   => ['DoNotSerialize']
);

sub BUILD {
    my $self  = shift;
    my @skeds = skedsort( $self->skeds );
    return $self->_set_skeds_r( \@skeds );
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
        _sked_ids     => 'keys',
        _has_sked_id  => 'exists',
    },
);

sub _build_sked_obj_by_id_r {
    my $self  = shift;
    my @skeds = $self->skeds;
    my %sked_obj_by_id;
    foreach my $sked (@skeds) {
        my $id = $sked->id;
        $sked_obj_by_id{$id} = $sked;
    }

    return \%sked_obj_by_id;
}

# Transitinfo IDs used by tabxchange

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
    my @skedids   = sort ( $self->_sked_transitinfo_ids_of_lg($linegroup)->@* );
    return @skedids;
}

has '_sked_ids_of_lg' => (
    is      => 'bare',
    isa     => 'HashRef[ArrayRef[Str]]',
    traits  => ['Hash'],
    builder => '_build_sked_ids_of_lg',
    lazy    => 1,
    handles => {
        _sked_ids_of_lg => 'get',
        linegroups      => 'keys',
    },
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

sub skeds_of_lg {
    my $self      = shift;
    my $linegroup = shift;
    my @skeds = map { $self->sked_obj($_) } $self->sked_ids_of_lg($linegroup);
    return @skeds;
}

##################
##### INPUT ######
##################

method load_storable ($class: :$signup, :$collection) {

    my $folder
      = $signup->folder( phylum => $PHYLUM, collection => $collection );

    my $self = $class->load( $folder->make_filespec('skeds_storable') );
    $self->_set_signup($signup);
    $self->_set_name($collection);
    return $self;

}

method load_xlsx ( $class: :$signup, :$collection ) {

    my $folder = $signup->folder(
        phylum     => $PHYLUM,
        collection => $collection,
        format     => 'skeds'
    );

    my @xlsx_files = $folder->glob_plain_files('*.xlsx');

    my @skeds;
    foreach my $file (@xlsx_files) {
        my $sked = Actium::O::Sked->new_from_xlsx( file => $file );
        push @skeds, $sked;
    }

    return $class->new(
        skeds  => \@skeds,
        name   => $collection,
        signup => $signup
    );

} ## tidy end: method load_xlsx

#######################
##### TRANSFORMATION
#######################

method finalize_skeds ( $class: :$signup ) {

    my $received_collection
      = $class->load_storable( signup => $signup, collection => 'received' );

    my $exception_collection
      = $class->load_xlsx( signup => $signup, collection => 'exceptions' );

    my @finalized_skeds;

    my @ids
      = uniq( $received_collection->_sked_ids,
        $exception_collection->_sked_ids );

    for my $id (@ids) {
        if ( $exception_collection->_has_sked_id($id) ) {
            push @finalized_skeds, $exception_collection->sked_obj($id);
        }
        else {
            push @finalized_skeds, $received_collection->sked_obj($id);
        }
    }

    my $finalized_collection = $class->new(
        skeds  => \@finalized_skeds,
        name   => 'final',
        signup => $signup,
    );

    $finalized_collection->output_skeds_all;

} ## tidy end: method finalize_skeds

###################
##### OUTPUT ######
###################

sub write_tabxchange {

    my $self = shift;

    my %params = u::validate(
        @_,
        {   tabfolder    => 1,
            commonfolder => 1,
            actiumdb     => 1,
        },
    );

    my $destination_code
      = Actium::O::DestinationCode->load( $params{commonfolder} );

    my @skeds = grep { $_->linegroup !~ /^(?:BS|4\d\d)/ax } $self->skeds;

    $params{tabfolder}->write_files_with_method(
        OBJECTS         => \@skeds,
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

method folder ($the_format) {
    # calling it $format yields syntax formatting errors
    # This can only be used for output folders since it depends on
    # object attributes
    my $signup     = $self->signup;
    my $collection = $self->name;
    return $signup->folder(
        phylum     => $PHYLUM,
        collection => $collection,
        format     => $the_format,
    );
}

method output_skeds_dump ( :$signup! ) {

    my $skeds_r = $self->skeds_r;

    my $folder = $self->folder('dumped');

    $folder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'dump',
        EXTENSION => 'dump',
    );

}

method output_skeds_all {

    my $skeds_r = $self->skeds_r;
    my $signup  = $self->signup;

    $self->output_skeds_storable;

    my $skeds_folder = $self->folder('skeds');

    $skeds_folder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'xlsx',
        EXTENSION => 'xlsx',
    );

    $self->output_skeds_place;

    $self->output_skeds_dump;

    my $spacedfolder = $self->folder('spaced');
    $spacedfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'spaced',
        EXTENSION => 'txt',
    );

    my $prehistoricfolder = $self->folder('prehistoric');

    Actium::O::Sked->write_prehistorics( $skeds_r, $prehistoricfolder );

} ## tidy end: method output_skeds_all

method output_skeds_storable (:$signup!) {
    my $filespec = $self->folder->make_filespec('skeds.storable');
    $self->store($filespec);
}

method output_skeds_place {

    my $cry = cry('Writing place xlsx schedules');

    #my $stop_xlsx_folder  = $skeds_folder->subfolder('xlsx_s');
    #my $place_xlsx_folder = $skeds_folder->subfolder('xlsx_p');
    my $place_xlsx_folder = $self->folder('place');

    my @linegroups = u::sortbyline $self->linegroups;

    foreach my $linegroup (@linegroups) {

        $cry->over("$linegroup ");

    #        my $stop_workbook_fh
    #          = $stop_xlsx_folder->open_write_binary("$linegroup.xlsx");
    #        my $stop_workbook    = Excel::Writer::XLSX->new($stop_workbook_fh);
    #        my $stop_text_format = $stop_workbook->actium_text_format;

        my $place_workbook_fh
          = $place_xlsx_folder->open_write_binary( $linegroup . '_p.xlsx' );
        my $place_workbook    = Excel::Writer::XLSX->new($place_workbook_fh);
        my $place_text_format = $place_workbook->actium_text_format;

        foreach my $sked ( $self->skeds_of_lg($linegroup) ) {
#            $sked->add_stop_xlsx_sheet( workbook => $stop_workbook, format => $stop_text_format );
            $sked->add_place_xlsx_sheet(
                workbook => $place_workbook,
                format   => $place_text_format,
            );
        }

        #        $stop_workbook->close;
        $place_workbook->close;

    } ## tidy end: foreach my $linegroup (@linegroups)

    $cry->over($EMPTY);
    $cry->done;

    return;

} ## tidy end: method output_skeds_place

u::immut;

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

