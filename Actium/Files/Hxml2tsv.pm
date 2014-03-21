# /Actium/Files/Hxml2tsv.pm
#
# Takes XML files exported from Hastus and turns them into tab-delimited files
# that are just like the Thea files.

# Subversion: $Id$

package Actium::Files::Hxml2tsv 0.003;

use Actium::Preamble;

my %xml_file_info = (
    stops => {
        old_fieldname_of => {
            qw(
              loca_latitude        stp_avl_lat
              loca_longitude       stp_avl_long
              stp_is_inservice     stp_in_service
              )
        },
        line_element => 'stop',
    },
);

sub convert_xml {

    my $theafolder = shift;

    my @xmlfiles = $theafolder->glob_files('*.xml');

    croak "No files found" unless @xmlfiles;

    my %results;

    foreach my $xmlfile (@xmlfiles) {
        my ( $filenamepart, $ext ) = Actium::Util::file_ext($xmlfile);

        my $xml_file_info = $xml_file_info{$filenamepart};
        next unless $xml_file_info;

        my ( $headers_r, $lines_r )
          = _parse_xml_file( $xmlfile, $xml_file_info );

        $results{$filenamepart} = {
            headers => $headers_r,
            lines   => $lines_r,
        };

    }

    return %results;
} ## tidy end: sub convert_xml

sub _parse_xml_file {

    my $xmlfile       = shift;
    my $xml_file_info = shift;
    my $line_element  = $xml_file_info->{line_element};
    # the element that contains the whole line -- 'stop' for stops.xml

    my %old_fieldname_of = %{ $xml_file_info->{old_fieldname_of} };
    # gives old THEA field name for new XML field name

    my ( $in_a_data_line, $current_fieldnum , $data_buffer);
    my ( %fieldnum_of_element, @fields, @linedata );
    
    
=begin comment

Here is the list of events that are noted. 

Start of $line_element - mark the beginning of a line. 

Start of any other element - ignored unless inside a line. 
inside a line - if have never seen this element, add its fieldname
to the end of the list, and keep track of what column this should be in

CHARS - Add chars to $data_buffer

End of any other element - only if inside a line, add $data_buffer to the
appropriate column

End of $line_element - mark end of line.

=end comment

=cut

    my $save_buffer = sub {
        
        if (defined $current_fieldnum and defined $data_buffer) {
           $linedata[$current_fieldnum] = $data_buffer;
        }
           
        $data_buffer = $EMPTY_STR;
        undef $current_fieldnum;
    };
    
    
    my $start_of_tag_handler = sub {
        
        #my $expat   = shift;
        #my $element = shift;
        
        
        
        
        
        
        
        
        
        
        my $element = $_[1];
        
        
        
        
        
        
        
        
        
        
        
        

        if ( $element eq $line_element ) {
            # 'stop' for $stops.xml
            $in_a_data_line = 1;
            undef $current_fieldnum;

        }
        elsif ($in_a_data_line) {
            
            
            # have to add code to make sure that if we haven't seen an end 
            # tag it's handled

            if ( not $fieldnum_of_element{$element} ) {
                # if haven't ever seen this element before

                my $field = $old_fieldname_of{$element} // $element;

                push @fields, $field;
                $fieldnum_of_element{$element} = $#fields;

            }

            $current_fieldnum = $fieldnum_of_element{$element};

            # at the moment, all attributes are ignored.
            # the only attribute that's currently given is
            # xsi:nil, and this just indicates an empty field --
            # which is just as indicated by there being no data...
            # so as near as I can tell, it's redundant.
            # (No difference between null and empty as far as I can tell)

        } ## tidy end: elsif ($in_a_data_line)

        return;

      };
      
     my $end_of_tag_handler = sub {
              #my $expat   = shift;
        #my $element = shift;
        my $element = $_[1];
        if ( $element eq $line_element ) {
            # 'stop' for $stops.xml
            $in_a_data_line = 0;
        }
        
        if (defined $current_fieldnum) {
           $linedata[$current_fieldnum] = $data_buffer;
           $data_buffer = $EMPTY_STR;
           undef $current_fieldnum;
        }
        
     };
      
      
      

} ## tidy end: sub _parse_xml_file

1;

__END__

