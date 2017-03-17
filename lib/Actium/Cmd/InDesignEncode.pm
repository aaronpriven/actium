package Actium::Cmd::InDesignEncode 0.010;

use Actium::Preamble;
use autodie;
use File::Slurper;

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

use Actium::O::2DArray;

sub START {
    my ( $class, $env ) = @_;
    my @argv = $env->argv;

    foreach my $input_file (@argv) {

        my $processing_cry = $env->crier->cry("Processing $input_file");
        my $input_cry      = $env->crier->cry("Loading $input_file");

        my $input = Actium::O::2DArray->new_from_file($input_file);

        $input->[0][0] =~ s/\N{BYTE ORDER MARK}//;

        $input_cry->done;

        my $encode_cry = $env->crier->cry("Encoding $input_file");

        my @headers = $input->row(0);
        my @chinese_cols;

        if ( u::folded_in( 'zh', @headers ) ) {

            # treat that column as though it were Chinese
            @chinese_cols
              = grep { u::feq( 'zh', $headers[$_] ) } ( 0 .. $#headers );
        }

        my %style_of = (
            ( quotemeta('*') ) => $IDT->char_bold,
            '_'                => $IDT->char_underline
        );
        my $nochar = $IDT->nocharstyle;

        $input->apply(
            sub {

                my ( $row, $col ) = @_;

                if ( u::in( $col, @chinese_cols ) ) {

                    my @components = $_ =~ /[!-~]+|[^!-~]+/g;

                    # eliminate components with just spaces

                    while ( u::any { $_ eq ' ' } @components ) {
                        my $position
                          = ( u::firstidx { $_ eq ' ' } @components );

                        if ( $position == 0 ) {
                            my $newcomponent = $components[0] . $components[1];
                            splice( @components, 0, 2, $newcomponent );
                        }
                        elsif ( $position == @components ) {
                            my $newcomponent
                              = $components[-2] . $components[-1];
                            splice( @components, -1, 2, $newcomponent );

                        }
                        else {
                            my $newcomponent = join( $EMPTY,
                                @components[ $position - 1, $position,
                                $position + 1 ] );
                            #splice( @components, $position - 1, 3 )
                            splice( @components, $position - 1,
                                3, $newcomponent );

                        }

                    } ## tidy end: while ( u::any { $_ eq ' '...})

                    # separates visible ASCII characters from other characters
                    foreach my $component (@components) {
                        if ( $component !~ /[!-~]/ ) {
                            $IDT->encode_high_chars($component);
                            $component
                              = $IDT->charstyle('Chinese')
                              . $component
                              . $IDT->nocharstyle;
                        }
                    }

                    $_ = join( $EMPTY, @components );

                } ## tidy end: if ( in( $col, @chinese_cols...))
                else {

                    $IDT->encode_high_chars($_);

                    # convert *bold* and _underline_

                    foreach my $char ( keys %style_of ) {
                        s/ 
                           (?<!$char)	       # lookbehind: not a char
                           $char               # a char
                           ([^$char]+)         # one or more non-char characters
                           $char               # Another char
                           (?!$char)           # lookahead: not a char
                       /$style_of{$char}$1$nochar/gx;
                    }

                }

            }
        );

        $encode_cry->done;

        my $tsv = $input->tsv;

        my ( $base, $ext ) = u::file_ext($input_file);
        my $output_file = "$base.tagged.txt";

        my $write_cry = $env->crier->cry("Writing $output_file");

        File::Slurper::write_text( $output_file, $tsv );

        $write_cry->done;

    } ## tidy end: foreach my $input_file (@argv)

    return;

} ## tidy end: sub START

1;

__END__
