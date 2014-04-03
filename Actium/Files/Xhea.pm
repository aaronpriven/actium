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

sub load_adjusted {

    my ($fields_of_r , $values_of_r )= load(@_);
    my $adjusted_values_of_r = adjust_for_basetype($fields_of_r, $values_of_r);
    return ($fields_of_r, $adjusted_values_of_r);
    
}

sub adjust_for_basetype {
    
    my ($fields_of_r , $values_of_r )= (@_);
    my %adjusted_values_of;
    
    foreach my $record_name (keys %{$fields_of_r}) {
        
        foreach my $record (@{$values_of_r->{$record_name}}) {
            
            my @adjusted_record;
            
            foreach my $field_name (sort keys %{$fields_of_r->{$record_name}}) {
                
                my $idx = $fields_of_r->{$record_name}{$field_name}{idx};
                my $adjusted = $record->[$idx];
                
                my $base = $fields_of_r->{$record_name}{$field_name}{base};

                if ($base eq 'string' or $base eq 'normalizedString') {
                    $adjusted =~ s/\A\s+//;
                    $adjusted =~ s/\s+\z//;
                }
                elsif ($base eq 'boolean') {
                    if ($adjusted eq 'true') {
                        $adjusted = 1;
                    } elsif ($adjusted eq 'false') {
                        $adjusted = 0;
                    }
                }
                
                $adjusted_record[$idx] = $adjusted;
                
            }
            
            push @{$adjusted_values_of{$record_name}}, \@adjusted_record;
            
        }
        
    }
    
   #emit "Dumping adjusted values to adjusted.dump";
   #$tfolder->slurp_write( _dumped(\%adjusted_values_of), "adjusted.dump" );
   #emit_done;

    return \%adjusted_values_of;
    
}

sub load {

    my $xheafolder = shift;
    my $tfolder    = $xheafolder->subfolder('t');

    my @xhea_filenames = _get_xhea_filenames($xheafolder);

    my $pastor = XML::Pastor->new();

    my ( %fields_of, %values_of );

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

        my ( $records_of_r, $fields_of_r )
          = _records_and_fields( $tree_r, $filename );

        %fields_of = ( %fields_of, %{$fields_of_r} );

        my $newvalues_r = _load_values(
            tree       => $tree_r,
            model      => $model,
            xmlfile    => $xml,
            records_of => $records_of_r,
            fields_of  => $fields_of_r,
            filename   => $filename,
            tfolder    => $tfolder,
        );

        %values_of = ( %values_of, %{$newvalues_r} );

        emit_done;

    } ## tidy end: foreach my $filename (@xhea_filenames)

    #$tfolder->json_store_pretty( \%fields_of, 'records.json' );
    
   #emit "Dumping fields to fields.dump";
   #$tfolder->slurp_write( _dumped(\%fields_of), "fields.dump" );
   #emit_done;

   #emit "Dumping values to values.dump";
   #$tfolder->slurp_write( _dumped(\%values_of), "values.dump" );
   #emit_done;

    return ( \%fields_of, \%values_of );

} ## tidy end: sub load

sub _load_values {

    my %p = validate(
        @_,
        {   tree       => 1,
            model      => 1,
            fields_of  => 1,
            records_of => 1,
            xmlfile    => 1,
            filename   => 1,
            tfolder    => 1,
        }
    );

    my %values_of;

    for my $table_name ( keys %{ $p{tree} } ) {
        my $table_class = $p{model}->xml_item_class($table_name);
        emit "Loading $table_name from $p{filename}.xml";
        my $table = $table_class->from_xml_file( $p{xmlfile} );
        emit_done;

        #emit "Dumping $table_name objects to ${table_name}-obj.dump";
        #$p{tfolder}->slurp_write( _dumped($table), "${table_name}-obj.dump" );
        #emit_done;
        
        emit "Processing $table_name into records";

        for my $record_name ( @{ $p{records_of}{$table_name} } ) {
            
            say $record_name;

            my @field_names = sort keys %{ $p{fields_of}{$record_name} };

            my %index_of;
            $index_of{$_} = $p{fields_of}{$record_name}{$_}{idx}
              foreach @field_names;

            my @record_objs = @{ $table->$record_name }  ;

            foreach my $record_obj ( @record_objs ) {
                my @record_data;
                while ( my ( $field_name, $idx ) = each %index_of ) {
                    $record_data[$idx] = $record_obj->$field_name->__value();
                }
                push @{ $values_of{$record_name} }, \@record_data;
            }

        }
        
        #emit "Dumping $table_name values to ${table_name}-values.dump";
        #$p{tfolder}->slurp_write( _dumped(\%values_of), "${table_name}-values.dump" );
        #emit_done;

        emit_done;

    } ## tidy end: for my $table_name ( keys...)

    
    return \%values_of;

} ## tidy end: sub _load_values

