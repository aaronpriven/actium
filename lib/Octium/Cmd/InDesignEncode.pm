package Octium::Cmd::InDesignEncode 0.010;

use Actium;
use Octium;
use autodie;
use File::Slurper;

use Octium::Text::InDesignTags;
const my $IDT => 'Octium::Text::InDesignTags';

use Array::2D;

sub START {
    my ( $class, $env ) = @_;
    my @argv = $env->argv;

    foreach my $input_file (@argv) {

        my $processing_cry = $env->crier->cry("Processing $input_file");
        my $input_cry      = $env->crier->cry("Loading $input_file");

        my $input = Array::2D->new_from_file($input_file);

        $input->[0][0] =~ s/\N{BYTE ORDER MARK}//;

        $input_cry->done;

        my $encode_cry = $env->crier->cry("Encoding $input_file");

        my @headers = $input->row(0);
        my @chinese_cols;

        if ( Octium::folded_in( 'zh', @headers ) ) {

            # treat that column as though it were Chinese
            @chinese_cols
              = grep { Octium::feq( 'zh', $headers[$_] ) } ( 0 .. $#headers );
        }

        my %style_of = (
            ( quotemeta('*') ) => $IDT->char_bold,
            '_'                => $IDT->char_underline
        );
        my $nochar = $IDT->nocharstyle;

        $input->apply(
            sub {

                my ( $row, $col ) = @_;

                if ( Octium::in( $col, @chinese_cols ) ) {

                    my @components = $_ =~ /[!-~]+|[^!-~]+/g;

                    # eliminate components with just spaces

                    while ( Actium::any { $_ eq ' ' } @components ) {
                        my $position
                          = ( Actium::firstidx { $_ eq ' ' } @components );

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

                    }    ## tidy end: while ( Actium::any { $_ eq ' '...})

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

                }    ## tidy end: if ( Octium::in( $col, @chinese_cols...))
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

        my ( $base, $ext ) = Octium::file_ext($input_file);
        my $output_file = "$base.tagged.txt";

        my $write_cry = $env->crier->cry("Writing $output_file");

        File::Slurper::write_text( $output_file, $tsv );

        $write_cry->done;

    }    ## tidy end: foreach my $input_file (@argv)

    return;

}    ## tidy end: sub START

1;

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 SYNOPSIS

 use <name>;
 # do something with <name>
   
=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS (pick one)

=over

=item B<subroutine()>

Description of subroutine.

=back

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

