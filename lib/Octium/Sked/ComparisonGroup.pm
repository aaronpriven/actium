package Octium::Sked::ComparisonGroup 0.014;

use Actium 'class';
use Octium;
use Octium::Sked::Comparison;

use List::Compare;

has [qw/oldskeds newskeds/] => (
    isa      => 'Octium::Sked::Collection',
    is       => 'ro',
    required => 1,
);

has oldsignup_id => (
    isa     => 'Str',
    is      => 'ro',
    builder => '_build_oldsignup_id',
    lazy    => 1,
);

has newsignup_id => (
    isa     => 'Str',
    is      => 'ro',
    builder => '_build_newsignup_id',
    lazy    => 1,
);

method _build_oldsignup_id {
    return $self->oldskeds->signup->signup;
}

method _build_newsignup_id {
    return $self->newskeds->signup->signup;
}

has result_r => (
    isa      => 'ArrayRef',
    traits   => ['Array'],
    is       => 'bare',
    init_arg => undef,
    builder  => '_build_result',
    handles  => { results => 'elements', },
);

my $lgdir_days_cr = sub {
    my $id = shift;
    my ( $lg, $dir, $days ) = split( /_/, $id );
    my @days     = split( //, $days );
    my %is_a_day = map { $_ => 1 } @days;
    return $lg . "_$dir", %is_a_day;

};

method _build_result {

    my @newids = Actium::sortbyline( $self->newskeds->sked_ids );
    my @oldids = Actium::sortbyline( $self->oldskeds->sked_ids );

    my $lc = List::Compare->new( \@oldids, \@newids );

    my @same_ids     = $lc->get_intersection;
    my @only_old_ids = $lc->get_unique;
    my @only_new_ids = $lc->get_complement;

    my %to_compare = map { $_, [$_] } @same_ids;

    {
        # go through each old ID and compare against each new ID.
        # If the linegroup and direction match,
        # and any of the days in the old and new id match,
        # do a comparison, and remove each from the "only in"
        # lists.

        my %is_uncompared_old = map { $_ => 1 } @only_old_ids;
        my %is_uncompared_new = map { $_ => 1 } @only_new_ids;

        foreach my $old_id (@only_old_ids) {

            my ( $old_lgdir, %is_an_old_day ) = $lgdir_days_cr->($old_id);

          NEW_ID:
            foreach my $new_id (@only_new_ids) {
                my ( $new_lgdir, %is_a_new_day ) = $lgdir_days_cr->($new_id);
                next unless $old_lgdir eq $new_lgdir;

                for my $oldday ( keys %is_an_old_day ) {
                    if ( $is_a_new_day{$oldday} ) {

                        push $to_compare{$old_id}->@*, $new_id;

                        delete $is_uncompared_old{$old_id};
                        delete $is_uncompared_new{$new_id};

                        next NEW_ID;
                    }
                }

            }
        }

        @only_old_ids = keys %is_uncompared_old;
        @only_new_ids = keys %is_uncompared_new;

    }

    my @results;

    my $comparecry = env->cry(
        'Comparing ' . $self->oldsignup_id . ' to ' . $self->newsignup_id );

    foreach my $oldid ( Actium::sortbyline( keys %to_compare ) ) {
        my $oldsked = $self->oldskeds->sked_obj($oldid);
        foreach my $newid ( $to_compare{$oldid}->@* ) {
            my $newsked = $self->newskeds->sked_obj($newid);

            $comparecry->over( $oldid eq $newid ? $oldid : "$oldid > $newid" );

            push @results,
              Octium::Sked::Comparison->new(
                oldsked => $oldsked,
                newsked => $newsked
              );

        }
    }

    $comparecry->over('');
    $comparecry->done;

    # add all the ones only in one or the other
    my $onlyocry = env->cry( 'Adding only in ' . $self->oldsignup_id );

    foreach my $oldid (@only_old_ids) {
        my $oldsked = $self->oldskeds->sked_obj($oldid);
        push @results, Octium::Sked::Comparison->new( oldsked => $oldsked );
    }
    $onlyocry->done;

    my $onlyncry = env->cry( 'Adding only in ' . $self->newsignup_id );
    foreach my $newid (@only_new_ids) {
        my $newsked = $self->newskeds->sked_obj($newid);
        push @results, Octium::Sked::Comparison->new( newsked => $newsked );
    }
    $onlyncry->done;

    @results = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortkey ] } @results;

    return \@results;

}    ## tidy end: method _build_result

method text {
    foreach my $result ( $self->results ) {
        if ( $result->isnt_identical ) {
            say "--";
            say $result->differ_text(
                old_signup => $self->oldsignup_id,
                new_signup => $self->newsignup_id
            );
            if ( $result->differs ) {
                say $result->trips_count;
                say $result->plain_text;
            }
        }
    }
}

