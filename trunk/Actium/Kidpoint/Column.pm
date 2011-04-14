# Kidpoint/Column.pm

# Object for a single column in an InDesign point schedule

# legacy stage 3, mostly

use warnings;
use strict;

use 5.010;

use sort ('stable');

package Actium::Kidpoint::Column;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Moose::Util::TypeConstraints;

use Actium::AttributeHandlers ( 'arrayhandles',
    'arrayhandles_ro', 'hashhandles' );
use Actium::Constants;
use Actium::Time ('timenum');
use IDTags;

around BUILDARGS => sub {

    my $orig  = shift;
    my $class = shift;

    my ( $linegroup, $dircode, $days, @entries ) = split( /\t/, $_[0] );

    if ( $entries[0] =~ /^\#/s ) {
        my ( $note, $head_lines, $destinations ) = @entries;
        $note =~ s/^\#//s;
        my @head_lines   = split( /:/, $head_lines );
        my @destinations = split( /:/, $destinations );

        return $class->$orig(
            linegroup           => $linegroup,
            days                => $days,
            dircode             => $dircode,
            note                => $note,
            head_line_r         => \@head_lines,
            primary_line        => $head_lines[0],
            primary_destination => $destinations[0],
            primary_exception   => '',
        );
    }

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
        push @times,        $time;
        push @lines,        $line;
        push @destinations, $destination;
        push @places,       $place;
        push @approxflags, ( $place ? 0 : 1 );
        push @exceptions, $exception;
    }

    return $class->$orig(
        {   linegroup     => $linegroup,
            days          => $days,
            dircode       => $dircode,
            time_r        => \@times,
            line_r        => \@lines,
            destination_r => \@destinations,
            exception_r   => \@exceptions,
            place_r       => \@places,
            approxflag_r  => \@approxflags,
        }
    );

};

#my $head_line_separator = $SPACE . IDTags::bullet . $SPACE;
my $head_line_separator = q</>;

has [qw/linegroup days dircode/] => (
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

foreach my $attr (qw<line time destination place exception >) {
    has "${attr}_r" => (
        traits  => ['Array'],
        is      => 'ro',
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        handles => { arrayhandles_ro($attr) },
    );
}

foreach my $attr (qw<formatted_time head_line>) {
    has "${attr}_r" => (
        traits  => ['Array'],
        is      => 'rw',
        isa     => 'ArrayRef[Str]',
        default => sub { [] },
        handles => { arrayhandles($attr) },
    );
}

has 'foot_r' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { [] },
    handles => { arrayhandles( 'foot', 'feet' ) },
);

has approxflag_r => (
    traits  => ['Array'],
    is      => 'ro',
    isa     => 'ArrayRef[Bool]',
    default => sub { [] },
    handles => { arrayhandles_ro('approxflag') },
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

    foreach my $line (@head_lines) {
    { no warnings 'once';
        $color = ( $main::lines{$line}{Color} or 'Grey80' );
    }
        $color_of{$line}    = $color;
        $seen_color{$color} = 1;
    }

    my $pstyle = $#head_lines ? 'dropcapheadmany' : 'dropcaphead';

    my $length_head_lines
      = length( join( $head_line_separator, @head_lines ) ) + 1;

    if ( scalar( keys %seen_color ) == 1 ) {
        $head_lines
          = IDTags::color( $color, join( $head_line_separator, @head_lines ) );
        $head_lines = IDTags::parastyle( $pstyle,
            IDTags::dropcapchars($length_head_lines), $head_lines );

    }
    else {
        my @color_head_lines = map { color( $color_of{$_}, $_ ) } @head_lines;
        $head_lines = join(
            IDTags::color( 'Grey80', $head_line_separator ),
            @color_head_lines
        );

        $head_lines = IDTags::parastyle( $pstyle,
            IDTags::dropcapchars($length_head_lines), $head_lines );

    }

    $self->append_to_formatted_header( $head_lines . $SPACE );
    #$self->set_formatted_header
    #      ($self->formatted_header . $head_lines . $SPACE);

    return;

}    ## <perltidy> end sub format_head_lines

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

    $self->append_to_formatted_header( IDTags::bold( ucfirst($days) ) );

    return;

}    ## <perltidy> end sub format_headdays

sub format_headdest {

    my $self    = shift;
    my $desttp4 = $self->primary_destination;
    my $tpname;
    { no warnings 'once';
    $tpname  = $main::timepoints{$desttp4}{TPName};
    }

    my $dest;

    if ($tpname) {
        $dest = " to $tpname";
    }
    else {
        $dest = $desttp4;
        warn "No timepoint found for $desttp4";
    }

    my $dir = $self->dircode;

    if ( $dir eq '8' ) {
        $dest .= ' (Clockwise loop)';
    }
    elsif ( $dir eq '9' ) {
        $dest .= ' (Counterclockwise loop)';
    }

    $dest =~ s{\.*\z}{\.}sx;    # put exactly one period at the end

    $self->append_to_formatted_header($dest);
    return;

}    ## <perltidy> end sub format_headdest

sub format_approxflag {
    my $self = shift;

    return if $self->has_note;

    my $primary_approxflag = $self->primary_approxflag;

    $self->append_to_formatted_header(
        $primary_approxflag
        ? ' Approximate departure times:'
        : ' Scheduled departure times:'
    );

    return;

}

no Moose::Util::TypeConstraints;
no Moose;
__PACKAGE__->meta->make_immutable;    ## no critic (RequireExplicitInclusion);

1;

__END__


