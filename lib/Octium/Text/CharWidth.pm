package Octium::Text::CharWidth 0.012;

# character widths

use warnings;
use 5.012;    # turns on features

use Sub::Exporter -setup => { exports => [qw( ems twelfths char_width )] };
# Sub::Exporter ### DEP ###

use List::Util ('sum'); ### DEP ###
use Carp; ### DEP ###
use POSIX ('ceil'); ### DEP ###

# the following are character widths for a few fonts, derived from the AFM
# files

# This is nowhere near good enough to lay everything out really precisely,
# but this is all approximate. If we really wanted to do this "precisely" we'd
# probably lay out the page, see if the text is overset, if it is,
# change to the next smaller type, etc., because the only way to be really sure
# what InDesign will do is to ask InDesign to do it.

# The widths are in fractions of an em (the text height), so in a 10 point
# font, someting that's width .333 will turn out to be 3.33 points wide.

# This is all very kludgy.

my %warned_font;

my %widths;

$widths{Univers_CondensedBold} = [
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.222, 0.333, 0.333, 0.444, 0.444, 0.778, 0.667, 0.222,   # SP
    0.278, 0.278, 0.444, 0.5,   0.222, 0.5,   0.222, 0.278,
    0.444, 0.444, 0.444, 0.444, 0.444, 0.444, 0.444, 0.444,   # 0 1 2 3 4 5 6 7,
    0.444, 0.444, 0.222, 0.222, 0.5,   0.5,   0.5,   0.444,   # 8 9 : ; < = > ?,
    0.795, 0.611, 0.611, 0.556, 0.611, 0.5,   0.444, 0.611,   # @ A B C D E F G
    0.611, 0.278, 0.5,   0.556, 0.444, 0.833, 0.667, 0.611,   # H I J K L M N O
    0.556, 0.611, 0.556, 0.556, 0.5,   0.611, 0.556, 0.889,   # P Q R S T U V W
    0.556, 0.556, 0.5,   0.278, 0.25,  0.278, 0.5,   0.5,     # X Y Z
    0.222, 0.5,   0.5,   0.5,   0.5,   0.5,   0.278, 0.5,
    0.5,   0.278, 0.278, 0.5,   0.278, 0.722, 0.5,   0.5,
    0.5,   0.5,   0.333, 0.444, 0.278, 0.5,   0.444, 0.778,
    0.5,   0.444, 0.389, 0.274, 0.25,  0.274, 0.5,   0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.278, 0.278, 0.278, 0.278, 0.278, 0.278, 0.278, 0.278,
    0.278, 0,     0.278, 0.278, 0,     0.445, 0.278, 0.278,
    0.222, 0.333, 0.444, 0.444, 0.444, 0.444, 0.25,  0.444,
    0.278, 0.83,  0.3,   0.444, 0.5,   0.333, 0.83,  0.278,
    0.4,   0.5,   0.266, 0.266, 0.278, 0.5,   0.55,  0.222,
    0.278, 0.266, 0.3,   0.444, 0.666, 0.666, 0.666, 0.444,
    0.611, 0.611, 0.611, 0.611, 0.611, 0.611, 0.833, 0.556,
    0.5,   0.5,   0.5,   0.5,   0.278, 0.278, 0.278, 0.278,
    0.611, 0.667, 0.611, 0.611, 0.611, 0.611, 0.611, 0.5,
    0.611, 0.611, 0.611, 0.611, 0.611, 0.556, 0.556, 0.556,
    0.5,   0.5,   0.5,   0.5,   0.5,   0.5,   0.778, 0.5,
    0.5,   0.5,   0.5,   0.5,   0.278, 0.278, 0.278, 0.278,
    0.5,   0.5,   0.5,   0.5,   0.5,   0.5,   0.5,   0.5,
    0.5,   0.5,   0.5,   0.5,   0.5,   0.444, 0.5,   0.444,
];

