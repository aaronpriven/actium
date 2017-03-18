sub agency_effective_date_indd {
    my $self      = shift;
    my $i18n_id   = shift;
    my $color     = shift;
    my $metastyle = 'Bold';

    my $cachekey = "$i18n_id|$color";

    state $cache;
    return $cache->{$cachekey} if exists $cache->{$cachekey};

    my $dt         = $self->effective_date(agency => $DEFAULT_AGENCY);
    my $i18n_row_r = $self->i18n_row_r($i18n_id);

    require Actium::Text::InDesignTags;
    const my $nbsp => $IDT->nbsp;

    my @effectives;
    foreach my $lang (@ALL_LANGUAGES) {
        my $method = "long_$lang";
        my $date   = $dt->$method;
        if ( $lang eq 'en' ) {
            $date =~ s/ /$nbsp/g;
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

    return $cache->{$cachekey} = join( $IDT->hardreturn, @effectives );

} ## tidy end: sub agency_effective_date_indd
