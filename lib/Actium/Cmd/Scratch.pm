package Actium::Cmd::Scratch 0.011;

use Actium::Preamble;
use Actium::O::2DArray;

# a place to test out small programs, in the Actium environment

sub START {

    my $new_p_records_r = [ [qw/a b c/], [qw/d e f/], ];

    my $new_p_heads_r = [qw/H1 H2 H3/];

    my $aoa
      = Actium::O::2DArray->new($new_p_records_r);
      ;
      
    say u::dumpstr($aoa);
    
    my $tabbed
      = Actium::O::2DArray->new($new_p_records_r)->tsv( @{$new_p_heads_r} )
      ;

    say $tabbed;

}

1;

__END__