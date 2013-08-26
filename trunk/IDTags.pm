# IDTags.pm
# vimcolor: #002000

# This is IDTags.pm, a module to print ID Tags.

# Obsolete. Use Actium::Text::InDesignTags.pm instead

package IDTags;

use strict;

use Sub::Exporter -setup => {
    exports => [
        qw<start start_with_tables underline bold parastyle charstyle 
           nocharstyle dropcapchars punctuationspace thinspace bullet 
           boxbreak superscript nbsp endash emdash softreturn color 
           emspace enspace nonjoiner  thirdspace hairspace discretionary_lf 
           combiside combifootnote combichar>
    ]
};

use Carp;

sub start {

    my $starttext = <<'EOF';
<ASCII-MAC>
<Version:2.000000><FeatureSet:InDesign-Roman><ColorTable:=<Black:COLOR:CMYK:Process:0.000000,0.000000,0.000000,1.000000><Grey20:COLOR:CMYK:Process:0.000000,0.000000,0.000000,0.200000><Grey80:COLOR:CMYK:Process:0.000000,0.000000,0.000000,0.800000><H3-Blue:COLOR:CMYK:Process:1.000000,0.300000,0.000000,0.000000><H8-Blue:COLOR:CMYK:Process:0.900000,0.050000,0.000000,0.000000><H12-Aqua:COLOR:CMYK:Process:0.600000,0.000000,0.150000,0.000000><H15-Green:COLOR:CMYK:Process:0.750000,0.000000,0.400000,0.000000><H16-Green:COLOR:CMYK:Process:0.700000,0.000000,0.800000,0.000000><H43-Aqua:COLOR:CMYK:Process:0.500000,0.000000,0.351000,0.000000><H47-Blue:COLOR:CMYK:Process:0.650000,0.250000,0.000000,0.000000><H51-Blue:COLOR:CMYK:Process:0.600000,0.150000,0.000000,0.000000><H69-Green:COLOR:CMYK:Process:0.351000,0.000000,0.351000,0.000000><H71-Purple:COLOR:CMYK:Process:0.351000,0.500000,0.000000,0.000000><H81-Green:COLOR:CMYK:Process:0.351000,0.000000,0.700000,0.000000><H101-Purple:COLOR:CMYK:Process:0.550000,0.600000,0.000000,0.000000><H103-Pink:COLOR:CMYK:Process:0.030000,0.351000,0.000000,0.000000><H108-Yellow:COLOR:CMYK:Process:0.150000,0.000000,0.800000,0.000000><H121-Orange:COLOR:CMYK:Process:0.000000,0.150000,0.800000,0.050000><H122-Pink:COLOR:CMYK:Process:0.150000,0.550000,0.000000,0.000000><H124-Pink:COLOR:CMYK:Process:0.000000,0.500000,0.150000,0.000000><H125-Pink:COLOR:CMYK:Process:0.000000,0.600000,0.351000,0.000000><H130-Orange:COLOR:CMYK:Process:0.000000,0.400000,0.800000,0.000000><H132-Rose:COLOR:CMYK:Process:0.000000,0.700000,0.300000,0.000000><H134-Magenta:COLOR:CMYK:Process:0.100000,0.700000,0.000000,0.000000><H135-Red:COLOR:CMYK:Process:0.050000,0.800000,0.750000,0.000000><H136-Red:COLOR:CMYK:Process:0.150000,1.000000,0.650000,0.000000>>
<DefineParaStyle:Normal=<Nextstyle:Normal><cTypeface:57 Condensed><cSize:10.000000><cAutoPairKern:Optical><cLigatures:0><cBaselineShift:-0.000000><pHyphenationLadderLimit:0><pAutoLeadPercent:1.204987><cLeading:12.000000><pMinCharBeforeHyphen:3><pShortestWordHyphenated:6><pHyphenationZone:0.000000><cFont:Univers><pMaxWordSpace:2.500000><pMinWordSpace:0.750000><pMaxLetterspace:0.039993><cHang:Baseline><pRuleAboveColor:Black><pRuleAboveTint:100.000000><pRuleBelowColor:Black><pRuleBelowTint:100.000000>>
<DefineParaStyle:amtimes=<BasedOn:Normal><Nextstyle:amtimes><cSize:11.000000><cAutoPairKern:Metrics><cTracking:2><pTextComposer:HL Single><cLeading:12.500000><pHyphenation:0><pTabRuler:13.000000\,Char\,\:\,0\, \;>>
<DefineParaStyle:num-name=<BasedOn:Normal><Nextstyle:num-name><cColor:Grey80><cTypeface:Heavy><cSize:12.000000><cStrokeWeight:0.200000><cTracking:100><cCase:All Caps><cStrokeColor:COLOR\:CMYK\:Process\:0.000000\,0.000000\,0.000000\,1.000000><cFont:Futura><pRuleAboveStroke:0.250000><pRuleAboveOffset:12.900000><pRuleAboveLeftIndent:-24.000000><pRuleAboveOn:1>>
<DefineParaStyle:days-dest=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:dropcaphead=<BasedOn:Normal><Nextstyle:dropcaphead>>
<DefineParaStyle:dropcapheadmany=<BasedOn:Normal><Nextstyle:dropcapheadmany>>
<DefineParaStyle:noteonly=<BasedOn:Normal><Nextstyle:noteonly><pBodyAlignment:Center>>
<DefineParaStyle:pmtimes=<BasedOn:amtimes><Nextstyle:pmtimes><cTypeface:67 Bold Condensed>>
<DefineParaStyle:sidenotes=<BasedOn:Normal><Nextstyle:sidenotes><pSpaceAfter:6.000000><pKeepParaTogether:1><pKeepLines:1><pHyphenationWeight:3>>
<DefineParaStyle:bottomnotes=<BasedOn:Normal><Nextstyle:bottomnotes><cSize:9.000000><cLeading:10.000000>>
<DefineCharStyle:Bold=<Nextstyle:Bold><cTypeface:67 Bold Condensed>><DefineCharStyle:footnum=<Nextstyle:footnum>>
EOF

    $starttext =~ s/\n/\r/g;    #CRs rather than LFs for Mac programs

    $starttext =~ s/\r$//;      # strip trailing newline

    return $starttext;

    # these are the definitions out of a test tagged file. The specific values
    # are intended to be overridden by the InDesign import routine.

} ## tidy end: sub start :

