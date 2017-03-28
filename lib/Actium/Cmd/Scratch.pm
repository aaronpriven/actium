package Actium::Cmd::Scratch 0.012;

use Actium::Preamble;

use Actium::O::2DArray;

sub START {

    my $obj = Actium::O::2DArray::->new_from_xlsx(
        '/Users/apriven/Desktop/flex_stops_2017-03-26.xlsx');

    $obj->trim;
    $obj->apply(
        sub {
            my @words = split;
            $_ = join( ' ', u::sortbyline(@words) );
        }
    );

    say $obj->tabulated;
    $obj->xlsx(
        output_file => '/Users/apriven/Desktop/flex_stops_modified.xlsx' )
      ;

}

1;

__END__
