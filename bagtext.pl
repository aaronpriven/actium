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

my $bagtextdir = $signup->subfolder('bagtexts');

# retrieve data
my ( @stops, %stops );
FPread_simple( 'Stops.csv', \@stops, \%stops, 'PhoneID' );

my %compare;
open my $comp, '<', 'compare/comparestops-x.txt';
while (<$comp>) {
    chomp;
    my ($type,       $stopid,  $desc,         $numadded, $added,
        $numremoved, $removed, $numunchanged, $unchanged
    ) = split(/\t/);
    $compare{$stopid} = {
        Type      => $type,
        Added     => $added,
        Removed   => $removed,
        Unchanged => $unchanged,
    };
}

close $comp;

my %output_dispatch = (
    AL => \&al_output,
    RL => \&rl_output,
    CL => \&cl_output,
    AS => \&as_output,
    RS => \&rs_output,
);

my $stopcount = 0;
my $filecount = 0;

my ( %texts_of, %texts_of_type );

my %seen_length;

#my %decalroutes;

#$decalroutes{$_} = 1 foreach qw(
#  210 211 212 213 214 215 216 217 218 235 305 328 329 332 360 77 81 M SB
#);

my $date = 'March' . IDTags::nbsp() . '27';

foreach my $file (qw(baglist.txt baglist-add.txt baglist-rm.txt)) {

    open my $baglist, '<', "compare/$file";

    while (<$baglist>) {

        chomp;
        my ( $routedir, @thesestopids ) = split(/\t/);
        my $numstops = scalar @thesestopids;

        foreach my $i ( 0 .. $#thesestopids ) {

            my $thistext = '';

            open my $bagtext, '>', \$thistext or die $!;

            $stopcount++;
            my $stopid = $thesestopids[$i];
            my $desc   = $stops{$stopid}{DescriptionF}
              || die "No description for $stopid";
            my $city = $stops{$stopid}{CityF} || die "No city for $stopid";

            print $bagtext para('Teeny');

            print $bagtext "$routedir (", $i + 1, " of $numstops)";
            print $bagtext IDTags::emspace, "$desc, $city";
            print $bagtext IDTags::emspace, "Stop $stopid$CR";

            my $type  = $compare{$stopid}{Type}  || die "No type for $stopid";
            my $added = $compare{$stopid}{Added} || $EMPTY_STR;
            my $removed   = $compare{$stopid}{Removed}   || $EMPTY_STR;
            my $unchanged = $compare{$stopid}{Unchanged} || $EMPTY_STR;

            my ( @added, @removed, @unchanged, @current );

            @added     = split( /,/, $added )     if $added;
            @removed   = split( /,/, $removed )   if $removed;
            @unchanged = split( /,/, $unchanged ) if $unchanged;
            @current = sortbyline ( @removed, @unchanged );

            my %added   = prepary(@added);
            my %removed = prepary(@removed);
            my %current = prepary(@current);
            
            next unless ($type ~~ [ qw(AS RS AL RL CL) ] );

            my ( $text, $length )
              = $output_dispatch{$type}->( \%added, \%removed, \%current );
              
            print $bagtext $text;

            print $bagtext para( 'Questions',
'Want more info? Visit www.actransit.org or call 511 (and say, <0x201C>AC Transit.<0x201D>)'
            );

            close $bagtext;

            $length += $height_of{margin};

            my $outtype = $type;

            if ( $type eq 'AL' or $type eq 'RL' or $type eq 'CL' ) {
                $outtype = 'C';
                my $route = substr($routedir,0,index($routedir,'-'));
                #$outtype = 'CD' if $decalroutes{$route};

            }

            # IGNORE HEIGHTS FOR PRINTING ON BAGS
            #$length = 36;

            $seen_length{"$length-$outtype"}++;

            push @{ $texts_of{$outtype}{$length} }, $thistext;

            #push @{$texts_of_length{ ceil(($length)/2) * 2}} , $thistext;
            # round to nearest 2 inches.

            push @{ $texts_of_type{$type} }, $thistext;

        } ## <perltidy> end foreach my $i ( 0 .. $#thesestopids)

    } ## <perltidy> end while (<$baglist>)

    close $baglist;

} ## <perltidy> end foreach my $file (...)

open my $sample, '>', 'bagtexts/sample.txt' or die $!;
print $sample start();

