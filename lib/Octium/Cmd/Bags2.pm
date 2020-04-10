package Octium::Cmd::Bags2 0.014;

# service change bag decals from Excel and into a script

use Actium;
use Octium;
use autodie;

use Array::2D;

use Octium::Text::InDesignTags;
use Octium::DateTime;
use Octium::Set ('clusterize');

const my $IDT     => 'Octium::Text::InDesignTags';
const my $HARDRET => Octium::Text::InDesignTags::->hardreturn_esc;

sub OPTIONS {
    return qw/actiumdb/;
}

my %i18n;
my ( %workzone_of, %cluster_of );

sub START {

    my @ymd = qw/2020 03 29/;
    my $dt  = Octium::DateTime::->new( ymd => \@ymd );

    my $config_obj = env->config;

    my $i18n_cry = env->cry('Fetching i18ns from database');

    my $actium_db = env->actiumdb;

    %i18n = %{ $actium_db->all_in_columns_key(qw(I18N en es zh)) };

    $i18n_cry->done;

    my $workzone_cry = env->cry('Fetching work zones from database');
    %workzone_of
      = %{ $actium_db->all_in_column_key(qw(Stops_Neue u_work_zone)) };
    $workzone_cry->done;

    my $read_cry = env->cry('Reading sheet');

    my $excelfile = env->argv_idx(0);

    my ( $outfile, $oldext ) = Octium::file_ext($excelfile);
    my $clusterfile = $outfile . '-clusters2.txt';
    $outfile .= "-b2.txt";

    my $list    = Array::2D->new_from_xlsx($excelfile);
    my @headers = $list->shift_row;

    my %col;
    for my $i ( 0 .. $#headers ) {
        my $header = $headers[$i];
        $col{$header} = $i;
    }

    $read_cry->wail( join( " ", keys %col ) );

    $read_cry->done;

    my $output_cry = env->cry('Processing and outputting data');

    open( my $outfh, '>:encoding(UTF-8)', $outfile );

    say $outfh "Action\tStopID\tMainbox\tInstruction";

    # clusterize

    my ( @stopids, @workzones );
    for my $stop_r ( @{$list} ) {
        my $stopid = $stop_r->[ $col{StopID} ];
        push @stopids, $stopid;
        my $workzone = $workzone_of{$stopid} // '';
        push @workzones, $workzone_of{$stopid};
    }

    %cluster_of = %{ clusterize( items => \@workzones, size => 20 ) };

    open( my $clusterfh, '>:encoding(UTF-8)', $clusterfile );
    foreach my $stopid (@stopids) {
        say $clusterfh join( "\t",
            $stopid, $workzone_of{$stopid},
            $cluster_of{ $workzone_of{$stopid} } );
    }

    close $clusterfh;

    # end clusterize

    for my $stop_r ( @{$list} ) {
        my $out_line = _process_stop( $stop_r, \%col, $dt );
        next unless defined $out_line;
        say $outfh $out_line;
    }

    $output_cry->done;

    return;
}    ## tidy end: sub START

sub _process_stop {

    \my @stop = shift;
    \my %col  = shift;
    my $dt = shift;

    my $stopid = $stop[ $col{StopID} ];
    my @added  = split( ' ', $stop[ $col{Added} ] );
    @added = grep !/^BS[DN]$/, @added;
    my @removed = split( ' ', $stop[ $col{Removed} ] );
    @removed = grep !/^BS[DN]$/, @removed;
    my @unchanged = split( ' ', $stop[ $col{Unchanged} ] );
    @unchanged = grep !/^BS[DN]$/, @unchanged;
    my $bagtextid = "sp20-" . $stop[ $col{'StopID'} ];
    $bagtextid = $EMPTY unless $bagtextid =~ /\w/;
    my $bagtext = $stop[ $col{'Text'} ];
    $bagtext = $EMPTY unless $bagtextid =~ /\w/;
    #my $cluster = $stop[ $col{'Work cluster'} ];
    #$cluster =~ s/^c//;

    my $bagortmp = $stop[ $col{'Bag / Temp'} ];

    return unless Actium::feq( $bagortmp, 'B2' );

    my $cluster = $cluster_of{ $workzone_of{$stopid} };
    #my $desc = $stop[ $col{'Stop Description'} ] . "      Work zone $cluster";
    my $desc = $stop[ $col{'Stop Description'} ];

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

        if ( not @removed ) {
            say "$stopid";
            exit 0;
        }
        $mainbox
          = _lines( 'current_stop', 'CurrentLines', @removed )
          . $HARDRET
          . _translate_graf( 'stop_removed', 'Removed' )
          . $HARDRET;
        # extra return to add more space after removed
    }

    #if ( defined $bagtextid and $bagtextid !~ /\A\s*\z/ ) {
    if ( defined $bagtext and $bagtext !~ /\A\s*\z/ ) {
        $mainbox
          .= $HARDRET . _translate_graf( $bagtextid, 'Note', 'ChineseMedium' );
    }

    #$mainbox = _effective_date_indd($dt) . $HARDRET . $HARDRET . $mainbox;
    #$mainbox
    #  = _translate_graf( 'w16_10', 'effectivedate', 'ChineseMedium' )
    #  . $HARDRET
    #  . $HARDRET
    #  . $mainbox;

    return "$action\t$stopid\t$mainbox\t$desc";

}    ## tidy end: sub _process_stop

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