sub start_with_tables  {

    my $starttext = <<'EOF';
<ASCII-MAC>
<Version:2.000000><FeatureSet:InDesign-Roman><ColorTable:=<Black:COLOR:CMYK:Process:0.000000,0.000000,0.000000,1.000000><Grey20:COLOR:CMYK:Process:0.000000,0.000000,0.000000,0.200000><Grey80:COLOR:CMYK:Process:0.000000,0.000000,0.000000,0.800000><H3-Blue:COLOR:CMYK:Process:1.000000,0.300000,0.000000,0.000000><H8-Blue:COLOR:CMYK:Process:0.900000,0.050000,0.000000,0.000000><H12-Aqua:COLOR:CMYK:Process:0.600000,0.000000,0.150000,0.000000><H15-Green:COLOR:CMYK:Process:0.750000,0.000000,0.400000,0.000000><H16-Green:COLOR:CMYK:Process:0.700000,0.000000,0.800000,0.000000><H43-Aqua:COLOR:CMYK:Process:0.500000,0.000000,0.351000,0.000000><H47-Blue:COLOR:CMYK:Process:0.650000,0.250000,0.000000,0.000000><H51-Blue:COLOR:CMYK:Process:0.600000,0.150000,0.000000,0.000000><H69-Green:COLOR:CMYK:Process:0.351000,0.000000,0.351000,0.000000><H71-Purple:COLOR:CMYK:Process:0.351000,0.500000,0.000000,0.000000><H81-Green:COLOR:CMYK:Process:0.351000,0.000000,0.700000,0.000000><H101-Purple:COLOR:CMYK:Process:0.550000,0.600000,0.000000,0.000000><H103-Pink:COLOR:CMYK:Process:0.030000,0.351000,0.000000,0.000000><H108-Yellow:COLOR:CMYK:Process:0.150000,0.000000,0.800000,0.000000><H121-Orange:COLOR:CMYK:Process:0.000000,0.150000,0.800000,0.050000><H122-Pink:COLOR:CMYK:Process:0.150000,0.550000,0.000000,0.000000><H124-Pink:COLOR:CMYK:Process:0.000000,0.500000,0.150000,0.000000><H125-Pink:COLOR:CMYK:Process:0.000000,0.600000,0.351000,0.000000><H130-Orange:COLOR:CMYK:Process:0.000000,0.400000,0.800000,0.000000><H132-Rose:COLOR:CMYK:Process:0.000000,0.700000,0.300000,0.000000><H134-Magenta:COLOR:CMYK:Process:0.100000,0.700000,0.000000,0.000000><H135-Red:COLOR:CMYK:Process:0.050000,0.800000,0.750000,0.000000><H136-Red:COLOR:CMYK:Process:0.150000,1.000000,0.650000,0.000000>>
<DefineParaStyle:Normal=<Nextstyle:Normal><cTypeface:57 Condensed><cSize:10.000000><cAutoPairKern:Optical><cLigatures:0><cBaselineShift:-0.000000><pHyphenationLadderLimit:0><pAutoLeadPercent:1.204987><cLeading:12.000000><pMinCharBeforeHyphen:3><pShortestWordHyphenated:6><pHyphenationZone:0.000000><cFont:Univers><pMaxWordSpace:2.500000><pMinWordSpace:0.750000><pMaxLetterspace:0.039993><cHang:Baseline><pRuleAboveColor:Black><pRuleAboveTint:100.000000><pRuleBelowColor:Black><pRuleBelowTint:100.000000>>
<DefineParaStyle:amtimes=<BasedOn:Normal><Nextstyle:amtimes><cSize:11.000000><cAutoPairKern:Metrics><cTracking:2><pTextComposer:HL Single><cLeading:12.500000><pHyphenation:0><pTabRuler:13.000000\,Char\,\:\,0\, \;>>
<DefineParaStyle:num-name=<BasedOn:Normal><Nextstyle:num-name><cColor:Grey80><cTypeface:Heavy><cSize:12.000000><cStrokeWeight:0.200000><cTracking:100><cCase:All Caps><cStrokeColor:COLOR\:CMYK\:Process\:0.000000\,0.000000\,0.000000\,1.000000><cFont:Futura><pRuleAboveStroke:0.250000><pRuleAboveOffset:12.900000><pRuleAboveLeftIndent:-24.000000><pRuleAboveOn:1>>
<DefineParaStyle:days-dest=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:linenumber=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:linesnumbers=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:days=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:dayslines=<BasedOn:Normal><Nextstyle:days-dest>>
<DefineParaStyle:dropcaphead=<BasedOn:Normal><Nextstyle:dropcaphead>>
<DefineParaStyle:dropcapheadmany=<BasedOn:Normal><Nextstyle:dropcapheadmany>>
<DefineParaStyle:noteonly=<BasedOn:Normal><Nextstyle:noteonly><pBodyAlignment:Center>>
<DefineParaStyle:pmtimes=<BasedOn:amtimes><Nextstyle:pmtimes><cTypeface:67 Bold Condensed>>
<DefineParaStyle:sidenotes=<BasedOn:Normal><Nextstyle:sidenotes><pSpaceAfter:6.000000><pKeepParaTogether:1><pKeepLines:1><pHyphenationWeight:3>>
<DefineParaStyle:bottomnotes=<BasedOn:Normal><Nextstyle:bottomnotes><cSize:9.000000><cLeading:10.000000>>
<DefineCharStyle:Bold=<Nextstyle:Bold><cTypeface:67 Bold Condensed>>
EOF

    $starttext =~ s/\n/\r/g;    #CRs rather than LFs for Mac programs

    $starttext =~ s/\r$//;      # strip trailing newline

    return $starttext;

    # these are the definitions out of a test tagged file. The specific values
    # are intended to be overridden by the InDesign import routine.

} ## tidy end: sub start_with_tables :