$widths{Futura_CondensedBold} = [
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.245, 0.246, 0.36,  0.49,  0.49,  0.858, 0.59,  0.302,
    0.3,   0.3,   0.376, 0.49,  0.245, 0.49,  0.245, 0.547,
    0.49,  0.49,  0.49,  0.49,  0.49,  0.49,  0.49,  0.49,     # 0 1 2 3 4 5 6 7
    0.49,  0.49,  0.245, 0.245, 0.49,  0.49,  0.49,  0.454,    # 8 9 : ; < = > ?
    0.833, 0.528, 0.479, 0.452, 0.53,  0.392, 0.394, 0.563,
    0.555, 0.255, 0.352, 0.513, 0.373, 0.722, 0.573, 0.582,
    0.487, 0.582, 0.53,  0.44,  0.414, 0.544, 0.565, 0.793,
    0.545, 0.514, 0.508, 0.32,  0.25,  0.32,  0.49,  0.5,
    0.302, 0.433, 0.433, 0.315, 0.433, 0.414, 0.299, 0.437,
    0.424, 0.209, 0.209, 0.44,  0.21,  0.639, 0.424, 0.436,
    0.433, 0.433, 0.315, 0.376, 0.308, 0.423, 0.452, 0.694,
    0.489, 0.452, 0.401, 0.3,   0.25,  0.3,   0.49,  0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.209, 0.3,   0.3,   0.3,   0.3,   0.3,   0.3,   0.3,
    0.3,   0,     0.3,   0.3,   0,     0.3,   0.3,   0.3,
    0.245, 0.246, 0.49,  0.49,  0.49,  0.49,  0.25,  0.491,
    0.3,   0.83,  0.3,   0.433, 0.49,  0.318, 0.83,  0.3,
    0.4,   0.49,  0.294, 0.294, 0.3,   0.423, 0.6,   0.245,
    0.3,   0.294, 0.3,   0.433, 0.735, 0.735, 0.735, 0.454,
    0.528, 0.528, 0.528, 0.528, 0.528, 0.528, 0.674, 0.452,
    0.392, 0.392, 0.392, 0.392, 0.255, 0.255, 0.255, 0.255,
    0.53,  0.573, 0.582, 0.582, 0.582, 0.582, 0.582, 0.49,
    0.582, 0.544, 0.544, 0.544, 0.544, 0.514, 0.487, 0.478,
    0.433, 0.433, 0.433, 0.433, 0.433, 0.433, 0.64,  0.315,
    0.414, 0.414, 0.414, 0.414, 0.209, 0.209, 0.209, 0.209,
    0.436, 0.424, 0.436, 0.436, 0.436, 0.436, 0.436, 0.49,
    0.436, 0.423, 0.423, 0.423, 0.423, 0.452, 0.433, 0.452,
];

$widths{Futura_Heavy} = [
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.289, 0.325, 0.488, 0.578, 0.578, 0.772, 0.702, 0.296,
    0.271, 0.271, 0.417, 0.578, 0.289, 0.578, 0.289, 0.539,
    0.578, 0.578, 0.578, 0.578, 0.578, 0.578, 0.578, 0.578,    # 0 1 2 3 4 5 6 7
    0.578, 0.578, 0.289, 0.289, 0.578, 0.578, 0.578, 0.487,    # 8 9 : ; < = > ?
    0.975, 0.676, 0.553, 0.601, 0.646, 0.488, 0.463, 0.739,    # @ A B C D E F G
    0.674, 0.254, 0.389, 0.62,  0.402, 0.836, 0.759, 0.782,
    0.528, 0.782, 0.558, 0.526, 0.451, 0.66,  0.639, 0.977,
    0.623, 0.587, 0.575, 0.288, 0.539, 0.288, 0.578, 0.5,
    0.296, 0.565, 0.565, 0.421, 0.565, 0.501, 0.303, 0.562,
    0.54,  0.253, 0.253, 0.526, 0.239, 0.802, 0.54,  0.548,
    0.565, 0.565, 0.367, 0.41,  0.274, 0.535, 0.488, 0.783,
    0.549, 0.52,  0.481, 0.389, 0.538, 0.389, 0.578, 0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0,     0,     0,     0,     0,     0,     0,     0,
    0.253, 0.38,  0.38,  0.4,   0.4,   0.4,   0.4,   0.38,
    0.4,   0,     0.38,  0.38,  0,     0.42,  0.38,  0.4,
    0.289, 0.325, 0.578, 0.578, 0.578, 0.578, 0.538, 0.577,
    0.4,   0.8,   0.339, 0.514, 0.578, 0.33,  0.8,   0.4,
    0.4,   0.578, 0.346, 0.346, 0.38,  0.535, 0.577, 0.289,
    0.38,  0.346, 0.339, 0.514, 0.867, 0.867, 0.867, 0.487,
    0.676, 0.676, 0.676, 0.676, 0.676, 0.676, 0.921, 0.601,
    0.488, 0.488, 0.488, 0.488, 0.254, 0.254, 0.254, 0.254,
    0.646, 0.759, 0.782, 0.782, 0.782, 0.782, 0.782, 0.578,
    0.782, 0.66,  0.66,  0.66,  0.66,  0.587, 0.528, 0.561,
    0.565, 0.565, 0.565, 0.565, 0.565, 0.565, 0.792, 0.421,
    0.501, 0.501, 0.501, 0.501, 0.253, 0.253, 0.253, 0.253,
    0.548, 0.54,  0.548, 0.548, 0.548, 0.548, 0.548, 0.578,
    0.564, 0.535, 0.535, 0.535, 0.535, 0.52,  0.565, 0.52,
];

