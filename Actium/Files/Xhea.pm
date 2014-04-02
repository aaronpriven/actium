# /Actium/Files/Xhea.pm
#
# Using XML::Pastor, reads XML Hastus Exports for Actium files
# (exports from Hastus) and imports them into Actium.
#

# Subversion: $Id$

package Actium::Files::Xhea 0.003;

use Actium::Preamble;
use Actium::Term;

use Params::Validate(':all');
use Actium::Util('file_ext');
use List::MoreUtils('pairwise');

use XML::Pastor;

const my $prefix => 'Actium::O::Files::Xhea';

sub load_into_objs {

    my $xheafolder     = shift;
    my @xhea_filenames = _get_xhea_filenames($xheafolder);

    my $pastor = XML::Pastor->new();

    my %results;

    foreach my $filename (@xhea_filenames) {

        emit "Processing $filename";

        emit "Generating classes from XSD";

        my $xsd       = $xheafolder->make_filespec("$filename.xsd");
        my $xml       = $xheafolder->make_filespec("$filename.xml");
        my $newprefix = $prefix . "::$filename";

        $pastor->generate(
            mode         => 'eval',
            schema       => $xsd,
            class_prefix => $newprefix,
        );

        emit_done;    # generating classes

        my $model  = ( $newprefix . '::Pastor::Meta' )->Model;
        my $tree_r = _build_tree($model);

        _check_tree( $tree_r, $filename );

        %results = (
            %results,
            _get_values(
                xmlfile  => $xml,
                filename => $filename,
                model    => $model,
                tree     => $tree_r
            )
        );

        emit_done;

    } ## tidy end: foreach my $filename (@xhea_filenames)

    return %results;
} ## tidy end: sub load_into_objs

sub _check_tree {
    my ( $tree_r, $filename ) = @_;

    $filename = "$filename.xsd";

    for my $table ( keys %{$tree_r} ) {

        if ( not $tree_r->{$table}{has_subelements} ) {
            _unexpected_croak(
                {   foundtype    => 'data field',
                    foundname    => $table,
                    expectedtype => 'table',
                    filename     => $filename,
                }
            );

            my %info_of_record = %{ $tree_r->{children} };
            for my $record ( keys %info_of_record ) {

                if ( not $info_of_record{$record}{has_subelements} ) {

                    _unexpected_croak(
                        {   foundtype    => 'data field',
                            foundname    => $record,
                            expectedtype => 'record',
                            filename     => $filename,
                        }
                    );

                    croak qq[Unexpected data field "$record" ]
                      . qq[where record expected in $filename];
                }

                my %info_of_field = %{ $info_of_record{children} };

                for my $field ( keys %info_of_field ) {

                    if ( $info_of_record{$field}{has_subelements} ) {

                        _unexpected_croak(
                            {   foundtype    => 'record',
                                foundname    => $field,
                                expectedtype => 'field',
                                filename     => $filename,
                            }
                        );

                    }

                }

            } ## tidy end: for my $record ( keys %info_of_record)

        } ## tidy end: if ( not $tree_r->{$table...})

        return;

    } ## tidy end: for my $table ( keys %{...})

}

sub _unexpected_croak {

    my %p = validate(
        @_,
        {   foundtype    => 1,
            foundname    => 1,
            expectedtype => 1,
            filename     => 1,
        }
    );

    croak qq[Unexpected $p{foundtype} "$p{foundname}" ]
      . qq[where $p{expectedtype} expected in $p{filename}];
}

#sub _get_values {
#
#    # Hastus exports XML files with three levels:
#    # table level (contains records)
#    # record level (contains fields), and field level (contains field data).
#    # So far there has been only one table per table level
#    # and one type of record per record level.
#    # This allows more than table and more than one kind of
#    # record per table (although names of all record types must be unique
#    # across all xml files read).
#    # However, it does not allow any variations on what the levels are.
#
#    my %p = validate(
#        @_,
#        {   tree     => { type => HASHREF },
#            model    => { type => HASHREF },
#            xmlfile  => { type => SCALAR },
#            filename => { type => SCALAR },
#        }
#    );
#
#    my %tree = %{ $p{tree} };
#
#    my %results;
#
#    foreach my $table ( keys %tree ) {         # normally juse one
#        my $table_class    = $p{model}->xml_item_class($table);
#        my %info_of_record = %{ $tree{children} };
#
#        my $value_tree = $table_class->from_xml_file( $p{xmlfile} );
#
#        my %index_of_field;
#        foreach my $record ( keys %info_of_record ) {
#
#            if ( not exists $index_of_field{$record} ) {
#
#               if ($info_of_record{has_subelements}) {
#                croak qq[Unexpected data field "$record" ] . qq[where record expected in $p{filename}.xsd];
#               }
#
#               $index_of_field{$record} = {};
#
#
#                my ( @fields, @basetypes );
#                my %info_of_field = %{$info_of_record{$field}{children} };
#
#                foreach
#                  my $field ( keys %info_of_field )
#                {
#
#
#
#
#                  }
#
#
#
#            }
#
#        }
#
#    }
#
#    return %results;
#
#} ## tidy end: sub _get_values

