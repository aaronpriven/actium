# /Actium/Cmd/Bags2.pm

# service change bag decals from Excel and into a script

package Actium::Cmd::Bags2 0.010;

use Actium::Preamble;
use autodie;

use Actium::Cmd::Config::ActiumFM ('actiumdb');
use Actium::Cmd::Config::Signup   (qw<signup oldsignup>);
use Actium::O::2DArray;

use Actium::Text::InDesignTags;
const my $IDT     => 'Actium::Text::InDesignTags';
const my $HARDRET => Actium::Text::InDesignTags::->hardreturn_esc;

sub OPTIONS {
    my ( $class, $env ) = @_;
    return ( Actium::Cmd::Config::ActiumFM::OPTIONS($env), );
}

my %i18n;
my $env;

sub START {

    my $class = shift;
    $env = shift;

    my $config_obj = $env->config;

    my $i18n_cry = $env->crier->cry('Fetching i18ns from database');

    my $actium_db = actiumdb($env);

    %i18n = %{ $actium_db->all_in_columns_key(qw(I18N en es zh)) };

    $i18n_cry->done;

    my $read_cry = $env->crier->cry('Reading sheet');

    my $excelfile = $env->argv_idx(0);

    my ( $outfile, $oldext ) = u::file_ext($excelfile);
    $outfile .= "-bags.txt";

    my $list    = Actium::O::2DArray->new_from_xlsx($excelfile);
    my @headers = $list->shift_row;

    my %col;
    for my $i ( 0 .. $#headers ) {
        my $header = $headers[$i];
        $col{$header} = $i;
    }

    $read_cry->done;

    my $output_cry = $env->crier->cry('Processing and outputting data');

    open( my $outfh, '>:encoding(UTF-8)', $outfile );

    say $outfh "Action\tStopID\tMainbox\tInstruction";

    for my $stop_r ( @{$list} ) {
        my $out_line = _process_stop( $stop_r, \%col );
        next unless defined $out_line;
        say $outfh $out_line;
    }

    $output_cry->done;

    return;
} ## tidy end: sub START

sub _process_stop {

    \my @stop = shift;
    \my %col  = shift;

    my $stopid    = $stop[ $col{StopID} ];
    my @added     = split( ' ', $stop[ $col{Added} ] );
    my @removed   = split( ' ', $stop[ $col{Removed} ] );
    my @unchanged = split( ' ', $stop[ $col{Unchanged} ] );
    my $bagtext   = $stop[ $col{'Bag Text Number'} ];
    $bagtext = $EMPTY unless $bagtext =~ /\w/;
    my $desc     = $stop[ $col{'Stop Description'} ];
    my $bagortmp = $stop[ $col{'Bag/ Tmp?'} ];

    return unless u::feq( $bagortmp, 'B' );

    my $num_added     = scalar @added;
    my $num_removed   = scalar @removed;
    my $num_unchanged = scalar @unchanged;

       #<<<
        my $action
          = $num_added   && $num_removed && $num_unchanged ? 'CL'
          : $num_added   && $num_removed                   ? 'XL'
          : $num_added   && $num_unchanged                 ? 'AL'
          : $num_removed && $num_unchanged                 ? 'RL'
          : $num_added                                     ? 'AS'
          :                                                  'RS';
        #>>>

    my $mainbox;

    if ( $action eq 'AL' ) {
        $mainbox
          = _lines( 'line_stop', 'CurrentLines', @unchanged )
          . $HARDRET
          . _lines( 'also_stop', 'AddedLines', @added );
    }
    elsif ( $action eq 'RL' ) {
        $mainbox
          = _lines( 'line_stop', 'CurrentLines', @unchanged )
          . $HARDRET
          . _lines( 'not_stop', 'RemovedLines', @removed );
    }
    elsif ( $action eq 'XL' ) {
        $mainbox = _lines( 'begin_stop', 'AddedLines', @added );
        $mainbox .= $HARDRET;
        $mainbox .= _lines( 'not_stop', 'RemovedLines', @removed );
    }
    elsif ( $action eq 'CL' ) {
        $mainbox
          = _lines( 'line_stop', 'CurrentLines', @unchanged )
          . $HARDRET
          . _lines( 'begin_stop', 'AddedLines', @added )
          . $HARDRET
          . _lines( 'not_stop', 'RemovedLines', @removed );
    }
    elsif ( $action eq 'AS' ) {
        $mainbox
          = _translate_graf( 'new_bus_stop', 'NewBusStop' )
          . $HARDRET
          . _lines_first( 'begin_stop', 'AddedLines', @added );
    }
    else {    # action is 'RS'
        $mainbox
          = _lines( 'current_stop', 'CurrentLines', @removed )
          . $HARDRET
          . _translate_graf( 'stop_removed', 'Removed' )
          . $HARDRET;
          # extra return to add more space after removed
    }

    if ( defined $bagtext and $bagtext !~ /\A\s*\z/ ) {
        $mainbox .= $HARDRET . _translate_graf( $bagtext, 'Note' , 'ChineseMedium');
    }

    return "$action\t$stopid\t$mainbox\t$desc";

} ## tidy end: sub _process_stop

sub _translate_graf {
    my $i18n_id = shift;
    my $style   = shift;
    my $zh_style = shift // 'ChineseBold' ;

    \my %translations = _translate($i18n_id);

    return
        _para($style)
      . $translations{en}
      . $HARDRET
      . $translations{es}
      . $HARDRET
      . _zh_phrase($translations{zh} , $zh_style);

}

sub _translate {
    my $i18n_id      = shift;
    my %translations = %{ $i18n{$i18n_id} };
    return \%translations;

}

sub _lines_first {
   unshift @_, 'FirstLineIntro';
   goto &_lines_with_introstyle; 
    
}

sub _lines {
   unshift @_, 'LineIntro';
   goto &_lines_with_introstyle; 
}
    

sub _lines_with_introstyle {
    my $introstyle = shift;
    my $i18n_id = shift;    # of intro
    my $style   = shift;    # of lines
    my @lines   = @_;

    $i18n_id .= "_pl" if @lines != 1;    # pluralize

    my $translations = _translate_phrase( $i18n_id );
    
    my $return =
      _para($introstyle) . 
       $translations
      . $HARDRET
      . _para($style)
      . ( join( $SPACE, @lines ) );
      
    return $return;

}

sub _translate_phrase {

    my $i18n_id = shift;
    \my %translations = _translate($i18n_id);

    $translations{zh} = _zh_phrase($translations{zh});

    my $nbsp   = $IDT->nbsp;
    my $joiner = $IDT->nbsp . $IDT->bullet . $SPACE;

    s/ /$nbsp/g foreach ( values %translations );
    return join( $joiner, @translations{qw/en es zh/} );
}

sub _para {
    my $para = shift;
    $para = "A-$para";    # allows find-and-replace to B-, C-, etc.
    return $IDT->parastyle($para) . join( $EMPTY_STR, @_ );
}

sub _zh_phrase {
    my $phrase = shift;
    my $zh_style = shift // 'ChineseBold';

    $phrase =~ s/((?:<0x[[:xdigit:]]+>)+)/<CharStyle:$zh_style>$1<CharStyle:>/g;
    $phrase =~ s/<CharStyle:> +<CharStyle:$zh_style>/ /g;

    return $phrase;

}

1;