if (0) {
for my $type (qw(AL RL CL AS RS)) {

    my %seen;

    for ( 0 .. 15 ) {
        my $random = rand( $#{ $texts_of_type{$type} } );
        redo if $seen{$random};
        $seen{$random} = 1;
        print $sample $texts_of_type{$type}[$random], IDTags::boxbreak;

    }

}
}

my $number_in_a_group = 1e6;

while ( my ( $outtype, $lengths_of_r ) = each %texts_of ) {

    while ( my ( $length, $texts_r ) = each %{$lengths_of_r} ) {

        my $texts_count = scalar @$texts_r;

   #    if ($texts_count > 60) {
   #       my @samples = @{$texts_r}[0 , 15 , 30 , 45 , 60];
   #       print $sample join( IDTags::boxbreak , @samples) , IDTags::boxbreak;
   #    }
   #    elsif ($texts_count > 8) {
   #       my @samples = @{$texts_r}[0 , 2 , 4 , 6 , 8];
   #       print $sample join( IDTags::boxbreak , @samples) , IDTags::boxbreak;
   #    }

        my $fname = "$outtype-$length";

        if ( $texts_count > $number_in_a_group ) {

            my $suffix = 'a';

            my $it = natatime $number_in_a_group, @$texts_r;
            while ( my @texts = $it->() ) {

                open my $bagtext, '>', "bagtexts/$fname-$suffix.txt" or die $!;
                print $bagtext start();
                foreach (@texts) {
                    print $bagtext $_ , IDTags::boxbreak , $_ , IDTags::boxbreak ;
		}
                #print $bagtext join( IDTags::boxbreak, @texts );
                close $bagtext;

                $suffix++;    # alphabetic auto-increment

            }

        }
        else {

            open my $bagtext, '>', "bagtexts/$fname.txt" or die $!;

            print $bagtext start();
            #print $bagtext join( IDTags::boxbreak, @{$texts_r} );
            foreach (@{$texts_r}) {
                print $bagtext $_ , IDTags::boxbreak ;
            }

            close $bagtext;
        }

    } ## <perltidy> end while ( my ( $length, $texts_r...))

} ## <perltidy> end while ( my ( $outtype, $lengths_of_r...))

close $sample;

# end of main

{
    no warnings 'numeric';

    foreach ( sort { $a <=> $b } keys %seen_length ) {

        say $_ , ": ", $seen_length{$_};

    }

}

sub al_output {
    my %added   = %{ +shift };
    my %removed = %{ +shift };
    my %current = %{ +shift };

    my $r = current(%current);

    $r .= para('FirstLineIntro');
    $r .= "Effective $date, $added{these} will ";
    $r .= IDTags::underline('also');
    $r .= " stop here:$CR";
    $r .= para( 'HighlightedLines', $added{lines} ) . $CR;

    my $length = $added{len} + $current{len} + $height_of{AL};

    return $r, $length;

}

sub rl_output {
    my %added   = %{ +shift };
    my %removed = %{ +shift };
    my %current = %{ +shift };

    my $r = current(%current);
    $r .= para('FirstLineIntro');
    $r .= "Effective $date, $removed{these} will ";
    $r .= IDTags::underline('not');
    $r .= " stop here:$CR";
    $r .= para( 'HighlightedLines', $removed{lines} ) . $CR;
    my $length = $removed{len} + $current{len} + $height_of{RL};
    return $r, $length;

}

sub cl_output {
    my %added   = %{ +shift };
    my %removed = %{ +shift };
    my %current = %{ +shift };

    my $r = current(%current);

    $r .= para('FirstLineIntroSm');
    $r .= "Effective $date, $added{these} will ";
    $r .= IDTags::underline('begin') . " stopping here:$CR";
    $r .= para( 'HighlightedLines', $added{lines} ) . $CR;
    $r .= para('LineIntroSm');
    $r .= ucfirst("$removed{these} will ");
    $r .= IDTags::underline('not') . " stop here:$CR";
    $r .= para( 'HighlightedLines', $removed{lines} ) . $CR;
    my $length = $added{len} + $removed{len} + $current{len} + $height_of{CL};
    return $r, $length;

}

sub as_output {
    my %added   = %{ +shift };
    my %removed = %{ +shift };
    my %current = %{ +shift };

    my $r = para( 'NewBusStop', "NEW " . IDTags::softreturn . "BUS STOP$CR" );
    $r .= para('FirstLineIntro');
    $r .= "Effective $date, $added{these} will stop here:$CR";
    $r .= para( 'HighlightedLines', $added{lines} ) . $CR;
    my $length = $added{len} + $height_of{AS};
    return $r, $length;

}

sub rs_output {
    my %added   = %{ +shift };
    my %removed = %{ +shift };
    my %current = %{ +shift };
    my $length  = $current{len} + $height_of{RS};

    my $r
      = current(%current)
      . para( 'Removed', "Effective $date, this bus stop will be removed." )
      . $CR;

    return $r, $length;

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
    my $smallsep = IDTags::thirdspace 
                 . ( IDTags::hairspace() x 2 ) . IDTags::discretionary_lf;

    my @textlines;
    my $thisline = $EMPTY_STR;

    my $line_width = 11;

    foreach my $i (0 .. $#_ - 1 ) {

        my $chars = $_[$i];

        if (charwidth ($thisline . $chars) <= $line_width ) {    
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

     if (charwidth ($thisline . $chars) <= ($line_width ) ) {
         # less than or equal to than line length
         push @textlines, $thisline . $chars ;
     }
     else {
         push @textlines, $thisline, $chars;
     }

    $return{'len'} = $#textlines * $height_of{numbers};

    my $sep = $bigsep;

    foreach (@textlines) {
       if (charwidth($_) >= $line_width -1 ) {
          $sep = $smallsep;
          last;
       }
    }

    my $lines = join( $EMPTY_STR, @textlines );
    $lines =~ s/$SPACE/$sep/g;
    $return{lines} = $lines;

    #$return{lines} = join( $separator, @_ );

    return (%return);

} ## <perltidy> end sub prepary

sub start {
    return "<ASCII-MAC>$CR<Version:6><FeatureSet:InDesign-Roman>";
}

sub charwidth {
   my $chars = shift;

   my $letters = ( $chars =~ tr/A-Z// );

   my $nonletters = length($chars) - $letters;
   
   return ( $letters * 1.34 + $nonletters);

}

 

