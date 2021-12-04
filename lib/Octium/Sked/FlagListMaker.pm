package Octium::Sked::FlagListMaker 0.013;

use Actium ('role');
use Octium::Set;
# applied to Octium::SkedCollection

my @FLAGLIST_HEADER;

BEGIN {
    const @FLAGLIST_HEADER => (
        qw/ DestItem DestDefault DestOverride
          StopID PlaceID In_patterns StopDescrip DestPlaceIDs
          NameDefault NameOverrideKey NameOverride
          IconsDefault IconsDefaultKey IconsOverride/
    );
}

use constant {
    map { $FLAGLIST_HEADER[$_] => $_ } ( 0 .. $#FLAGLIST_HEADER )
};
# turns the header names into constants for the column ids

use constant { STOPS => 0, PLACES => 1, COUNT => 2 };

const my $LASTSTOP_TOKEN      => '@L';
const my $TRANSBAY_ONLY_TOKEN => '@TO';
const my $TRANSBAY_DROPOFF    => '@TD';

method _flaglist_patterns {

    my ( %pat_of_ld, %dirobj_of_ld );

    foreach my $sked ( $self->skeds ) {
        my $dir        = $sked->dircode;
        my $dir_obj    = $sked->dir_obj;
        my $daycode    = $sked->daycode;
        my @stops      = $sked->stopids;
        my @stopplaces = $sked->stopplaces;

        foreach my $trip ( $sked->trips ) {
            my $line = $trip->line;
            my $ld   = "$line-$dir";
            $dirobj_of_ld{$ld} //= $dir_obj;

            my @stoptimes     = $trip->stoptimes;
            my @has_a_time    = map  { defined $_ ? 1 : 0 } @stoptimes;
            my @tripstop_idxs = grep { $has_a_time[$_] } ( 0 .. $#stoptimes );

            my @tripstops  = @stops[@tripstop_idxs];
            my $patternkey = join( " ", @tripstops );

            if ( exists $pat_of_ld{$ld}{$patternkey} ) {
                $pat_of_ld{$ld}{$patternkey}[COUNT]{$daycode}++;
            }
            else {
                $pat_of_ld{$ld}{$patternkey}[STOPS] = \@tripstops;
                $pat_of_ld{$ld}{$patternkey}[COUNT]{$daycode} = 1;
                $pat_of_ld{$ld}{$patternkey}[PLACES]
                  = [ @stopplaces[@tripstop_idxs] ];
            }

        }

    }

    return \%pat_of_ld, \%dirobj_of_ld;

}

method flaglists (:$actiumdb = env->actiumdb) {

    my $stopinfo_r
      = env->actiumdb->all_in_columns_key(
        qw/Stops_Neue c_description_fullabbr h_stp_place/);

    my $cry = env->cry('Assembling flag lists');

    ( \my %patterns_of_linedir, \my %dirobj_of_linedir )
      = $self->_flaglist_patterns;

    my %flaglists_of_linedir;

    for my $linedir ( keys %patterns_of_linedir ) {

        my %pat = _flaglist_patinfo(
            patterns_of_linedir => \%patterns_of_linedir,
            linedir             => $linedir
        );

        my $flaglist = Array::2D->new;

        $flaglist->set_col( DestItem, $linedir, $pat{patterns}->@* );

        my @dests
          = map { $actiumdb->destination_or_warn($_) } $pat{final_places}->@*;
        my $line_dest = join( " / ", Actium::uniq(@dests) );
        $flaglist->set_col( DestDefault, $line_dest, @dests );

        $flaglist->set_col( StopID, $pat{union_stops}->@* );

        $flaglist->set_col( StopDescrip,
            map { $stopinfo_r->{$_}{c_description_fullabbr} }
              $pat{union_stops}->@* );

        $flaglist->set_col( PlaceID, $pat{union_places}->@* );

        $flaglist->set_col( In_patterns, $pat{in_patterns}->@* );

        #my @union_dest_ids = map { join(" " , $_->@* ) } $pat{union_dests}->@*;
        #$flaglist->set_col( DestPlaceIDs , @union_dest_ids);

        my $dirobj = $dirobj_of_linedir{$linedir};

        my ( @union_dest_ids, @name_defaults );
        for my $stop_idx ( 0 .. $pat{union_dests}->$#* ) {
            my @stop_dests = $pat{union_dests}[$stop_idx]->@*;
            push @union_dest_ids, join( " ", @stop_dests );

            if ( $stop_dests[0] =~ /^@/ ) {
                push @name_defaults, $stop_dests[0];
            }
            else {
                my @dest_names
                  = Actium::uniq( map { $actiumdb->destination_or_warn($_) }
                      @stop_dests );
                push @name_defaults,
                  $dirobj->as_to_text . join( " / ", @dest_names );
            }
        }

        $flaglist->set_col( DestPlaceIDs, @union_dest_ids );
        $flaglist->set_col( NameDefault,  @name_defaults );

        $flaglist->unshift_row(@FLAGLIST_HEADER);

        $flaglists_of_linedir{$linedir} = $flaglist;

    }

    $cry->done;

    return \%flaglists_of_linedir;

}

func _flaglist_patinfo (:\%patterns_of_linedir , :$linedir) {

    my ( %order_of, %places_of, %stops_of, @ids );
    for my $patternkey ( keys $patterns_of_linedir{$linedir}->%* ) {
        push @ids, $patternkey;
        $stops_of{$patternkey}
          = $patterns_of_linedir{$linedir}{$patternkey}[STOPS];
        $places_of{$patternkey}
          = $patterns_of_linedir{$linedir}{$patternkey}[PLACES];
    }

    my %union_info
      = Octium::Set::ordered_union_columns( sethash => \%stops_of, );

    \my @union_stops = $union_info{union};
    \my %columns_of  = $union_info{columns_of};
    my @union_places;

    # set up pattern letters and in_patterns

    my (%letter_of,          %id_of,       @in_patterns_of_hash,
        @in_patterns_of_str, @all_letters, $letter,
        %final_place_of,     @union_dests, @is_intermediate_stop
    );
    for my $id (@ids) {
        if ( defined $letter ) {
            $letter++;
        }
        else {
            $letter = 'A';
        }
        push @all_letters, $letter;
        #increment letter, or set to 'A' if it was never set

        $letter_of{$id} = $letter;
        $id_of{$letter} = $id;

        \my @column_idxs = $columns_of{$id};

        #foreach my $column_idx (@column_idxs) {
        #    $in_patterns_of_hash[$column_idx]{$letter} = 1;
        #}

        my $final_place = '';
        my $seen_final_pat_column;
        foreach my $pat_column_idx ( reverse( 0 .. $#column_idxs ) ) {
            my $column_idx = $column_idxs[$pat_column_idx];
            $in_patterns_of_hash[$column_idx]{$letter} = 1;
            my $place = $places_of{$id}[$pat_column_idx];
            if ($place) {
                $union_places[$column_idx] //= $place;
                $final_place ||= $place;
            }

            $union_dests[$column_idx]{$final_place} = 1;
            if ($seen_final_pat_column) {
                @is_intermediate_stop[$column_idx] = 1;
            }
            else {
                $seen_final_pat_column = 1;
            }

        }

        $final_place_of{$letter} = $final_place;

    }

    foreach my $union_idx ( 0 .. $#union_stops ) {
        my $str = $EMPTY;
        for my $letter (@all_letters) {
            $str .= $in_patterns_of_hash[$union_idx]{$letter} ? $letter : '_';
        }
        $in_patterns_of_str[$union_idx] = $str;

        @union_dests[$union_idx]
          = [ sort keys $union_dests[$union_idx]->%* ];
        if ( not $is_intermediate_stop[$union_idx] ) {
            unshift $union_dests[$union_idx]->@*, $LASTSTOP_TOKEN;
        }

    }

    my ( @pat_display, @final_places );
    foreach my $letter (@all_letters) {

        \my %counts
          = $patterns_of_linedir{$linedir}{ $id_of{$letter} }[COUNT];

        my $pat_display = "$letter";
        foreach my $day ( sort keys %counts ) {
            my $shortcode = Octium::Days->instance( $day, 'B' )->as_shortcode;
            $pat_display .= " $shortcode:" . $counts{$day};
        }

        push @pat_display,  $pat_display;
        push @final_places, $final_place_of{$letter};
    }

    return union_stops => \@union_stops,
      union_places     => \@union_places,
      patterns         => \@pat_display,
      final_places     => \@final_places,
      in_patterns      => \@in_patterns_of_str,
      union_dests      => \@union_dests,
      ;

}

const my $PHYLUM => 'f';

method output_skeds_flaglists (
      :$actiumdb = env->actiumdb,
      Octium::Folders::Signup :$signup = env->signup,
      Str :$collection  = 'final',
      ) {

    my $output_folder      = $signup->subfolder( $PHYLUM, $collection );
    my $output_folder_path = $output_folder->path;

    \my %flaglists_of_linedir = $self->flaglists( actiumdb => $actiumdb );

    my $cry = env->cry("Writing flag lists...");
    foreach my $linedir ( Actium::sortbyline keys %flaglists_of_linedir ) {
        $cry->over($linedir);
        my $flaglist = $flaglists_of_linedir{$linedir};
        $flaglist->xlsx( output_file => "$output_folder/$linedir.xlsx" );
    }
    $cry->done;

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