$widths{'FrutigerLTStd-BoldCn'} = [
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.278, 0.389, 0.481, 0.556, 0.556, 1.000, 0.722, 0.278,
    0.333, 0.333, 0.556, 0.600, 0.278, 0.333, 0.278, 0.389,
    0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.556, # 0 1 2 3 4 5 6 7
    0.556, 0.556, 0.278, 0.278, 0.600, 0.600, 0.600, 0.500, # 8 9 : ; < = > ?
    0.800, 0.722, 0.611, 0.611, 0.722, 0.556, 0.500, 0.722, # @ A B C D E F G
    0.722, 0.278, 0.389, 0.667, 0.500, 0.944, 0.722, 0.778, # H I J K L M N O
    0.556, 0.778, 0.611, 0.556, 0.556, 0.722, 0.667, 1.000, # P Q R S T U V W
    0.667, 0.667, 0.556, 0.333, 0.389, 0.333, 0.600, 0.500, # X Y Z
    0.278, 0.556, 0.611, 0.444, 0.611, 0.556, 0.389, 0.611,
    0.611, 0.278, 0.278, 0.556, 0.278, 0.889, 0.611, 0.611,
    0.611, 0.611, 0.389, 0.444, 0.389, 0.611, 0.556, 0.889,
    0.556, 0.556, 0.500, 0.333, 0.222, 0.333, 0.600, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000, 0.000,
    0.278, 0.389, 0.556, 0.556, 0.556, 0.556, 0.222, 0.556,
    0.278, 0.800, 0.361, 0.556, 0.600, 0.333, 0.800, 0.278,
    0.400, 0.600, 0.361, 0.361, 0.278, 0.611, 0.620, 0.278,
    0.278, 0.361, 0.397, 0.556, 0.834, 0.834, 0.834, 0.500,
    0.722, 0.722, 0.722, 0.722, 0.722, 0.722, 0.944, 0.611,
    0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.278, 0.278,
    0.722, 0.722, 0.778, 0.778, 0.778, 0.778, 0.778, 0.600,
    0.778, 0.722, 0.722, 0.722, 0.722, 0.667, 0.556, 0.611,
    0.556, 0.556, 0.556, 0.556, 0.556, 0.556, 0.889, 0.444,
    0.556, 0.556, 0.556, 0.556, 0.278, 0.278, 0.278, 0.278,
    0.611, 0.611, 0.611, 0.611, 0.611, 0.611, 0.611, 0.600,
    0.611, 0.611, 0.611, 0.611, 0.611, 0.556, 0.611, 0.556,

];

# Correct 0, 3, 4, 8 since they turn out wider in Futura

foreach (qw/0 3 4 8/) {
    $widths{Futura_CondensedBold}[ord] *= 1.2;
    $widths{Futura_Heavy}[ord] *= 1.2;
}

foreach (qw/1/) {
    $widths{Futura_CondensedBold}[ord]   *= .8;
    $widths{Univers_CondensedBold}[ord]  *= .8;
    $widths{Futura_Heavy}[ord]           *= .8;
    #$widths{'FrutigerLTStd-BoldCn'}[ord] *= .8;
}

my $default = ord('M');

sub ems {
    my $text = shift;
    my $font = _check_font(shift);
    return _calc_ems( $text, $font );
}

sub twelfths {
    my $text = shift;
    my $font = _check_font(shift);
    return ceil( _calc_ems( $text, $font ) / $widths{$font}[$default] * 12 );
}

sub char_width {
    my $text = shift;
    my $font = _check_font(shift);
    return ceil( _calc_ems( $text, $font ) / $widths{$font}[$default] );
}

sub _calc_ems {
    my ( $text, $font ) = @_;
    my @chars = split( //, $text );
    return sum( map { $widths{$font}[ord] // $widths{$font}[$default] }
          @chars );
}

sub _check_font {
    my $font = shift;

    return 'FrutigerLTStd-BoldCn' unless defined $font;

    $font =~ s/ /_/g;

    if ( $widths{$font} or $warned_font{$font} ) {
        return $font;
    }

    if ( not $warned_font{$font} ) {
        carp "Unknown font $font in calculating widths. "
          . 'Using FrutigerLTStd-BoldCn';
        $warned_font{$font} = 1;
    }
    return 'FrutigerLTStd-BoldCn';
}

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
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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
