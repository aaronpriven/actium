#!/ActivePerl/bin/perl

# bagtext

use warnings;
use 5.012;

use sort ('stable');

# add the current program directory to list of files to include
use FindBin('$Bin');
use lib ( $Bin, "$Bin/../bin" );

use Actium::Sorting::Line ('sortbyline');
use Actium::Constants;
use Actium::Files::Merge::FPMerge (qw(FPread FPread_simple));

use List::MoreUtils ('natatime');

use POSIX qw(ceil);

use IDTags;

# don't buffer terminal output
$| = 1;

my $helptext = <<'EOF';
bagtext makes the text for the bags.
EOF

{
    no warnings('once');
    if ($Actium::Eclipse::is_under_eclipse) { ## no critic (ProhibitPackageVars)
        @ARGV = Actium::Eclipse::get_command_line();
    }
}

my $intro = 'bagtext -- makes text for bags';

my $CR = "\r";

my %height_of = (
    numbers => 3,
    AL      => 13.375,
    AS      => 15.175,
    RL      => 13.375,
    CL      => 17.875,
    margin  => 0.75,
    RS      => 16.375,
);

use Actium::Options;
use Actium::Folders::Signup;

Actium::Options::init_options();

my $signup = Actium::Folders::Signup->new();
chdir $signup->path();

my %output_dispatch = (
    AL => \&al_output,
    RL => \&rl_output,
    CL => \&cl_output,
    AS => \&as_output,
    RS => \&rs_output,
);

my $date = 'December' . IDTags::nbsp() . '18';

my ( @pink, @notpink );

open my $tobag, '<', 'compare/tobag-order.txt' or die $!;
while (<$tobag>) {
    chomp;
    #    my ($type,       $stopid,  $desc,         $numadded, $added,
    #        $numremoved, $removed, $numunchanged, $unchanged

    my @fields = split(/\t/);
    foreach (@fields) {
        s/^"//;
        s/"$//;
    }

    my ($series, $order,   $stopid,    $desc, $type,
        $added,  $removed, $unchanged, $explanation
    ) = @fields;

    my $thistext = '';

    open my $bagfh, '>', \$thistext or die $!;

    print $bagfh para('Teeny');

    print $bagfh "$series ($order)";
    print $bagfh IDTags::emspace, $desc;
    print $bagfh IDTags::emspace, "Stop $stopid$CR";

    my ( @added, @removed, @unchanged, @current );

    @added     = split( /,/, $added )     if $added;
    @removed   = split( /,/, $removed )   if $removed;
    @unchanged = split( /,/, $unchanged ) if $unchanged;
    @current = sortbyline( @removed, @unchanged );

    my %added   = prepary(@added);
    my %removed = prepary(@removed);
    my %current = prepary(@current);

    next unless ( $type ~~ [qw(AS RS AL RL CL)] );

    my ( $text, $length )
      = $output_dispatch{$type}
      ->( \%added, \%removed, \%current, $explanation );

    print $bagfh $text;

    print $bagfh para( 'Questions',
'Want more info? Visit www.actransit.org or call 511 (and say, <0x201C>AC Transit.<0x201D>)'
    );

    close $bagfh;

    if ( $type eq 'RS' ) {
        push @pink, $thistext;
    }
    else {
        push @notpink, $thistext;

    }

}    ## <perltidy> end foreach my $file (...)

my $number_in_a_group = 1e6;

open my $pink, '>', 'compare/pinkbags.txt' or die "$!";

print $pink start();
foreach (@pink) {
    print $pink $_, IDTags::boxbreak;
}
close $pink;

open my $notpink, '>', 'compare/bags.txt' or die "$!";

print $notpink start();
foreach (@notpink) {
    print $notpink $_, IDTags::boxbreak;
}
close $notpink;

say scalar @pink, " pink bags and ", scalar @notpink, " regular bags.";

sub al_output {
    my %added       = %{ +shift };
    my %removed     = %{ +shift };
    my %current     = %{ +shift };
    my $explanation = shift;

    my $r = current(%current);

    if ($explanation) {
        $r .= explanation($explanation);
    }

    else {
        $r .= para('FirstLineIntro');
        $r .= "Effective $date, $added{these} will ";
        $r .= IDTags::underline('also');
        $r .= " stop here:$CR";
        $r .= para( 'HighlightedLines', $added{lines} ) . $CR;
    }

    my $length = $added{len} + $current{len} + $height_of{AL};

    return $r, $length;

} ## tidy end: sub al_output

sub rl_output {
    my %added       = %{ +shift };
    my %removed     = %{ +shift };
    my %current     = %{ +shift };
    my $explanation = shift;

    my $r = current(%current);

    if ($explanation) {
        $r .= explanation($explanation);
    }

    else {
        $r .= para('FirstLineIntro');

        $r .= "Effective $date, $removed{these} will ";
        $r .= IDTags::underline('not');
        $r .= " stop here:$CR";
        $r .= para( 'HighlightedLines', $removed{lines} ) . $CR;
    }
    my $length = $removed{len} + $current{len} + $height_of{RL};
    return $r, $length;

} ## tidy end: sub rl_output

