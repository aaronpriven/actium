package Octium::Points::Column 0.013;

# Object for a single column in an InDesign point schedule
#
use warnings;
use strict;

use 5.010;

use sort ('stable');

use Moose;                             ### DEP ###
use MooseX::SemiAffordanceAccessor;    ### DEP ###
use Moose::Util::TypeConstraints;      ### DEP ###

use namespace::autoclean;              ### DEP ###

use Actium::Time;
use Const::Fast;                       ### DEP ###

use Octium::Text::InDesignTags;
const my $IDT => 'Octium::Text::InDesignTags';

const my $head_line_separator =>
  ( $IDT->thinspace . $IDT->bullet . $IDT->thinspace );

const my $FREQUENT_SERVICE         => 15;
const my $MINIMUM_TRIPS_IN_A_RANGE => 8;

# first and last will still be shown

has [qw/linegroup display_stopid days dircode/] => (
    is  => 'ro',
    isa => 'Str',
);

has note => (
    is        => 'rw',
    isa       => 'Str',
    predicate => 'has_note',
);

has [qw<primary_destination primary_exception primary_line>] => (
    is  => 'rw',
    isa => 'Str',
);

foreach (qw/formatted_header formatted_column/) {
    has $_ => => (
        is      => 'rw',
        isa     => 'Str',
        default => q[],
    );
}

sub append_to_formatted_header {
    my $self = shift;
    $self->set_formatted_header( $self->formatted_header . join( '', @_ ) );
}

has primary_approxflag => (
    is  => 'rw',
    isa => 'Bool',
);

has time_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles =>
      { 'time' => 'get', time_count => 'count', 'times' => 'elements' },
);

has line_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { line => 'get', lines => 'elements' },
);

has destination_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { destination => 'get', destinations => 'elements' },
);

has exception_r => (
    traits  => ['Array'],
    is      => 'ro',
    writer  => '_set_exception_r',    # only for stupid BSN kludge
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { exception => 'get', exceptions => 'elements' },
);

has place_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { places => 'elements' },
);

has "head_line_r" => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        head_line       => 'get',
        head_lines      => 'elements',
        head_line_count => 'count'
    },
);

has "formatted_time_r" => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => {
        set_formatted_time   => 'set',
        formatted_times      => 'elements',
        formatted_time_count => 'count',
    },
);

has 'foot_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { feet => 'elements', set_foot => 'set', foot => 'get', },
);

has approxflag_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Bool]',
    default => sub { [] },
    handles => { approxflags => 'elements', approxflag => 'get', },
);

has formatted_height => (
    is  => 'rw',
    isa => 'Maybe[Int]',

    # this is the height of the column after it's been formatted, that is,
    # the height on the template
);

has 'previous_blank_columns' => (
    isa     => 'Int',
    is      => 'rw',
    default => 0,
);

has frequent_action_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef',
    builder => '_build_frequent_action_r',
    lazy    => 1,
    handles => { frequent_actions => 'elements', },
);

has content_height => (
    is      => 'ro',
    builder => '_build_content_height',
    lazy    => 1,
    isa     => 'Int',
);

# this is the number of visible rows in the column, that is, times plus
# space for the frequent icon

has _column_division_r => (
    is      => 'bare',
    default => sub { {} },
    isa     => 'HashRef',
    traits  => ['Hash'],
    handles => {
        _set_column_division    => 'set',
        _column_division        => 'get',
        _column_division_exists => 'exists',
    },
);

sub column_division {
    my ( $self, $column_height ) = @_;
    if ( $self->_column_division_exists($column_height) ) {
        return $self->_column_division($column_height);
    }
    return $self->divide_columns($column_height);

}

sub fits_in_columns {
    my ( $self, $column_height ) = @_;
    my $division = $self->column_division($column_height);
    return scalar keys $division->%*;
}

# column divisions are array references of the last entry of each column (0-based)
# So [10] means there's 1 column and rows 0-10 are in it
# [10, 15] means there's 2 columns, rows 0-10 are in the first one, 11-15 in the second one

sub format_header {
    my $self = shift;
    $self->format_head_lines;
    $self->format_headdays;
    $self->format_headdest;
    $self->format_approxflag;

    return;

}

