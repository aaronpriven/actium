# TaggedText.pm
# vimcolor: #000020

# This contains Quark and Indesign tags

package TaggedText;

use strict;
our (@ISA ,@EXPORT_OK ,$VERSION);

use Exporter;
@ISA = ('Exporter');
@EXPORT_OK = qw( parastyle %quark %indesign %tags);

our (%quark , %indesign , %tags);
         
%quark = (
BIGSPACE => '<\q><\q>' ,
BOXBREAK => '<\\b>' ,
ST => '<f"Zapf Dingbats">H<f$>',
SD => '<f"Carta">V<f$>',
SH => '<f"Festive"><\#105><f$>',
'*' => '<f"Transportation"><\#121><f$>',
PARASTYSTART => '<@' ,
PARASTYEND => ':' ,
CHARSTYSTART => '<@' ,
CHARSTYEND => ':' ,
NOBREAKSPC => '<\!s>' ,
BOLDFONT => '<f"HelveticaNeue BoldCond">',
NOBOLDFONT => '<f$>' ,
START => '' ,
);

%indesign = (
BIGSPACE => '<0x2002>' ,
BOXBREAK => "<cNextXChars:Box>\r<cNextXChars:>" ,
ST => '<cFont:Zapf Dingbats>H<cfont:>',
SD => '<cFont:Carta>V<cFont:>',
SH => '<cFont:Festive">i<cFont:>',
'*' => '<cFont:Transportation>y<cFont:>',
PARASTYSTART => '<ParaStyle:' ,
PARASTYEND => '>',
CHARSTYSTART => '<CharStyle:' ,
CHARSTYEND => '>',
NOBREAKSPC =>  '<0x00A0>' ,
BOLDFONT => '<CharStyle:pmtimes>' ,
NOBOLDFONT => '<CharStyle:>' ,
START => "<ASCII-MAC>\r" ,
);

$indesign{START} .= "<DefineParaStyle:$_=>" foreach 
    ( qw(headnum headname headdest headdays tpnum tpname times timesblank legend) );

$indesign{START} .= "<DefineCharStyle:$_=>" foreach 
    ( qw(pmtimes) );



#$indesign{START} = `cat /tmp/z`;


%tags = %indesign;

sub preparequark { %tags = %quark }

sub prepareindesign { %tags = %indesign }

sub parastyle { 
   return $tags{PARASTYSTART} . $_[0] . $tags{PARASTYEND}
}

sub charstyle { 
   return $tags{CHARSTYSTART} . $_[0] . $tags{CHARSTYEND}
}

1;
