# Actium/Points/Column.pm

# Object for a single column in an InDesign point schedule

use warnings;
use strict;

use 5.010;

use sort ('stable');

package Actium::O::Points::Column 0.008;

use Moose;                             ### DEP ###
use MooseX::SemiAffordanceAccessor;    ### DEP ###
use Moose::Util::TypeConstraints;      ### DEP ###

use namespace::autoclean;              ### DEP ###

use Actium::Constants;
use Actium::Time ('timenum');
use Const::Fast;                       ### DEP ###

use Actium::Text::InDesignTags;
const my $IDT => 'Actium::Text::InDesignTags';

my $get_tp_value = sub {

    my $tp4 = shift;

    no warnings 'once';
    my $tpdest = $Actium::Cmd::MakePoints::places{$tp4}{c_destination};

    if ($tpdest) {
        return $tpdest;
    }
    else {
        warn "No timepoint found for $tp4";
        return $tp4;
    }

};

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    my $kpoint = shift;

    if ( ref $kpoint ) {
        return $class->$orig(@_);
    }

    my $display_stopid = shift;

    my ( $linegroup, $dircode, $days, @entries )
      = split( /\t/, $kpoint );
    if ( $entries[0] =~ /^\#/s ) { # entries like "LAST STOP"
        my ( $note, $head_lines, $desttp4s ) = @entries;
        $note =~ s/^\#//s;
        my @head_lines = split( /:/, $head_lines );
        my @desttp4s   = split( /:/, $desttp4s );

        my @destinations;
        foreach my $desttp4 (@desttp4s) {
            push @destinations, $get_tp_value->($desttp4);
        }

        return $class->$orig(
            linegroup           => $linegroup,
            days                => $days,
            dircode             => $dircode,
            note                => $note,
            head_line_r         => \@head_lines,
            primary_line        => $head_lines[0],
            primary_destination => $destinations[0],
            primary_exception   => '',
            display_stopid      => $display_stopid,
        );
    } ## tidy end: if ( $entries[0] =~ /^\#/s)

    my ( @times, @lines, @destinations, @places, @exceptions, @approxflags );

    my %time_of;

    foreach (@entries) {
        my ( $time, $line, $destination, $place, $exception ) = split(/:/);
        my $timenum = timenum($time);
        $time_of{$_} = $timenum;
    }

    @entries = sort { $time_of{$a} <=> $time_of{$b} } @entries;

    foreach (@entries) {
        my ( $time, $line, $destination, $place, $exception ) = split(/:/);
        push @times, $time;
        push @lines, $line;
        $destination = $get_tp_value->($destination);
        push @destinations, $destination;
        push @places,       $place;
        push @approxflags, ( $place ? 0 : 1 );
        push @exceptions, $exception;
    }

    return $class->$orig(
        {   linegroup      => $linegroup,
            days           => $days,
            dircode        => $dircode,
            time_r         => \@times,
            line_r         => \@lines,
            destination_r  => \@destinations,
            exception_r    => \@exceptions,
            place_r        => \@places,
            approxflag_r   => \@approxflags,
            display_stopid => $display_stopid,
        }
    );

};

my $head_line_separator = q</>;

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
        default => $EMPTY_STR,
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
    isa => 'Int',
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

    my $pstyle = $#head_lines ? 'dropcapheadmany' : 'dropcaphead';

    foreach my $line (@head_lines) {
        {
            no warnings 'once';
            if ( $line =~ /BS[DNH]/ ) {
                $color = $line;

                if ( $line eq 'BSN' ) {
                    my $days = $self->days;
                    $line = 'FRI NIGHT' if $days eq '5';
                    #$line = 'SAT NIGHT'       if $days eq '6';
                    $line = 'FRI & SAT NIGHT' if $days eq '6';
                    $line = 'FRI & SAT NIGHT' if $days eq '56';
                    $line = 'MON' . $IDT->endash . 'THU NIGHT'
                      if $days eq '12345';    # ugly ugly ugly hack,
                                              # I should really fix the data
                }
                elsif ( $line eq 'BSD' or $line eq 'BSH' ) {
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

            } ## tidy end: if ( $line =~ /BS[DNH]/)
            else {
                $color = (
                    $Actium::Cmd::MakePoints::lines{$line}{Color}
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
    $self->append_to_formatted_header( $head_lines . $SPACE );

    #$self->set_formatted_header
    #      ($self->formatted_header . $head_lines . $SPACE);

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
