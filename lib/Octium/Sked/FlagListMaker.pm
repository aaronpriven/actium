package Octium::Sked::FlagListMaker 0.013;
#vimcolor: #202020

use Actium ('role');
use Octium::Set;
# applied to Octium::SkedCollection

my @FLAGLIST_HEADER;

BEGIN {
    const @FLAGLIST_HEADER => (
        qw/ DestItem DestDefault DestOverride
          StopID PlaceID In_patterns c_description_full DestPlaceIDs NameDefault
          NameOverrideKey NameOverride IconsDefault IconsDefaultKey IconsOverride/
    );
}

use constant {
    map { $FLAGLIST_HEADER[$_] => $_ } ( 0 .. $#FLAGLIST_HEADER )
};
# turns the header names into constants for the column ids

use constant { STOPS => 0, COUNT => 1 };

method _flaglist_patterns {

    my %pat_of_ld;

    foreach my $sked ( $self->skeds ) {
        my $dir     = $sked->dircode;
        my $daycode = $sked->daycode;
        my @stops   = $sked->stops;

        foreach my $trip ( $sked->trips ) {
            my $line = $trip->line;
            my $ld   = "$line-$dir";

            my @stoptimes  = $trip->stoptimes;
            my @has_a_time = map { defined $_ ? 1 : 0 } @stoptimes;
            my @tripstops
              = @stops[ grep { $has_a_time[$_] } ( 0 .. $#stoptimes ) ];
            my $patternkey = join( " ", @tripstops );

            if ( exists $pat_of_ld{$ld}{$patternkey} ) {
                $pat_of_ld{$ld}{$patternkey}[COUNT]{$daycode}++;
            }
            else {
                $pat_of_ld{$ld}{$patternkey}[STOPS] = \@tripstops;
                $pat_of_ld{$ld}{$patternkey}[COUNT]{$daycode} = 1;
            }

        }

    }

    return \%pat_of_ld;

}

method flaglists {

    \my %patterns_of_linedir = $self->_flaglist_patterns;

    # so stops_of_pattern{$patternkey} has the list of stops, and
    # count_of_pattern{$patternkey}{daycode} has the count of trips for that day

    my %flaglists_of_linedir;

    for my $linedir ( keys %patterns_of_linedir ) {

        my ( @ids, @stop_sets );
        for my $patternkey ( keys $patterns_of_linedir{$linedir}->%* ) {
            push @ids,       $patternkey;
            push @stop_sets, $patterns_of_linedir{$linedir}{$patternkey}[STOPS];
        }

        \my %union_info = Octium::Set::ordered_union_columns(
            ids  => \@ids,
            sets => \@stop_sets,
        );

        \my @union_stops = $union_info{union};
        \my %columns_of  = $union_info{columns_of};

        # set up pattern letters and in_patterns

        my ( %letter_of, %id_of, @in_patterns_of_hash, @in_patterns_of_str,
            @all_letters, $letter );
        for my $id (@ids) {
            $letter = $letter ? $letter++ : 'A';
            push @all_letters, $letter;
            #increment letter, or set to 'A' if it was never set

            $letter_of{$id} = $letter;
            $id_of{$letter} = $id;

            \my @column_idxs = $columns_of{$id};

            foreach my $column_idx (@column_idxs) {
                $in_patterns_of_hash[$column_idx]{$letter} = 1;
            }
        }

        foreach my $column_idx ( 0 .. $#union_stops ) {
            my $str = $EMPTY;
            for my $letter (@all_letters) {
                $str
                  .= $in_patterns_of_hash[$column_idx]{$letter} ? $letter : '_';
            }
            $in_patterns_of_str[$column_idx] = $str;
        }

        my @pat_display;
        foreach my $letter (@all_letters) {
            my $pat_display = "$letter: ";
            # TODO add days and counts
            push @pat_display, $pat_display;
        }

        my $flaglist = Array::2D->new;
        $flaglist->set_col( DestItem, $linedir, @pat_display );
        $flaglist->set_col( StopID, @union_stops );

        $flaglist->set_col( In_patterns, @pat_display );

        $flaglist->unshift_row(@FLAGLIST_HEADER);

        $flaglists_of_linedir{$linedir} = $flaglist;

    }

    return \%flaglists_of_linedir;

}

const my $PHYLUM => 'f';

method output_skeds_flaglists (
      Octium::Folders::Signup : $signup = Octium::env->signup,
      Str : $collection  = 'final',
      ) {

    my $output_folder      = $signup->subfolder( $PHYLUM, $collection );
    my $output_folder_path = $output_folder->path;

    \my %flaglists_of_linedir = $self->flaglists;

    foreach my $linedir ( keys %flaglists_of_linedir ) {
        my $flaglist = $flaglists_of_linedir{$linedir};
        $flaglist->xlsx("$output_folder/$linedir.xlsx");
    }

    return;

}

1;

__END__

        my %patterns_of_daycode;
        my %stops_of_daycode;

        foreach my $sked (@skeds) {

            my %pattern_of_key;

            foreach my $trip ( $sked->trips ) {
                my @stoptimes  = $trip->stoptimes;
                my @has_a_time = map { defined $_ ? 1 : 0 } @stoptimes;
                my $patternkey = join( '', @has_a_time );

                if ( exists( $pattern_of_key{$patternkey} ) ) {
                    $pattern_of_key{$patternkey}{count}++;
                }
                else {
                    $pattern_of_key{$patternkey} = {
                        count      => 1,
                        has_a_time => \@has_a_time,
                    };

                }

            }

            my $daycode = $sked->daycode;
            $patterns_of_daycode{$daycode} = [ values %pattern_of_key ];
            $stops_of_daycode{$daycode}    = $sked->stopids;

        }

        my ( @stop_sets, @daycodes );
        foreach my $daycode ( keys %stops_of_daycode ) {
            push @daycodes,  $daycode;
            push @stop_sets, $stops_of_daycode{$daycode};
        }

        my $union = Octium::Set::ordered_union_columns(
            sets => \@stop_sets,
            ids  => @daycodes
        );
        my @union_stops = $union->{union};
        \my %columns_of = $union->{columns_of};

        foreach my $daycode ( keys %columns_of ) {
            my @columns  = $columns_of{$daycode};
            my @patterns = $patterns_of_daycode{$daycode};

            foreach my $pattern (@patterns) {

            }

        }

    }
}

__END__









{

    my @skeds;
    foreach my $linedir ( keys %skeds_of_linedir ) {
        push @skeds, _merge_skeds_for_fl( $skeds_of_linedir{$linedir}->@* );
    }

    my @flaglists = map { $_->flaglists } @skeds;
    # flaglist in Octium::Sked not yet implemented
    return @flaglists;

}

func _merge_skeds_for_fl (Octium::Sked @skeds) {

    die "no skeds passed to _merge_skeds" unless @skeds;
    return $skeds[0] if @skeds == 1;

    my @merged_skeds;






    # merge multiple skeds into one
    # not yet implemented
    ...;

    return @merged_skeds;

}

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use <name>;
 # do something with <name>

=head1 DESCRIPTION

A full description of the module and its features.

=head1 CLASS METHODS

=head2 method

Description of method.

=head1 OBJECT METHODS or ATTRIBUTES

=head2 method

Description of method.

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

The Actium system, and...

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

