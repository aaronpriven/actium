package Actium::O::Sked::ComparisonGroup 0.014;

use Actium 'class';
use Actium::O::Sked::Comparison;
use Actium::Sorting::Line;

use List::Compare;

has [qw/oldskeds newskeds/] => (
    isa      => 'Actium::O::Sked::Collection',
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

method _build_result {

    my @newids = Actium::sortbyline( $self->newskeds->sked_ids );
    my @oldids = Actium::sortbyline( $self->oldskeds->sked_ids );

    my $lc = List::Compare->new( \@oldids, \@newids );

    my @same = $lc->get_intersection;
    my @old  = $lc->get_unique;
    my @new  = $lc->get_complement;

    my %to_compare = map { $_, [$_] } @same;

    # TODO -
    # figure out how to map old ones to new ones when the days differ
    # and make $to_compare{$oldid} = [ $newids ]
    # e.g.,
    # $to_compare{1_NB_67} = [ 1_NB_6, 1_NB_7 ]
    # and also
    # $to_compare{6_NB_6} = [ 6_NB_67 ]
    # $to_compare{6_NB_7} = [ 6_NB_67 ]

    my @results;

    foreach my $oldid ( Actium::sortbyline( keys %to_compare ) ) {
        my $oldsked = $self->oldskeds->sked_obj($oldid);
        foreach my $newid ( $to_compare{$oldid}->@* ) {
            my $newsked = $self->newskeds->sked_obj($newid);
            push @results,
              Actium::O::Sked::Comparison->new(
                oldsked => $oldsked,
                newsked => $newsked
              );

        }
    }

    # add all the ones only in one or the other

    foreach my $oldid (@old) {
        my $oldsked = $self->oldskeds->sked_obj($oldid);
        push @results, Actium::O::Sked::Comparison->new( oldsked => $oldsked );
    }
    foreach my $newid (@new) {
        my $newsked = $self->newskeds->sked_obj($newid);
        push @results, Actium::O::Sked::Comparison->new( newsked => $newsked );
    }

    @results = map { $_->[0] }
      sort { $a->[1] cmp $b->[1] }
      map { [ $_, $_->sortkey ] } @results;

    return \@results;

} ## tidy end: method _build_result

method text {
    foreach my $result ( $self->results ) {
        if ( $result->isnt_identical ) {
            say "--";
            say $result->differ_text(
                old_signup => $self->oldsignup_id,
                new_signup => $self->newsignup_id
            );
            say $result->text if $result->difference_type == $result->DIFFER;
        }
    }
}

const my %FORMATSPEC = (
    ids => {
        bold     => 1,
        size     => 18,
        color    => 'white',
        bg_color => 'black',
        valign   => 'bottom'
    },
    new_time     => { bg_color => '#CCFFCC' },
    old_time     => { bg_color => '#FFCCCC' },
    changed_time => { bg_color => '#FFFFCC' },
    unchanged    => {},
    new_row => { bg_color => '#800000', color => 'white' },
    old_row => { bg_color => '#004000', color => 'white' },
);

method excel (:$file! ) {
    require Actium::Storage::Excel;
    my $workbook = Actium::Storage::Excel->new_workbook($file);

    my %format
      = map { $_ => $workbook->add_format( $FORMATSPEC{$_} ) } keys %FORMATSPEC;

    my $only_in = $workbook->add_worksheet('Only in one');

    my ( %worksheet_of, %last_row_of, %widest_col_of );

    my ( @old, @new );
    foreach my $result ( $self->results ) {
        if ( $result->is_only_old ) {
            push @old, $result->ids;
        }
        elsif ( $result->is_only_new ) {
            push @new, $result->ids;
        }
        elsif ( $result->differs ) {
            my $ids       = $result->ids;
            my $lgdir     = $ids =~ s/_[0-9A-Z]*\z//r;
            my $worksheet = $worksheet_of{$lgdir}
              //= $workbook->add_worksheet($lgdir);

            my $row = $last_row_of{$lgdir} // 0;
            $worksheet->write_string( $row++, 0, $ids, $format{ids} );

            # TODO write rows here

            $last_row_of{$lgdir} = $row;
        }

    } ## tidy end: foreach my $result ( $self->...)

    @old = "(none)" unless @old;
    unshift @old, "Only in " . $self->oldsignup_id;
    $only_in->actium_write_col_string( 0, 0, \@old );

    @new = "(none)" unless @new;
    unshift @new, "Only in " . $self->newsignup_id;
    $only_in->actium_write_col_string( 0, 1, \@new, $format{unchanged} );

    my $width = Actium::max( map { length($_) } ( @new, @old ) );
    $only_in->set_column( 0, 1, int( $width * 1.1 ) );

    $workbook->close;

} ## tidy end: method excel

Actium::immut;

1;

__END__