sub format_head_lines {

    my $self = shift;

    my ( %color_of, %seen_color );
    my @head_lines = $self->head_lines;
    my ( $color, $head_lines );

    my $pstyle        = 'dropcaphead';
    my $firstline     = $self->head_line(0);
    my $firstline_len = length($firstline);
    if ( $#head_lines or ( $firstline_len > 3 ) ) {
        $pstyle = 'dropcapheadmany';
    }
    elsif ( $firstline_len == 3 ) {
        $pstyle = 'dropcaphead3';
    }

    foreach my $line (@head_lines) {
        {
            no warnings 'once';
            if ( $line =~ /BS[DN]/ ) {
                $color = $line;

                if ( $line eq 'BSN' ) {

                   #    my $days = $self->days;
                   #    $line = 'FRI NIGHT' if $days eq '5';
                   #    #$line = 'SAT NIGHT'       if $days eq '6';
                   #    $line = 'FRI & SAT NIGHT' if $days eq '6';
                   #    $line = 'FRI & SAT NIGHT' if $days eq '56';
                   #    $line = 'MON' . $IDT->endash . 'THU NIGHT'
                   #      if $days eq '12345';    # ugly ugly ugly hack,
                   #                              # I should really fix the data
                   #}
                   #elsif ( $line eq 'BSD' or $line eq 'BSH' ) {
                    $line = 'MON' . $IDT->endash . 'FRI NIGHT';
                }
                else {
                    $line = 'MON' . $IDT->endash . 'FRI DAY';
                }

                #$pstyle = 'dropcapheadbsh';

                $self->append_to_formatted_header(
                    $IDT->parastyle('BSHdays-dest'),
                    $IDT->color($color),
                    $line,

                    #$IDT->thirdspace,
                    $IDT->end_nested_style,
                    $IDT->softreturn,
                );
                return;

            }
            else {
                $color = (
                    $Octium::Cmd::MakePoints::lines{$line}{Color}
                      or 'Grey80'
                );
            }
        }
        $color_of{$line}    = $color;
        $seen_color{$color} = 1;
    }

    my $length_head_lines
      = calc_length_head_lines( $head_line_separator, @head_lines );

    #my $length_head_lines
    #  = length( join( $head_line_separator, @head_lines ) ) + 1;

    if ( scalar( keys %seen_color ) == 1 ) {
        $head_lines
          = $IDT->color($color) . join( $head_line_separator, @head_lines );
        $head_lines
          = $IDT->parastyle($pstyle)
          . $IDT->dropcapchars($length_head_lines)
          . $head_lines;

    }
    else {
        my @color_head_lines
          = map { $IDT->color( $color_of{$_} ) . $_ . $IDT->nocolor }
          @head_lines;
        $head_lines = join(
            $IDT->color('Grey80') . $head_line_separator . $IDT->nocolor,
            @color_head_lines
        );

        $head_lines
          = $IDT->parastyle($pstyle)
          . $IDT->dropcapchars($length_head_lines)
          . $head_lines;

    }
    $self->append_to_formatted_header( $head_lines . q[ ] );

    #$self->set_formatted_header
    #      ($self->formatted_header . $head_lines . q[ ]);

    return;

}

sub calc_length_head_lines {
    my $separator  = shift;
    my @head_lines = @_;
    my $text       = join( $head_line_separator, @head_lines );
    $text =~ s/<0x[0-9A-F]+>/ /g; # replace InDesign character tags with a space
    return length($text) + 1;
}

my %weekdays = (
    1 => 'Mondays',
    2 => 'Tuesdays',
    3 => 'Wednesdays',
    4 => 'Thursdays',
    5 => 'Fridays',
    6 => 'Saturdays',
    7 => 'Sundays',
    W => 'weekdays',
    E => 'weekends',
    D => 'every day',
    H => 'holidays',
    S => 'school days',
);

