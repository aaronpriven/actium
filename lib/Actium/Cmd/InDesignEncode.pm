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

	my $input_file = shift @argv;

	my $input = Actium::O::2DArray->new_from_file($input_file);

	my @headers = $input->row(0);
	my @chinese_cols;

	if ( u::folded_in( 'zh', @headers ) ) {

		# treat that column as though it were Chinese
		@chinese_cols =
		  grep { u::feq( 'zh', $headers[$_] ) } ( 0 .. $#headers );
	}

	$input->apply(
		sub {

			my ( $row, $col ) = @_;

			if ( in( $col, @chinese_cols ) ) {

				my @components = $_ =~ /[!-~]+|[^!-~]/g;

				# separates visible ASCII characters from other characters

				foreach my $component (@components) {
					if ( $component !~ /[!-~]/ ) {
						$IDT->encode_high_chars($component);
						$component =
						    $IDT->charstyle('Chinese')
						  . $component
						  . $IDT->nocharstyle;
					}
				}

				$_ = join( $EMPTY, @components );

			}
			else {
				$IDT->encode_high_chars($_);
			}

		}
	);
	
	my $tsv = $input->tsv;
	my $output_file = "$input_file.tagged.txt";
	
	File::Slurper::write_text($output_file,$tsv);
	
	return;

}

1;

__END__