sub _translate {
    my $i18n_id = shift;
    croak "No such id $i18n_id" unless exists $i18n{$i18n_id};
    my %translations = %{ $i18n{$i18n_id} };
    delete $translations{i18n_id};
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
    my $i18n_id    = shift;    # of intro
    my $style      = shift;    # of lines
    my @lines      = @_;

    return $EMPTY if $lines[0] eq 'NONE';

    $i18n_id .= "_pl" if @lines != 1;    # pluralize

    my $translations = _translate_phrase($i18n_id);

    my $return
      = _para($introstyle)
      . $translations
      . $HARDRET
      . _para($style)
      . ( join( $SPACE, @lines ) );

    return $return;

}    ## tidy end: sub _lines_with_introstyle

const my @ALL_LANGUAGES => qw/en es zh/;
const my $nbsp          => $IDT->nbsp;

sub _effective_date_indd {

    my $dt = shift;

    my $i18n_id = 'effective_colon';
    my $style   = 'effectivedate';

    \my %translations = _translate($i18n_id);

    foreach my $lang ( keys %translations ) {
        my $method = "full_$lang";
        my $date   = $dt->$method;
        if ( $lang eq 'en' ) {
            $date =~ s/ /$nbsp/g;
        }

        $date = $IDT->encode_high_chars_only($date);
        $date = $IDT->language_phrase( $lang, $date, 'Regular' );

        my $phrase = $translations{$lang};
        $phrase =~ s/\s+\z//;

        if ( $phrase =~ m/\%s/ ) {
            $phrase =~ s/\%s/$date/;
        }
        else {
            $phrase .= " " . $IDT->discretionary_lf . $date;
        }

        $phrase
          =~ s/CharStyle:(?:Chinese|ZH_Bold|ZH_Regular)/CharStyle:ChineseMedium/g;

        $translations{$lang} = $phrase;

    }    ## tidy end: foreach my $lang ( keys %translations)

    return
        _para($style)
      . $translations{en}
      . $HARDRET
      . $translations{es}
      . $HARDRET
      . $translations{zh};

}    ## tidy end: sub _effective_date_indd

sub _translate_phrase {

    my $i18n_id = shift;
    \my %translations = _translate($i18n_id);

    $translations{zh} = _zh_phrase( $translations{zh} );

    my $nbsp   = $IDT->nbsp;
    my $joiner = $IDT->nbsp . $IDT->bullet . $SPACE;

    s/ /$nbsp/g foreach ( values %translations );
    return join( $joiner, @translations{qw/en es zh/} );
}

sub _para {
    my $para = shift;
    $para = "A-$para";    # allows find-and-replace to B-, C-, etc.
    return $IDT->parastyle($para) . join( $EMPTY, @_ );
}

sub _zh_phrase {
    my $phrase   = shift;
    my $zh_style = shift // 'ChineseBold';

    $phrase =~ s/((?:<0x[[:xdigit:]]+>)+)/<CharStyle:$zh_style>$1<CharStyle:>/g;
    $phrase =~ s/<CharStyle:> +<CharStyle:$zh_style>/ /g;

    return $phrase;

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
files, and the meaning of any environment variables or properties that
can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT  ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or  FITNESS FOR A PARTICULAR PURPOSE.

