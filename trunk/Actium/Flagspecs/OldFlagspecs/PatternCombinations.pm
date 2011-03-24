#!/ActivePerl/bin/perl

#/Actium/Flagspecs/PatternCombinations.pm

# Subversion: $Id$

1;

__END__

use warnings;
use strict;

package Actium::Flagspecs::PatternCombinations;

use 5.010;

our $VERSION = '0.001';
$VERSION = eval $VERSION;    ## no critic (StringyEval)

use Actium::Constants;
use Actium::Term;
use Actium::Util qw(jk sk);

use Perl6::Export::Attrs;

    my %combos;
    my %override_of;
    my %comments_of;
    my %preserved_override_of;
    my %short_code_of;

    sub build_pat_combos {
        my $signup = shift;

        emit 'Building pattern combinations';

        my $short = 'aa';

        foreach my $stop ( keys_pats_of_stop() ) {
            foreach my $routedir ( routedirs_of_stop($stop) ) {

                my @pat_idents = pat_idents_of( $stop, $routedir );

                my @placelists
                  = map { $placelist_of{ jk( $routedir, $_ ) } } @pat_idents;

                my $combokey = jt(@placelists);
                my $shortkey = jt( $routedir, $combokey );
                $short_code_of{$shortkey} = $short++
                  unless exists $short_code_of{$shortkey};

                $combos{$routedir}{$combokey} = \@placelists;
                push @{ $combos_of_stop{$stop}{$routedir} }, $combokey;

            }
        }

        emit_done;
        return;

    } ## tidy end: sub build_pat_combos

    sub process_combo_overrides {
        my $signup = shift;
        my $file
          = File::Spec->catfile( $signup->get_dir(), $OVERRIDE_FILENAME );
        my $bakfile = "$file.bak";

        # first, we input the file, receiving the user overrides

        read_combo_overrides($file);

        # then, we output the file, including all current overrides and
        # all the old ones, too

        unlink $bakfile if -e $bakfile;
        if ( -e $file ) {
            rename $file, $bakfile;
        }

        write_combo_overrides($file);

        return \%override_of;

    } ## tidy end: sub process_combo_overrides

    Readonly my $ENTRY_DIVIDER => ( "=" x 78 );

    sub write_combo_overrides {
        my $file = shift;

        emit "Writing override file $OVERRIDE_FILENAME";

        open my $out, '>', $file or die "Can't open $file for writing";

        Readonly my $patternpad => $SPACE x 7;

        my $oldfh = select($out);

        local $Text::Wrap::unexpand = 1;

        foreach my $routedir ( sortbyline keys %combos ) {

            my ( $route, $dir ) = sk($routedir);

            my @thesecombos = keys %{ $combos{$routedir} };

            foreach my $combokey (@thesecombos) {
                my $shortkey = jt( $routedir, $combokey );
                say $comments_of{$shortkey} if $comments_of{$shortkey};
                printf "Line %-3s %68s\n", $route, $short_code_of{$shortkey};
                my @placelists = @{ $combos{$routedir}{$combokey} };
                #say $patternpad, 'Pattern',
                #  ( scalar @placelists ? '(s)' : $EMPTY_STR ),
                #  q{:};
                foreach my $placelist (@placelists) {
                    say wrap (
                        "=" . $patternpad,
                        "=" . $patternpad . $patternpad,
                        description_of( $routedir, $placelist ),
                    );
                }
                say '= Computer: ', destination_of( $dir, @placelists );
                say 'You: ', $override_of{$shortkey} || $EMPTY_STR;
                say $ENTRY_DIVIDER;
            }

        } ## tidy end: foreach my $routedir ( sortbyline...)

        say 'Codes:';
        foreach my $shortkey ( sort keys %short_code_of ) {
            say "$short_code_of{$shortkey}\t$shortkey";
        }

        select($oldfh);

        emit_done;

        return;

    } ## tidy end: sub write_combo_overrides

    #    my $stopdata = $signup->mergeread('Stops.csv');
    #    my $column = $stopdata->column_order_of('DescriptionF');
    #
    #    foreach my $stop ( sort (keys_pats_of_stop()) ) {
    #       my ($row) = $stopdata->rows_where( 'PhoneID', $stop );
    #       my $stopdesc = $row->[$column] ;
    #
    #       foreach my $routedir ( routedirs_of_stop($stop) ) {
    #           foreach my $combokey ( @{$combos_of_stop{$stop}{$routedir}} ) {
    #              print "$stop\t$stopdesc\t" ;
    #              say $combolong{$combokey};
    #           }
    #
    #       }
    #
    #    }

    sub read_combo_overrides {

        my $file = shift;

        my %input_override_of;
        my %input_descriptions_of;
        my %input_comments_of;
        my $chunk;

        open my $in, '<', $file or die "Can't open $file for input: $OS_ERROR";

        local $/ = $ENTRY_DIVIDER . "\n";

        while ( $chunk = <$in> ) {
            last if $chunk =~ /^Codes:/;

            my @lines = split( "\n", $chunk );
            my $comments    = join( "\n", grep {/\A#/} @lines );
            my $description = join( "\n", grep {/\A=/} @lines );
            @lines = grep { $_ and not(m/\A[#=]/) } @lines;

            my ( undef, $line, $short ) = split( $SPACE, shift @lines );
            my $override = shift;
            $override =~ s/ \A  You:   //sx;
            $override =~ s/ \A  \s+    //sx;
            $override =~ s/ \s+ \z     //sx;

            $input_override_of{$short}     = $override    if $override;
            $input_comments_of{$short}     = $comments    if $comments;
            $input_descriptions_of{$short} = $description if $description;

        }

        close $in or die "Can't close $file for input: $OS_ERROR";

        # read codes

        my @lines = split( /\n/, $chunk );
        shift @lines;    # the word "Codes:"

        my %shortkey_of;
        foreach my $line (@lines) {
            my ( $short, $shortkey ) = split( "\t", $line, 2 );
            $shortkey_of{$short} = $shortkey;
        }

        foreach my $short ( keys %input_override_of ) {
            my ( $routedir, $combokey ) = split( "\t", $short, 2 );
            if ( exists( $combos{$routedir}{$combokey} ) ) {
                $override_of{ $shortkey_of{$short} }
                  = $input_override_of{$short};
            }
            else {
                $preserved_override_of{ $shortkey_of{$short} }
                  = $input_override_of{$short};
            }

        }

        foreach my $short ( keys %input_comments_of ) {
            $comments_of{ $shortkey_of{$short} } = $input_comments_of{$short};
        }

    } ## tidy end: sub read_combo_overrides

1;