# /Actium/Files/Hxml2tsv.pm
#
# Takes XML files exported from Hastus and turns them into tab-delimited files
# that are just like the Thea files.

# Subversion: $Id$

package Actium::Files::Hxml2tsv 0.003;

use Actium::Preamble;
use XML::Parser;

my %xml_file_info = (
    stops => {
        old_fieldname_of => {
            qw(
              loca_latitude        stp_avl_lat
              loca_longitude       stp_avl_long
              stp_is_inservice     stp_in_service
              )
        },
        record_element => 'stop',
    },
);

use constant { OUTSIDE_RECORD => 0, INSIDE_RECORD => 1, INSIDE_FIELD => 2 };

sub convert_xml_in_folder {

    my $theafolder = shift;

    my @xmlfiles = $theafolder->glob_files('*.xml');

    croak "No files found" unless @xmlfiles;

    my %results;

    foreach my $xmlfile (@xmlfiles) {
        my ( $filenamepart, $ext ) = Actium::Util::file_ext($xmlfile);

        my $xml_file_info = $xml_file_info{$filenamepart};
        next unless $xml_file_info;

        my ( $headers_r, $records_r )
          = _parse_xml_file( $xmlfile, $xml_file_info );

        $results{$filenamepart} = {
            headers => $headers_r,
            records => $records_r,
        };

    }

    return %results;
} ## tidy end: sub convert_xml

sub _parse_xml_file {

    my $xmlfile        = shift;
    my $xml_file_info  = shift;
    my $record_element = $xml_file_info->{record_element};
    # the element that contains the whole record -- 'stop' for stops.xml

    my %old_fieldname_of = %{ $xml_file_info->{old_fieldname_of} };
    # gives old THEA field name for new XML field name

    my $where = OUTSIDE_RECORD;

    my ( $current_fieldnum, $current_element, $data_buffer );
    my ( %fieldnum_of_element, @fields, @this_record, @records );

=begin comment


This assumes that the structure is

  <tag for a record>
      <tag for a field>data</tag for a field>
      <tag for an empty field />
  </tag for a record>
  
Basically, CSV without the commas. It will give an error if it 
receives anything outside the tag for a record, or if it has any nested 
tags for fields. It's dumb. But then, so is this whole schema.

Here is the list of events that are noted. 

Start of $record_element - mark the beginning of a record. 

Start of any other element - ignored unless inside a record. 
inside a record - if have never seen this element, add its fieldname
to the end of the list, and keep track of what column this should be in.

CHARS - Add chars to $data_buffer

End of element other than $record_element - only if inside a record, 
add $data_buffer to the appropriate column

End of $record_element - mark end of record.

=end comment

=cut

    my $record_start_handler = sub {

        my ( $expat, $element ) = @_;

        if ( $where != OUTSIDE_RECORD ) {
            my $err = "Unexpected <$record_element> start tag [$where]";
            _error_tag(
                found => $element,
                expat => $expat,
                file  => $xmlfile,
            );
        }

        $where = INSIDE_RECORD;
        undef $current_fieldnum;
        return;

    };

    my $record_end_handler = sub {
        my ( $expat, $element ) = @_;

        if ( $where == INSIDE_FIELD ) {
            _error_tag(
                found           => $element,
                found_is_end    => 1,
                expected        => $current_element,
                expected_is_end => 1,
                file            => $xmlfile,
                expat           => $expat,
            );
        }
        elsif ( $where == OUTSIDE_RECORD ) {
            _error_tag(
                found        => $element,
                found_is_end => 1,
                expected     => $record_element,
                file         => $xmlfile,
                expat        => $expat,
            );
        }
        
        if ( $data_buffer ne $EMPTY_STR and $data_buffer !~ /\A\s+\z/ ) {
            croak "Character data [$data_buffer] found inside $record_element element at "
              . _error_loc( $expat, $xmlfile );
        }

        # save record and prepare for the next one
        push @records, [@this_record];
        @this_record = ();
        $where       = OUTSIDE_RECORD;
        return;

    };

    my $start_of_tag_handler = sub {

        goto &{$record_start_handler} if $_[1] eq $record_element;

        return if $where == OUTSIDE_RECORD;
        # ignore tags if outside the record

        my $expat   = shift;
        my $element = shift;

        if ( $where == INSIDE_FIELD ) {
            _error_tag(
                found           => $element,
                expected        => $current_element,
                expected_is_end => 1,
                expat           => $expat,
                file            => $xmlfile
            );
        }

        if ( not exists $fieldnum_of_element{$element} ) {
            # haven't ever seen this element before
            my $field = $old_fieldname_of{$element} // $element;
            push @fields, $field;
            $fieldnum_of_element{$element} = $#fields;

        }

        $current_fieldnum = $fieldnum_of_element{$element};
        $current_element  = $element;
        $where            = INSIDE_FIELD;
        $data_buffer      = $EMPTY_STR;

        # at the moment, all attributes are ignored.
        # the only attribute that's currently given is
        # xsi:nil, and this just indicates an empty field --
        # which is just as indicated by there being no data...
        # (No difference between null and empty as far as I can tell)

        return;

    };

    my $end_of_tag_handler = sub {

        goto &{$record_end_handler} if $_[1] eq $record_element;

        my $expat   = shift;
        my $element = shift;

        if ( $where == INSIDE_RECORD ) {
            # found end before start
            _error_tag(
                found        => $element,
                found_is_end => 1,
                expected     => $element,
                file         => $xmlfile,
                expat        => $expat
            );
        }

        return if $where == OUTSIDE_RECORD;
        # ignore tags if outside a record

        if ( $current_element ne $element ) {
            # found wrong element
            _error_tag(
                found           => $element,
                found_is_end    => 1,
                expected        => $current_element,
                expected_is_end => 1,
                file            => $xmlfile,
                expat           => $expat
            );
        }

        if ( defined $current_fieldnum ) {
            $this_record[$current_fieldnum] = $data_buffer;
            $data_buffer = $EMPTY_STR;
            undef $current_fieldnum;
            undef $current_element;
        }

        $where = INSIDE_RECORD;

    };

    my $char_handler = sub {
        #my $expat  = shift;
        #my $string = shift;
        $data_buffer = $data_buffer . $_[1];
        return;
    };

     my $parser = XML::Parser->new(
        Handlers => {
            Start => $start_of_tag_handler,
            End   => $end_of_tag_handler,
            Char  => $char_handler,
        }
    );  
    
    $parser->parsefile($xmlfile);
    
    return \@fields,\@records;
    
} ## tidy end: sub _parse_xml_file

sub _error_tag {

    require Params::Validate;

    my %p = Params::Validate::validate(
        @_,
        {   found           => 1,
            found_is_end    => { default => 0 },
            expected        => 0,
            expected_is_end => { default => 0 },
            expat           => 1,
            file            => 1,
        }
    );

    my $err;

    if ( $p{found_is_end} ) {
        $err = "Unexpected end tag </$p{found}> found";
    }
    else {
        $err = "Unexpected start tag <$p{found}> found";
    }

    if ( defined $p{expected} ) {
        if ( $p{expected_is_end} ) {
            $err .= " (Expected: end tag </$p{expected}>)";
        }
        else {
            $err .= " (Expected: start tag <$p{expected}>)";
        }
    }

    my $loc = _error_loc( $p{expat}, $p{file} );

    confess("$err at $loc");

} ## tidy end: sub _error_tag

sub _error_loc {

    my $expat = shift;
    my $file  = shift;

    my $line   = $expat->current_line;
    my $column = $expat->current_column;

    return "$file, line $line, column $column";

}

1;

__END__

