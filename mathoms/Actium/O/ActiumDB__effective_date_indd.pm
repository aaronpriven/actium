const my @ALL_LANGUAGES => qw/en es zh/;

sub _effective_date_indd {
    my $self   = shift;
    my $dt     = $self->effdate;
    my $is_bsh = shift;

    my $i18n_id = 'effective_colon';

    my $metastyle = 'Bold';

    my $month   = $dt->month;
    my $oddyear = $dt->year % 2;
    my ( $color, $shading, $end );

    # EFFECTIVE DATE and colors
    if ($is_bsh) {
        $color   = $EMPTY;
        $shading = $EMPTY;
        $end     = $EMPTY;
    }
    else {
        $color   = $COLORS{$oddyear};
        $color   = $IDT->color($color);
        $shading = $SHADINGS{ $month . $oddyear };
        $shading = "<pShadingColor:$shading>";
        $end     = '<pShadingColor:>';
    }

    my $retvalue = $IDT->parastyle('sideeffective') . $shading . $color;

    my $i18n_row_r = $Actium::Cmd::MakePoints::actiumdb->i18n_row_r($i18n_id);

    my @effectives;
    foreach my $lang (@ALL_LANGUAGES) {
        my $method = "long_$lang";
        my $date   = $dt->$method;
        if ( $lang eq 'en' ) {
            $date =~ s/ /$NBSP/g;
        }

        $date = $IDT->encode_high_chars_only($date);
        $date = $IDT->language_phrase( $lang, $date, $metastyle );

        my $phrase = $i18n_row_r->{$lang};
        $phrase =~ s/\s+\z//;

        if ( $phrase =~ m/\%s/ ) {
            $phrase =~ s/\%s/$date/;
        }
        else {
            $phrase .= " " . $IDT->discretionary_lf . $date;
        }

        #$phrase = $IDT->language_phrase( $lang, $phrase, $metastyle );

        $phrase =~ s/<CharStyle:Chinese>/<CharStyle:ZH_Bold>/g;
        $phrase =~ s/<CharStyle:([^>]*)>/<CharStyle:$1>$color/g;

        push @effectives, $phrase;

    } ## tidy end: foreach my $lang (@ALL_LANGUAGES)

    return $retvalue . join( $IDT->hardreturn, @effectives ) . $end;

} ## tidy end: sub _effective_date_indd

