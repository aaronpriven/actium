# /Actium/Import/CalculateFields.pm
#
# Routines for calculating fields based on imported data.
# Does things like break up "description" into "on" and "at". Etc.
# This is probably a terrible name for this.

# Subversion: $Id$

package Actium::Import::CalculateFields 0.003;

## no critic (ProhibitAmbiguousNames)

use Actium::Preamble;

sub hastus_stops_import {
    
    my @stop_headers = @{+shift};
    my @stop_records = @{+shift};
    
    foreach my $stop_record (@stop_records) {
        my %field;
        @field{@stop_headers} = @{$stop_record};
        
        my ($on, $at, $stnum, $comment) = 
           _description ($field{stp_description});

        
        
    }
        
    
}

sub _description {
    my $desc = shift;
    
    my ($on, $at, $stnum, $comment) = (($EMPTY_STR) x 4 ) ;
    
    $desc =~ s/(\(.*\))//;
    $comment = $1;
    
    my $rest;
    ($on, $rest) = split(/:/, $desc, 2);
    
    if ($on =~ / at / and not $rest ) {
       ($on, $rest) = split(/ at /, $desc, 2);
    }

    if ($rest =~ /^#/) {
        $stnum = $rest;
    } else {
        $at = $rest;
    }

    
    
    
    
    
    
}

1;

__END__