sub cl_output {
    my %added       = %{ +shift };
    my %removed     = %{ +shift };
    my %current     = %{ +shift };
    my $explanation = shift;

    my $r = current(%current);

    if ($explanation) {
        $r .= explanation($explanation);
    }

    else {

        $r .= para('FirstLineIntroSm');
        $r .= "Effective $date, $added{these} will ";
        $r .= IDTags::underline('begin') . " stopping here:$CR";
        $r .= para( 'HighlightedLines', $added{lines} ) . $CR;
        $r .= para('LineIntroSm');
        $r .= ucfirst("$removed{these} will ");
        $r .= IDTags::underline('not') . " stop here:$CR";
        $r .= para( 'HighlightedLines', $removed{lines} ) . $CR;
    }
    my $length = $added{len} + $removed{len} + $current{len} + $height_of{CL};
    return $r, $length;

} ## tidy end: sub cl_output

sub as_output {
    my %added       = %{ +shift };
    my %removed     = %{ +shift };
    my %current     = %{ +shift };
    my $explanation = shift;

    my $r = para( 'NewBusStop', "NEW " . IDTags::softreturn . "BUS STOP$CR" );
    if ($explanation) {
        $r .= explanation($explanation);
    }

    else {
        $r .= para('FirstLineIntro');
        $r .= "Effective $date, $added{these} will stop here:$CR";
        $r .= para( 'HighlightedLines', $added{lines} ) . $CR;
    }
    my $length = $added{len} + $height_of{AS};
    return $r, $length;

} ## tidy end: sub as_output

sub rs_output {
    my %added       = %{ +shift };
    my %removed     = %{ +shift };
    my %current     = %{ +shift };
    my $explanation = shift;
    my $length      = $current{len} + $height_of{RS};

    my $r = current(%current);
    if ($explanation) {
        $r .= explanation($explanation);
    }

    else {
        $r
          .= para( 'Removed',
            "Effective $date, this bus stop will be removed." )
          . $CR;
    }

    return $r, $length;

} ## tidy end: sub rs_output

sub explanation {
    my $explanation = shift;
    my $r           = para('FirstLineIntroSm');
    $r .= "Effective $date:$CR";
    $r .= para( 'HighlightedLines', $explanation ) . $CR;
    return $r;

}

sub para {

    return IDTags::parastyle(@_);

}

sub current {
    my %current = @_;
    my $r = para( 'Current', "Current $current{word} at this stop:$CR" );
    $r .= para( 'CurrentLines', $current{lines} ) . $CR;
    return $r;
}

sub prepary {

    my %return;

    if ( scalar(@_) == 1 ) {
        $return{word}      = 'line';
        $return{these}     = 'this line';
        $return{thesestop} = 'this line stops';
    }
    else {
        $return{word}      = 'lines';
        $return{these}     = 'these lines';
        $return{thesestop} = 'these lines stop';
    }

    #my $chars = join( $EMPTY_STR, @_ );
    #my $numbers = ( $chars =~ tr/0-9// );
    #my $letters = ( $chars =~ tr/A-Z// );
    #my $charwidth = $numbers + $letters * 1.33 + $#_;
    #my $textlines = ceil( $charwidth / 10 ) - 1;    # starts with 0

    #my $sum       = 0;
    #my $textlines = 0;    # one line of numbers is assumed in
    #                      # $height{AL}, $height{RL}, etc.

    my $bigsep = IDTags::enspace . IDTags::discretionary_lf;
    #my $smallsep = $bigsep;
    my $smallsep
      = IDTags::thirdspace
      . ( IDTags::hairspace() x 2 )
      . IDTags::discretionary_lf;

    my @textlines;
    my $thisline = $EMPTY_STR;

    my $line_width = 11;

    foreach my $i ( 0 .. $#_ - 1 ) {

        my $chars = $_[$i];

        if ( charwidth( $thisline . $chars ) <= $line_width ) {
            # less than or equal to than line length
            $thisline .= $chars . $SPACE;
        }
        else {
            push @textlines, $thisline;
            $thisline = $chars . $SPACE;
        }

    }

    # last item

    my $chars = $_[-1] || $EMPTY_STR;

    if ( charwidth( $thisline . $chars ) <= ($line_width) ) {
        # less than or equal to than line length
        push @textlines, $thisline . $chars;
    }
    else {
        push @textlines, $thisline, $chars;
    }

    $return{'len'} = $#textlines * $height_of{numbers};

    my $sep = $bigsep;

    foreach (@textlines) {
        if ( charwidth($_) >= $line_width - 1 ) {
            $sep = $smallsep;
            last;
        }
    }

    my $lines = join( $EMPTY_STR, @textlines );
    $lines =~ s/$SPACE/$sep/g;
    $return{lines} = $lines;

    #$return{lines} = join( $separator, @_ );

    return (%return);

}    ## <perltidy> end sub prepary

sub start {
    return "<ASCII-MAC>$CR<Version:6><FeatureSet:InDesign-Roman>";
}

sub charwidth {
    my $chars = shift;

    my $letters = ( $chars =~ tr/A-Z// );

    my $nonletters = length($chars) - $letters;

    return ( $letters * 1.34 + $nonletters );

}