const my %FORMATSPEC => (
    ids_str        => { bold     => 1,         size  => 12 },
    ids_cell       => { valign   => 'bottom',  top   => 2, },
    new_time       => { bg_color => '#FFFFCC', color => '#99FFFF' },
    old_time       => { bg_color => '#FFFFCC', color => '#FFCCCC' },
    changed_time   => { bg_color => '#FFFFCC', color => 'brown' },
    unchanged_time => { color    => '#666666' },
    changed_line   => { bg_color => '#FFFFCC', color => 'brown' },
    unchanged_line => { color    => '#666666' },
    changed_attr   => { bg_color => '#FFFFCC', color => 'brown' },
    unchanged_attr => { color    => '#666666' },
    new_header     => { color    => 'green' },
    old_header     => { color    => 'red' },
    changed_header => { bg_color => '#FFFFCC', color => 'brown' },
    unchanged_header => {},
    new_row          => { bg_color => '#99FFFF', },
    old_row          => { bg_color => '#FFCCCC', },
    new_marker       => { bg_color => '#99FFFF', bold => 1 },
    old_marker       => { bg_color => '#FFCCCC', bold => 1 },
    changed_marker   => { bg_color => '#FFFF00', color => 'brown' },
    unchanged_marker => {},

);

method excel (:$file! ) {
    require Octium::Storage::Excel;
    my $workbook = Octium::Storage::Excel::new_workbook($file);

    my %format = map { $_ => $workbook->add_format( $FORMATSPEC{$_}->%* ) }
      keys %FORMATSPEC;

    my $summary = $workbook->add_worksheet('Summary');
    $summary->set_zoom(125);

    my ( %worksheet_of, %next_row_of, %widest_col_of );

    my ( %use_daycode_col, %use_specday_col, %use_line_col );
    my @results = $self->results;
    foreach my $result (@results) {
        next unless $result->differs;
        my $lgdir = $result->lgdir;
        $use_daycode_col{$lgdir} = 1 if $result->shows_daycode;
        $use_line_col{$lgdir}    = 1 if $result->shows_line;
        $use_specday_col{$lgdir} = 1 if $result->shows_specday;
    }

    my %summary;

    foreach my $result (@results) {
        if ( $result->is_only_old ) {
            push $summary{old}->@*, $result->ids;
        }
        elsif ( $result->is_only_new ) {
            push $summary{new}->@*, $result->ids;
        }
        elsif ( $result->differs ) {
            push $summary{differs}->@*, $result->ids;

            my $ids         = $result->ids;
            my $trips_count = ' (' . $result->trips_count . ')';
            my $lgdir       = $result->lgdir;
            my $worksheet   = $worksheet_of{$lgdir}
              //= $workbook->add_worksheet($lgdir);

            my $row_idx = $next_row_of{$lgdir} // 0;
            $worksheet->write_rich_string( $row_idx, 0, $format{ids_str}, $ids,
                $trips_count, $format{ids_cell} );

            for \my @row(
                $result->strings_and_formats(
                    show_line    => $use_line_col{$lgdir},
                    show_daycode => $use_daycode_col{$lgdir},
                    show_specday => $use_specday_col{$lgdir},
                )
              )
            {
                $row_idx++;

                foreach my $col_idx ( 0 .. $#row ) {
                    $worksheet->write_string( $row_idx, $col_idx,
                        $row[$col_idx][0], $format{ $row[$col_idx][1] } );
                    my $len = length( $row[$col_idx][0] );

                    $widest_col_of{$lgdir}[$col_idx] = $len
                      if ( not defined $widest_col_of{$lgdir}[$col_idx] )
                      or $widest_col_of{$lgdir}[$col_idx] < $len;
                }

            }

            $next_row_of{$lgdir} = $row_idx + 1;

            foreach my $col_idx ( 0 .. $widest_col_of{$lgdir}->$#* ) {
                $worksheet->set_column( $col_idx, $col_idx,
                    int( ( $widest_col_of{$lgdir}[$col_idx] * 1.1 ) ) );
            }
            $worksheet->set_zoom(125);
        }
        else {
            push $summary{identical}->@*, $result->ids;
        }

    }

    {    # write summary

        my $col     = 0;
        my %headers = (
            old       => 'Only in ' . $self->oldsignup_id,
            new       => 'Only in ' . $self->newsignup_id,
            identical => 'Identical',
            differs   => 'Differ',
        );

        for my $entry (qw/old new identical differs /) {
            next unless defined $summary{$entry};
            my @vals = $summary{$entry}->@*;
            unshift @vals, $headers{$entry};
            $summary->actium_write_col_string( 0, $col, \@vals,
                $format{unchanged} );
            my $width = Actium::max( map { length($_) } (@vals) );
            $summary->set_column( $col, $col, int( $width * 1.1 ) );
            $col++;
        }

    }

    $workbook->close;

}

Actium::immut;

1;

__END__

