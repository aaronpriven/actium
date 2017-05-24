package Actium::O::Sked::Collection 0.014;

use Actium ('class_nomod');

use Actium::O::Sked;
use Actium::Sorting::Skeds ('skedsort');

use Actium::Excel;

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
    my @skedids   = $self->_sked_transitinfo_ids_of_lg($linegroup)->@*;
    return sort @skedids;
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

##################
##### OUTPUT ######
###################

method output_skeds_all ( :$signup!  , :$subfolder_name = 's') {

    my $skeds_r = $self->skeds_r;

    my $skeds_folder = $signup->subfolder($subfolder_name);

    $skeds_folder->store( $self, 'skeds.storable' );
    my $xlsxfolder = $skeds_folder->subfolder('xlsx_s');
    $xlsxfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'xlsx',
        EXTENSION => 'xlsx',
    );

    $self->output_skeds_xlsx( skeds_folder => $skeds_folder );

    my $dumpfolder = $skeds_folder->subfolder('dump');
    $dumpfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'dump',
        EXTENSION => 'dump',
    );

    my $spacedfolder = $skeds_folder->subfolder('spaced');
    $spacedfolder->write_files_with_method(
        OBJECTS   => $skeds_r,
        METHOD    => 'spaced',
        EXTENSION => 'txt',
    );

    Actium::O::Sked->write_prehistorics( $skeds_r,
        $skeds_folder->subfolder('prehistoric') );

} ## tidy end: sub METHOD1

method output_skeds_xlsx (:$skeds_folder!) {

    my $cry = cry("Writing place xlsx schedules");

    #my $stop_xlsx_folder  = $skeds_folder->subfolder('xlsx_s');
    my $place_xlsx_folder = $skeds_folder->subfolder('xlsx_p');

    my @linegroups = u::sortbyline $self->linegroups;

    foreach my $linegroup (@linegroups) {

        $cry->over("$linegroup ");

    #        my $stop_workbook_fh
    #          = $stop_xlsx_folder->open_write_binary("$linegroup.xlsx");
    #        my $stop_workbook    = Excel::Writer::XLSX->new($stop_workbook_fh);
    #        my $stop_text_format = $stop_workbook->actium_text_format;

        my $place_workbook_fh
          = $place_xlsx_folder->open_write_binary( $linegroup . "_p.xlsx" );
        my $place_workbook    = Excel::Writer::XLSX->new($place_workbook_fh);
        my $place_text_format = $place_workbook->actium_text_format;

        foreach my $sked ( $self->skeds_of_lg($linegroup) ) {
#            $sked->add_stop_xlsx_sheet( workbook => $stop_workbook, format => $stop_text_format );
            $sked->add_place_xlsx_sheet( $place_workbook, $place_text_format );
        }

        #        $stop_workbook->close;
        $place_workbook->close;

    } ## tidy end: foreach my $linegroup (@linegroups)

    $cry->over($EMPTY_STR);
    $cry->done;

    return;

} ## tidy end: sub METHOD2

u::immut;

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