sub _records_and_fields {

    # Hastus exports XML files with three levels:
    # table level (contains records)
    # record level (contains fields), and field level (contains field data).
    # So far there has been only one table per table level
    # and one type of record per record level.
    # This allows more than table and more than one kind of
    # record per table (although names of all record types must be unique
    # across all tables ).
    # However, it does not allow any variations on what the levels are.

    my ( $tree_r, $filename ) = @_;

    $filename = "$filename.xsd";

    my %fields_of;
    my %records_of;

    for my $table ( keys %{$tree_r} ) {
        emit_over "table: $table";

        if ( not $tree_r->{$table}{has_subelements} ) {
            _unexpected_croak(
                {   foundtype    => 'data field',
                    foundname    => $table,
                    expectedtype => 'table',
                    filename     => $filename,
                }
            );
        }

        my %info_of_record = %{ $tree_r->{$table}{children} };

        for my $record ( keys %info_of_record ) {
            emit_over "record: $record";

            if ( not $info_of_record{$record}{has_subelements} ) {

                _unexpected_croak(
                    {   foundtype    => 'data field',
                        foundname    => $record,
                        expectedtype => 'record',
                        filename     => $filename,
                    }
                );

            }

            push @{ $records_of{$table} }, $record;

            my %info_of_field = %{ $info_of_record{$record}{children} };

            my $field_idx = 0;

            for my $field ( sort keys %info_of_field ) {
                emit_over "field: $field";

                if ( $info_of_record{$field}{has_subelements} ) {

                    _unexpected_croak(
                        {   foundtype    => 'record',
                            foundname    => $field,
                            expectedtype => 'data field',
                            filename     => $filename,
                        }
                    );

                }

                my %info_of_field
                  = %{ $info_of_record{$record}{children}{$field} };

                my $base = $info_of_field{base} // $info_of_field{type};
                my $type = $info_of_field{type};

                for ( $base, $type ) {
                    s{\Q|http://www.w3.org/2001/XMLSchema\E\z}{};
                }

                $fields_of{$record}{$field}
                  = { base => $base, type => $type, idx => $field_idx };

                $field_idx++;
            } ## tidy end: for my $field ( sort keys...)

        } ## tidy end: for my $record ( keys %info_of_record)

    } ## tidy end: for my $table ( keys %{...})

    return \%records_of, \%fields_of;

} ## tidy end: sub _records_and_fields

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

sub _dumped {
    require Data::Dumper;
    local $Data::Dumper::Indent   = 1;
    local $Data::Dumper::Sortkeys = 1;
    return Dumper(@_);
}

sub _mydump {
    say _dumped(@_);
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

=encoding utf8

=head1 NAME

Actium::Files::Xhea - Routines for loading and processing XML Hastus exports

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use Actium::O::Folder;
 use Actium::Files::Xhea;
 
 my $folder = Actium::O::Folder->new("/path/to/folder");
 # folder should have paired xsd and xml files
 
 my ($fields_r, $values_r) = Actium::Files::Xhea::load_adjusted ($folder);
 
 my $recordname = 'place';
 my $fieldname = 'plc_identifier';
 my $idx = $fields_r->{$recordname}->{$fieldname}->idx;
 say "The first place is " .  $values_r->{$recordname}[0][$idx];
 
=head1 DESCRIPTION

Actium::Files::Xhea is a series of routines for loading XML Hastus exports and 
processing them into perl data structures. It uses L<XML::Pastor|XML::Pastor>
to process the XSD and read XML files, and so has the limitations of that 
module.

B<It ignores all attributes in all XML elements.> The only attribute 
normally found in Hastus XML exports is ' xsi:nil="true" ', which indicates
an empty element.  No practical advantage would be had by replacing the empty
string with an undefined value in the results, so an empty string is given for
such elements and this attribute, along with all others, is ignored.

=head1 SUBROUTINES 

No subroutines are exported. Use the fully qualified name to invoke them.
(e.g., "Actium::Files::Xhea::load_adjusted($folder)") 

=over

=item B<load(I<folderobj>)>

This routine takes a folder object (such as an 
Actium::O::Folder or Actium::O::Folders::Signup object ), looks for paired
xml and xsd files in that folder, and returns two structs: one contains
information about the records and fields, and the ohter contains the values
from the file.

The XML and XSD structure is somewhat limited and assumes the sort of XML 
typically exported from Hastus. 

Hastus exports XML files with three levels:
table level (contains records), record level (contains fields), 
and field level (contains field data).

This routine allows multiple tables per file (which hasn't happened) and 
multiple record types per file (which also hasn't happened).  
It does not allow any variations of
the levels (so there can't be nested record types or anything like that).
Names of all record types across all XML files loaded much be unique. 

 my ($fields_r, $values_r) = Actium::Files::Xhea::load($folder);

The structure of $fields_r will be:
 
 $fields_r =
   { I<recordname> => 
      { I<fieldname> => 
          {
          base => I<basetype>,
          type => I<type>,
          idx => I<idx>,
          },
       I<fieldname> => I<etc...>
      },
    I<recordname> => I<etc...>
   };
      
It contains a hash whose keys are the record names. The values of that hash
are other hashes whose keys are fieldnames and whose values are a third hash. 
That hash has the literal keys 'base', 'type', and 'idx.' 

The 'base' and 'type' entries 
both refer to the XSD data type. The 'type' can be either an XSD built-in type 
such as string, int, date, etc., or a custom XML 
simple type definition from the XSD.
The 'base' is always an XSD built-in type. 
If 'type' is an XSD built-in type, then 'base' and 'type' are identical.

The 'idx' entry provides an offset into the array of field data for this field.

The structure of $values_r will be:

 $values_r = 
  { I<recordname> => 
      [
        [ I<data> , I<data> , I<data> ... ], # first record
        [ I<data> , I<data> , I<data> ... ], # second record
        I<etc...>
      ],
    I<recordname> => 
      I<etc...>
  }
      
It contains a hash whose keys are the record names. The values of that hash
are arrays representing individual records. Each record is an array of scalars,
each of which is the data from a field. The 'idx' entry in the $field_r 
struct says which field corresponds to each entry in the record.

=item B<adjust_for_basetype(I<$fields_r>, I<$values_r>)>

This routine takes the result of load() and adjusts the resulting data to
better match expectations of someone using Perl.

At the moment it does only the following:

=over

=item 1

It removes leading and trailing whitespaces from fields whose base type is
'string' or 'normalizedString'.

=item 2

For fields whose base type is 'boolean', it changes the values 'true' to 1 
and 'false' to 0.

=back

In future this would be the place to decode base64Binary and hexBinary types,
or possibly other adjustments should that prove necessary.

=item B<load_adjusted(I<folderobj>)>

Equivalent to adjust_for_basetype(load(...))

=back

=head1 DIAGNOSTICS

=over

=item Unexpected data field "field" where record expected in $filename

=item Unexpected data field "field" where table expected in $filename

=item Unexpected record "record" where data field expected in $filename

While processing an XSD file, a complex type with elements was found when a 
type with no elements was expected, or vice versa. 
The program doesn't know how to 
deal with this more complicated schema.

=item No xsd / xml file pairs found when trying to import xhea files

No pairs of XSD and XML files were found in the appropriate folders.
Check that the folder is correct and that the files are present.

=back

=head1 DEPENDENCIES

=over 

=item *

Actium::Preamble

=item *

Actium::Term

=item *

Params::Validate

=item *

Actium::Util

=item *

List::MoreUtils

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2014

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
