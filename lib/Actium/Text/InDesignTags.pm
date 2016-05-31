# Actium/Text/InDesignTags.pm

# class providing routines and constants for InDesign tagged text

# Legacy stage 4

package Actium::Text::InDesignTags 0.010;

use warnings;
use 5.016;

# Simple tags

use Carp;    ### DEP ###

use constant {
	start            => "<ASCII-MAC>\r<Version:6><FeatureSet:InDesign-Roman>",
	punctuationspace => '<0x2008>',
	thinspace        => '<0x2009>',
	bullet           => '<0x2022>',
	boxbreak         => "<cNextXChars:Box>\r<cNextXChars:>",
	pagebreak        => "<cNextXChars:Page>\r<cNextXChars:>",
	nbsp             => '<0x00A0>',
	endash           => '<0x2013>',
	emdash           => '<0x2014>',
	hardreturn       => "\r",                     # 0x000D
	softreturn       => "\n",                     # 0x000A
	hardreturn_esc   => '<0x000D>',
	softreturn_esc   => '<0x000A>',
	end_nested_style => '<0x0003>',               # actually is exported as 0x03
	emspace          => '<0x2003>',
	enspace          => '<0x2002>',
	thirdspace       => '<0x2004>',
	hairspace        => '<0x200A>',
	nonjoiner        => '<0x200C>',
	discretionary_lf => '<0x200B>',
	noparastyle      => '<ParaStyle:>',
	nocharstyle      => '<CharStyle:>',
	nocolor          => '<cColor:>',
	nosupersub       => '<cPosition:>',
	superscript      => '<cPosition:Superscript>',
	subscript        => '<cPosition:Subscript>',
	char_underline   => '<CharStyle:Underline>',
	char_bold        => '<CharStyle:Bold>',

};

# Tags that have parameters

sub _parameter {
	my $invocant = shift;
	my $value    = shift;
	my $tag      = shift;
	return "<$tag:$value>";
}

sub color {
	return _parameter( @_, 'cColor' );
}

sub parastyle {
	return _parameter( @_, 'ParaStyle' );
}

sub tablestyle {
	return _parameter( @_, 'TableStyle' );
}

sub cellstyle {
	return _parameter( @_, 'CellStyle' );
}

sub charstyle {
	return _parameter( @_, 'CharStyle' );
}

sub dropcapchars {
	return _parameter( @_, 'pdcc' );
}

sub underline_word {
	my $invocant = shift;
	my $word     = shift;
	return char_underline . $word . nocharstyle;
}

sub bold_word {
	my $invocant = shift;
	my $word     = shift;
	return char_bold . $word . nocharstyle;
}

sub combi_side {
	my $invocant = shift;
	my $num      = $invocant->combichar( +shift );
	return ( $invocant->charstyle('sidenum') . $num . nocharstyle );
}

sub combi_foot {
	my $invocant = shift;
	my $num      = $invocant->combichar( +shift );
	return ( $invocant->charstyle('footnum') . $num . nocharstyle );
}

sub combichar {

	my $invocant = shift;
	my $num      = shift;
	if ( $num < 0 or $num > 99 or $num != int($num) ) {
		croak "invalid footnote '$num'";
	}

	if ( $num < 20 ) {
		$num = (qw(p q w e r t y u i o a s d f g h j k l ;))[$num];

		# 0 through 19
	}
	else {
		my @chars = split( //, $num );
		no warnings qw(qw);
		$chars[1] = (qw/ ) ! @ # $ % ^ & * ( /)[ $chars[1] ];

		# The characters above are the right halves of two-digit numbers.
		# 0-9 are, themselves, the left halves of two-digit numbers,
		# so we don't need to modify those.
		$num = join( '', @chars );
	}

	return $num;

}    ## tidy end: sub combichar

sub encode_all {

	my $invocant = shift;

	my $check_ord_cr = sub {
		my $ord = shift;
		return (
			     $ord < 32
			  or $ord == ord('<')
			  or $ord == ord('>')
			  or $ord > 0x7F
		);
	};

	return _encode( $check_ord_cr, @_ )

}

sub encode_high_chars {

	my $invocant = shift;

	my $check_ord_cr = sub {
		my $ord = shift;
		return ( $ord == ord('<') or $ord == ord('>') or $ord > 0x7F );
	};

	return _encode( $check_ord_cr, @_ )

}

sub _encode {

	my $check_ord_cr = shift;

	@_ = @_ ? @_ : $_ if defined wantarray;

	# set @_ to be a copy of itself, or of $_, if not in void context

	# allows it to work on copies in any but void context, or on
	# the original in void context. Thanks to Text::Trim

	for ( @_ ? @_ : $_ ) {    # alias $_ to each entry of @_, or if none, $_
		next unless defined;
		my @chars = split(//);
		for my $i ( reverse 0 .. $#chars ) {
			my $ord = ord( $chars[$i] );
			if ( $check_ord_cr->($ord) ) {
				substr( $_, $i, 1, sprintf( '<0x%04X>', $ord ) );
			}

		}
	}
	return if not defined wantarray;
	return @_ if wantarray;

	# return concatenation of defined values, if any
	my @defined_vals = grep { defined($_) } @_;
	if (@defined_vals) {
		my $joined = join( '', @defined_vals );
		return $joined;
	}

	return;

}

1;

__END__

Note that underline_word and bold_word will return to null the character
style -- it doesn't just override current word with underlining or bold 