sub _mydump {
    require Data::Dumper;
    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Sortkeys = 1;
    say Dumper (@_);
}

sub _build_tree {

    my $model = shift;

    emit " Building element tree ";

    my %element_obj_of = %{ $model->element };

    my ( @queue, %tree );

    foreach my $element ( keys %element_obj_of ) {
        push @queue, [ $element, $element_obj_of{$element}, \%tree ];
    }

    while (@queue) {
        my ( $element, $element_obj, $parent_hr ) = @{ shift @queue };

        my $type = $element_obj->type;
        my ( $type_obj, $base, @subelements );

        if ( exists $model->type->{$type} ) {
            $type_obj = $model->type->{$type};
            $base     = $type_obj->base;         # MAY BE UNDEFINED

            if ( $type_obj->contentType eq 'complex' ) {
                @subelements = $type_obj->effectiveElements;
            }
        }

        if (@subelements) {
            my $children_hr = {};
            $parent_hr->{$element} = {
                has_subelements => 1,
                type            => $type,
                children        => $children_hr
            };

            my %elementInfo_of = %{ $type_obj->effectiveElementInfo };

            foreach my $subelement ( keys %elementInfo_of ) {
                push @queue,
                  [ $subelement, $elementInfo_of{$subelement}, $children_hr ];
            }

        }
        else {
            $parent_hr->{$element} = { has_subelements => 0, type => $type };
            $parent_hr->{$element}{base} = $base if $base;
        }

    } ## tidy end: while (@queue)

    emit_done;

    return \%tree;

} ## tidy end: sub _build_tree

sub _get_xhea_filenames {

    my $xheafolder = shift;

    my @xmlfiles = $xheafolder->glob_files('*.xml');
    my @xsdfiles = $xheafolder->glob_files('*.xsd');

    foreach ( @xmlfiles, @xsdfiles ) {
        ( $_, undef ) = file_ext($_);
    }

    my @xhea_filenames;

    foreach my $filename (@xmlfiles) {
        push @xhea_filenames, $filename
          if in( $filename, @xsdfiles );
    }

    # so @xhea_filenames contains filename piece of all filenames where
    # there is both an .xsd and .xml file

    croak " No xsd / xml file pairs found when trying to import xhea files "
      unless @xhea_filenames;

    return @xhea_filenames;

} ## tidy end: sub _get_xhea_filenames

1;

__END__

#sub _subelements {
#
#    my ( $model, $type ) = @_;
#    my $elementInfo = $model->type->{$type}->elementInfo;
#
#    my %type_of_subelement;
#
#    while ( my ( $subelement, $subelementinfo ) = each %{$elementInfo} ) {
#
#        $type_of_subelement{$subelement} = $subelementinfo->type;
#    }
#
#    return %type_of_subelement;
#
#}

#
#        my $value_of_element_cr = sub {
#
#            my ($element_obj) = shift;
#            my $type          = $element_obj->type;
#            my $type_obj      = $model->type->{$type};
#            my $base          = $type_obj->base;
#
#            my $content;
#            if ( $type_obj->contentType eq 'complex' ) {
#
#                my %elementinfo_of = $type_obj->effectiveElementInfo;
#
#                while ( my ( $element, $element_obj ) = each %elementinfo_of ) {
#                    $content = __SUB__->( $element_obj );
#                }
#
#            }
#            else {
#                $content = 'simple - real data to go here';
#            }
#
#            return { type => $type, base => $base, content => $content };
#
#        };
#
#        while ( my ( $top_element, $top_element_obj ) = each %element_obj_of ) {
#            my $value = _value_of_element( $model, $top_element_obj );
#            push @tree, { $top_element => $value };
#        }

#        my @tree_display;
#        while ( my ( $top_element, $top_element_obj ) = each %element_obj_of ) {
#
#            my $top_class = $model->xml_item_class($top_element);
#
#            my $top_type = $top_element_obj->type;
#
#            my %type_of_subelement = _subelements( $model, $top_type );
#
#            push @tree_display, "$top_element : $top_type ";
#
#            while ( my ( $container, $containertype )
#                = each %type_of_subelement )
#            {
#
#                push @tree_display, " $container : $containertype ";
#
#                my %type_of_simple = _subelements( $model, $containertype );
#
#                while ( my ( $simple, $simpletype ) = each %type_of_simple ) {
#                    push @tree_display, " $simple : $simpletype ";
#                }
#
#            }
#
#        } ## tidy end: while ( my ( $top_element...))
#        emit_text jn(@tree_display);
