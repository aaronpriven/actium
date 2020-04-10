package Octium::Points::Box 0.013;

# Object for a single box in an 2019 InDesign point schedule

use Actium('class');
use Octium;
use Octium::Points::BTime;
use Octium::Types(qw/ActiumDir ActiumDays/);

use Octium::Text::InDesignTags;
const my $IDT => 'Octium::Text::InDesignTags';

has [qw/kpointline display_stopid /] => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has parent => (
    is       => 'ro',
    required => 1,
    weak_ref => 1,
    isa      => 'Octium::Points::BPoint',
    handles  => [qw/actiumdb agency/],
);

has [qw/note/] => (
    is        => 'rwp',
    isa       => 'Str',
    predicate => 'has_note',
);

has days => (
    is     => 'rwp',
    isa    => ActiumDays,
    coerce => 1,
);

has dir => (
    is     => 'rwp',
    isa    => ActiumDir,
    coerce => 1,
);

has linegroup => (
    is  => 'rwp',
    isa => 'Str',
);

has head_line_r => (
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

has btimes_r => (
    traits  => ['Array'],
    is      => 'rwp',
    isa     => 'ArrayRef[Octium::Point::BTime]',
    default => sub { [] },
    handles => { time_count => 'count', },
);

# the following are used for generating the footnotes

const my @PRIMARIES = qw/line destination exception approxflag/;

foreach my $primary_attr (@PRIMARIES) {
    has "primary_$primary_attr" => (
        isa => 'Str',
        is  => 'rwp',
    );

    my $count_attribute = $primary_attr . '_count';

    has $count_attribute => (
        isa => 'Int',
        is  => 'rwp',
    );

    has "has_multiple_$primary_attr" => (
        isa     => 'Bool',
        is      => 'ro',
        lazy    => 1,
        default => sub { my $self = shift; $self->$count_attribute > 1 },
    );

}

method BUILD {

    my ( $linegroup, $dircode, $days, @entries )
      = split( /\t/, $self->kpointline );

    $self->_set_dir($dircode);
    $self->_set_days($days);
    $self->_set_linegroup($linegroup);

    if ( $entries[0] =~ /^\#/s ) {    # entries like "LAST STOP"
        my ( $note, $head_lines, $desttp4s ) = @entries;

        $note =~ s/^\#//s;
        $self->_set_note($note);

        my @head_lines = split( /:/, $head_lines );
        $self->_set_head_line_r( \@head_lines );

        my @desttp4s     = split( /:/, $desttp4s );
        my @destinations = map { $self->_get_destination($_) } @desttp4s;

        #$self->_set_destinations( \@destinations );

        $self->_set_primary_line( $head_lines[0] );
        $self->_set_primary_destination( $destinations[0] );
        $self->_set_primary_exception($EMPTY);
        $self->_set_primary_approxflag(0);

        return;

    }

    my @btimes;

    my %seen;

    foreach my $entry (@entries) {
        my ( $time, $line, $desttp4, $place, $exception )
          = split( /:/, $entry );
        my $btime = Octium::Points::BTime->new(
            time      => $time,
            line      => $line,
            desttp4   => $desttp4,
            place     => $place,
            exception => $exception
        );
        push @btimes, $btime;

        $seen{line}{$line}++;
        my $destination = $btime->destination;
        $seen{destination}{$destination}++;
        $seen{place}{$place}++;
        my $approxflag = $btime->approxflag;
        $seen{approxflag}{$approxflag}++;

    }

    @btimes = Octium::Points::BTime->timesort(@btimes);
    $self->_set_btimes_r( \@btimes );

    foreach my $primary_attr (@PRIMARIES) {

        \my %seen_attr = $seen{$primary_attr};
        my $count_setter = "_set_" . $primary_attr . '_count';
        my $count        = scalar keys %seen_attr;
        $self->$count_setter($count);

        my $value_setter = "_set_primary_" . $primary_attr;
        my $primary_value
          = ( sort { $seen_attr{$a} <=> $seen_attr{$b} } keys %seen_attr )[0];
        $self->$value_setter($primary_value);

    }

    return;

}

foreach my $outputformat (qw/indd text/) {
    foreach my $attr (qw/head_lines/) {
        has "${attr}_$outputformat" => (
            isa     => 'Str',
            is      => 'ro',
            builder => "_build_${attr}_$outputformat",
            lazy    => 1,
        );
    }
}

const my $HEAD_LINE_SEPARATOR = ' / ';

method indd_head_lines {

    my @head_lines = $self->head_lines;

    if ( $self->agency eq 'BroadwayShuttle' ) {
        my $line = $self->head_line(0);
        return joinempty( $IDT->parastyle('BSHdays-dest'),
            $IDT->color($line), $line, $IDT->end_nested_style );

    }

    my ( %color_of, %seen_color );
    foreach my $head_line (@head_lines) {
        my $color = $self->actiumdb->color_of_line($head_line);
        $color_of{$head_line} = $color;
        $seen_color{$color}++;
    }

    ...;

    my $indd_head_lines;

    return $indd_head_lines;

}

method text_head_lines {
    return join( " / ", $self->head_lines );
}

Actium::immut;

__END__



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

            } ## tidy end: if ( $line =~ /BS[DN]/)
            else {
                $color = (
                    $Octium::Cmd::MakePoints::lines{$line}{Color}
                      or 'Grey80'
                );
            }
        }
        $color_of{$line}    = $color;
        $seen_color{$color} = 1;
    } ## tidy end: foreach my $line (@head_lines)

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
        my @color_head_lines = map { color( $color_of{$_}, $_ ) } @head_lines;
        $head_lines = join(
            $IDT->color('Grey80') . $head_line_separator,
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

}    ## <perltidy> end sub format_head_lines

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
    my @days = map { $weekdays{$_} } @daycodes;

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

}    ## <perltidy> end sub format_headdays

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

}    ## <perltidy> end sub format_headdest

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

} ## tidy end: sub format_approxflag

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

