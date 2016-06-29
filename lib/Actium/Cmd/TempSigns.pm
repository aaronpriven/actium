package Actium::Cmd::TempSigns 0.010;

use Actium::Preamble;
use autodie;

use Actium::O::Folder;
use Actium::O::DateTime;

use Actium::Text::InDesignTags;
const my $IDT     => 'Actium::Text::InDesignTags';
const my $HARDRET => Actium::Text::InDesignTags::->hardreturn_esc;

sub OPTIONS {
    return qw/actiumfm/;
}

my %i18n;
my $env;

sub START {

    my $class = shift;
    $env = shift;

    my $config_obj = $env->config;

    my $i18n_cry = $env->crier->cry('Fetching i18ns from database');

    my $actium_db = $env->actiumdb;

    %i18n = %{ $actium_db->all_in_columns_key(qw(I18N en es zh)) };

    $i18n_cry->done;

    # perhaps not the *best* way of specifying these

    my @signs = qw(
      su16_1
      su16_5
      su16_55
      su16_56
      su16_57
      su16_58
      su16_59
      su16_60
      su16_61
      su16_62
      su16_63
    );

    my $output_cry = $env->crier->cry('Outputting data to tempsigns.txt');

    my $dt = Actium::O::DateTime::->new(
        #datetime => $str,
        ymd => [ 2016, 06, 26 ],
        #pattern  => '%Y-%m-%d'
    );

    my $word = 'service_changes_effective_colon';

    my $en     = $i18n{$word}{en} . " " . $dt->full_en;
    my $es     = $i18n{$word}{es} . " " . $dt->full_es;
    my $zh     = $i18n{$word}{zh};
    my $zhdate = $dt->full_zh ;
    $zhdate = $IDT->encode_high_chars($zhdate);
    $zhdate = _zh_phrase( $zhdate);
    $zh =~ s/\%s/$zhdate/;

    my $dates
      = $IDT->parastyle('Text16') . join( $HARDRET, $en, $es, $zh ) . $HARDRET;

    my $folder = Actium::O::Folder::->new('/Users/apriven/Desktop');
    my $ofh    = $folder->open_write('tempsigns.txt');

    print $ofh $IDT->start;
    my @signtexts;

    foreach my $sign (@signs) {
        my $signnum = $sign;
        $signnum =~ s/.*?_//;
        push @signtexts,
            $dates
          . _translate_graf( $sign, 'Text16' )
          . ( $IDT->hardreturn x 2 )
          . $IDT->parastyle('Text8')
          . "Sign $signnum";

    }

    print $ofh join( $IDT->boxbreak, @signtexts );

    $output_cry->done;

    return;
} ## tidy end: sub START

sub _translate_graf {
    my $i18n_id  = shift;
    my $style    = shift;
    my $zh_style = shift // 'ChineseBold';

    \my %translations = _translate($i18n_id);

    return
        _para($style)
      . $translations{en}
      . $HARDRET
      . $translations{es}
      . $HARDRET
      . _zh_phrase( $translations{zh}, $zh_style );

}

sub _para {
    my $para = shift;
    #$para = "A-$para";    # allows find-and-replace to B-, C-, etc.
    return $IDT->parastyle($para) . join( $EMPTY_STR, @_ );
}

sub _translate {
    my $i18n_id      = shift;
    my %translations = %{ $i18n{$i18n_id} };
    return \%translations;

}

sub _translate_phrase {

    my $i18n_id = shift;
    \my %translations = _translate($i18n_id);

    $translations{zh} = _zh_phrase( $translations{zh} );

    my $nbsp   = $IDT->nbsp;
    my $joiner = $IDT->nbsp . $IDT->bullet . $SPACE;

    s/ /$nbsp/g foreach ( values %translations );
    return join( $joiner, @translations{qw/en es zh/} );
}

sub _zh_phrase {
    my $phrase = shift;
    my $zh_style = shift // 'ChineseBold';

    $phrase =~ s/((?:<0x[[:xdigit:]]+>)+)/<CharStyle:$zh_style>$1<CharStyle:>/g;
    $phrase =~ s/<CharStyle:> +<CharStyle:$zh_style>/ /g;

    return $phrase;

}

1;