sub format_headdays {

    my $self = shift;

    return if $self->linegroup =~ /\A BS[DSN] \z/sx;

    my $days = $self->days;

    # TODO add code for exceptions

    $days =~ s/1234567/D/;    # every day
    $days =~ s/12345/W/;      # weekdays
    $days =~ s/67/EH/;        # weekends & holidays
    $days =~ s/7/7H/;         # sundays & holidays

    my @daycodes = split( //, $days );
    my @days     = map { $weekdays{$_} } @daycodes;

    if ( @days == 1 ) {
        $days = $days[0];
    }
    else {
        my $last = pop @days;
        $days = join( q{, }, @days ) . " & $last";
    }

    my $dircode = $self->dircode;
    if ( $dircode eq '14' or $dircode eq '15' ) {
        $days .= ". ";
    }

    $self->append_to_formatted_header( $IDT->bold_word( ucfirst($days) ) );

    return;

}

sub format_headdest {

    my $self = shift;
    my $dest;
    if ( $self->linegroup =~ /\A BS[DSN] \z/sx ) {
        $dest = $IDT->nocolor . 'To ' . $self->primary_destination;
    }
    else {
        $dest = ' to ' . $self->primary_destination;
    }

    my $dir = $self->dircode;

    if ( $dir eq '8' ) {
        $dest .= ' (Clockwise loop)';
    }
    elsif ( $dir eq '9' ) {
        $dest .= ' (Counterclockwise loop)';
    }
    elsif ( $dir eq '14' ) {
        $dest = "<0x201C>A Loop<0x201D> $dest";
    }
    elsif ( $dir eq '15' ) {
        $dest = "<0x201C>B Loop<0x201D> $dest";
    }

    $dest =~ s{\.*\z}{\.}sx;    # put exactly one period at the end

    $self->append_to_formatted_header($dest);
    return;

}

sub format_approxflag {
    my $self = shift;

    my $display_stopid = $self->display_stopid;
    if ( $self->has_note ) {

        return unless $display_stopid;

        $self->append_to_formatted_header(" (Stop $display_stopid)");
        return;
    }

    my $primary_approxflag = $self->primary_approxflag;

    if ($display_stopid) {

        $self->append_to_formatted_header(
            $primary_approxflag
            ? " Approximate departure times from stop $display_stopid:"
            : " Scheduled departure times from stop $display_stopid:"
        );

    }
    else {
        $self->append_to_formatted_header(
            $primary_approxflag
            ? ' Approximate departure times:'
            : ' Scheduled departure times:'
        );
    }

    return;

}

sub _build_frequent_action_r {
    my $self = shift;

    my @frequent_actions;
    if ( $self->linegroup eq '1T' ) {
        my @ranges;
        my @times    = $self->times;
        my @timenums = map { Actium::Time::->from_str($_)->timenum } @times;
        my @feet     = $self->feet;

        my $start = 0;

        my $in_a_range = 0;

      TRIP:
        for my $trip_idx ( 0 .. $#times - 1 ) {

            my $next_idx = $trip_idx + 1;

            my $this        = $timenums[$trip_idx];
            my $next        = $timenums[$next_idx];
            my $is_frequent = ( $next - $this ) <= $FREQUENT_SERVICE;
            my $thisfoot    = $feet[$trip_idx];
            my $nextfoot    = $feet[$next_idx];

            if (    not $in_a_range
                and not $thisfoot
                and not $nextfoot
                and $is_frequent )
            {
                # start a range
                push @ranges, [$trip_idx];
                $in_a_range = 1;
            }
            elsif ( $in_a_range and ( $nextfoot or not $is_frequent ) ) {

                # end a range
                $ranges[-1][1] = $trip_idx;
                $in_a_range = 0;
            }
        }

        $ranges[-1][1] = $#times if ($in_a_range);

        #Actium::env->wail( Actium::dumpstr(@ranges) );

        # filter out ranges that are too small
        @ranges = grep {

            #\my @range = $_;
            #my $diff = $range[1] - $range[0];
            #$MINIMUM_TRIPS_IN_A_RANGE <= $diff;
            $MINIMUM_TRIPS_IN_A_RANGE <= ( $_->[1] - $_->[0] );

            # same thing as commented out code, only without refalias
        } @ranges;

        foreach my $range (@ranges) {
            my $first = $range->[0];
            my $last  = $range->[1];
            $frequent_actions[$first] = 'S';
            $frequent_actions[$last]  = 'E';
            foreach my $trip_idx ( $first + 1 .. $last - 1 ) {
                $frequent_actions[$trip_idx] = 'C';
            }
        }

        my @freq = map { $_ // '' } @frequent_actions;

        #Actium::env->wail("@freq");

    }

    return \@frequent_actions;

}

sub _build_content_height {
    my $self = shift;

    my $height = 0;
    for my $frequent_action ( $self->frequent_actions ) {
        if ( not defined $frequent_action or $frequent_action eq 'E' ) {
            $height++;
        }
        elsif ( $frequent_action eq 'S' ) {
            no warnings 'once';
            $height += Octium::Cmd::MakePoints::HEIGHT_OF_FREQUENT_ICON() + 1;
        }

    }
    return $height;

}

const my $icon_object_height =>
  Octium::Cmd::MakePoints::HEIGHT_OF_FREQUENT_ICON() + 2;

sub divide_columns {
    my ( $self, $max_column_height ) = @_;

    my $content_height = $self->content_height;
    return ( { $content_height => 1 } )
      if $max_column_height >= $content_height;

    my $width        = Actium::ceil( $content_height / $max_column_height );
    my $break_height = Actium::ceil( $content_height / $width );

    my $current_column_height = 0;
    my %column_division;

    my @frequent_actions = $self->frequent_actions;

my $break_at_next_e = 0;
    foreach my $action_idx ( 0 .. $#frequent_actions ) {

        my $action = $frequent_actions[$action_idx];
        my $to_add;

        if ( not defined $action ) {
            $to_add = 1;
        }
        elsif ( $action eq 'S' ) {
            $to_add = Octium::Cmd::MakePoints::HEIGHT_OF_FREQUENT_ICON() + 2;
        }
        elsif ($action eq 'E') {
            if ($break_at_next_e) {
               $column_division{$action_idx} = 1;
	}
	next;
        } else {
            $to_add = 0;
        }

        # push current item on next column if current item is too big
        # to fit in this column
        if ( $current_column_height + $to_add > $max_column_height ) {
            $column_division{ $action_idx - 1 } = 1;
            $current_column_height = $to_add;
        }
        elsif ( $action_idx == $#frequent_actions ) {
            $column_division{$action_idx} = 1;

            # it fits, and this is is the last item,
            # so set last column end to this one
        }
        else {

            # it fits, and there are more items, so add current height
            # to the tally
            $current_column_height += $to_add;

            # if it is now at or over the break height, set this
            # to be the last row in the column , and set the active column
            # to be the next one
	# 
	# Except that if this is an "S", we don't break here,
	# we break after the next "E"

            if ( $current_column_height >= $break_height ) {
	    if ($action eq 'S') {
	       $break_at_next_e = 1;
	       } else {
                   $column_division{$action_idx} = 1;
	       }

                $current_column_height = 0;
            }
        }

    }

    $self->_set_column_division( $max_column_height, \%column_division );
    return \%column_division;

}

__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

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