sub underline {
    my $text = shift;
    return "<CharStyle:Underline>$text<CharStyle:>";
}

sub bold {
    my $text = shift;
    return "<CharStyle:Bold>$text<CharStyle:>";
}

sub parastyle {

    my ( $style, @text ) = @_;

    my $text = join( "", @text );

    return "<ParaStyle:$style>$text";

}

sub charstyle {
    my ( $style, @text ) = @_;
    my $text = join( "", @text );
    return "<CharStyle:$style>$text";
}

sub nocharstyle {
    return "<CharStyle:>";
}

sub dropcapchars {
    my $chars = shift;
    return "<pdcc:$chars>";
}

sub punctuationspace { return '<0x2008>' }

sub thinspace { return '<0x2009>' }

sub bullet { return '<0x2022>' }

sub boxbreak {
    return "<cNextXChars:Box>\r<cNextXChars:>";
}

sub superscript {
    return "<cPosition:Superscript>@_<cPosition:>";
}

sub nbsp {
    return '<0x00A0>';
}

sub endash {
    return '<0x2013>';
}

sub emdash {
    return '<0x2014>';
}

sub softreturn {
    return "\n";    # this really is an \n, as opposed to the usual \r
}

sub color {
    my ( $color, @text ) = @_;
    my $text = join( "", @text );
    return "<cColor:$color>$text<cColor:>";
}

sub emspace {
    return '<0x2003>';
}

sub enspace {
    return '<0x2002>';
}

sub nonjoiner {
    return '<0x200C>';
}

sub thirdspace {
    return '<0x2004>';
}

sub hairspace {
    return '<0x200A>';
}

sub discretionary_lf {
    return '<0x200B>';
}

sub combiside {
    my $num = combichar( +shift );
    return charstyle( 'sidenum', $num ) . nocharstyle;
}

sub combifootnote {
    my $num = combichar( +shift );
    return charstyle( 'footnum', $num ) . nocharstyle;
}

sub combichar {

    my $num = shift;

    if ( $num < 1 or $num > 99 or $num != int($num) ) {
        croak "invalid footnote '$num'";
    }

    if ( $num < 20 ) {
        $num = (qw(p q w e r t y u i o a s d f g h j k l ;))[$num];
        # 1 through 19
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

} ## tidy end: sub combichar :

1;
