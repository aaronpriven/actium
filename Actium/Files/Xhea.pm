# /Actium/Files/Xhea.pm
#
# Using XML::Pastor, reads XML Hastus Exports for Actium files
# (exports from Hastus) and imports them into Actium.
#

# Subversion: $Id$

package Actium::Files::Xhea 0.003;

use Actium::Preamble;
use Actium::Term;

use Actium::Util('file_ext');

use XML::Pastor;

const my $prefix => 'Actium::O::Files::Xhea';

sub load_into_objs {

    my $xheafolder     = shift;
    my @xhea_filenames = _get_xhea_filenames($xheafolder);

    my $pastor = XML::Pastor->new();

    my %results;

    foreach my $filename (@xhea_filenames) {

        emit "Processing $filename";

        emit "Generating classes from XSD file";

        my $xsd       = $xheafolder->make_filespec("$filename.xsd");
        my $xml       = $xheafolder->make_filespec("$filename.xml");
        my $newprefix = $prefix . "::$filename";

        $pastor->generate(
            mode         => 'eval',
            schema       => $xsd,
            class_prefix => $newprefix,
        );

        emit_done;

        my $model = ( $newprefix . '::Pastor::Meta' )->Model;

        my %element_obj_of = %{$model->element};
        
        emit "Building element tree";
        
        my @tree_display;
        
        while ( my ( $top_element, $top_element_obj ) = each %element_obj_of ) {
            
            my $top_class = $model->xml_item_class($top_element);
            
            
                    #         emit "Loading $top_class from file $filename.xml";
        # my $xml_data = $top_class->from_xml_file($xml);
        # emit_done;

            my $top_type = $top_element_obj->type;

            my %type_of_subelement = _subelements( $model, $top_type );
            
            push @tree_display, "$top_element: $top_type";

            while ( my ( $container, $containertype )
                = each %type_of_subelement )
            {

                push @tree_display, "    $container: $containertype";

                my %type_of_simple = _subelements( $model, $containertype );

                while ( my ( $simple, $simpletype ) = each %type_of_simple ) {
                    push @tree_display, "        $simple: $simpletype";
                }

            }

        } ## tidy end: while ( my ( $top_element...))

        emit_text jn(@tree_display);

        emit_done;



        emit_done;

    } ## tidy end: foreach my $filename (@xhea_filenames)

    return %results;
} ## tidy end: sub load_into_objs

sub _subelements {

    my ( $model, $type ) = @_;
    my $elementInfo = $model->type->{$type}->elementInfo;
    
    my %type_of_subelement;
    
    while ( my ($subelement, $subelementinfo) = each %{$elementInfo} ) {
        
        $type_of_subelement{$subelement} = $subelementinfo->type;
    }

    return %type_of_subelement;

}

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

    croak "No xsd/xml file pairs found when trying to import xhea files"
      unless @xhea_filenames;

    return @xhea_filenames;

} ## tidy end: sub _get_xhea_filenames

1;
