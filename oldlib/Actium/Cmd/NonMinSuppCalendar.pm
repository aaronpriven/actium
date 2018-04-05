package Actium::Cmd::NonMinSuppCalendar 0.012;

# This generates a supplementary calendar from the list of schools.
# With luck this will be a temporary measure that will go away soon.

use Actium;
use Actium::Time;
use Actium::Import::Xhea::SuppCalendar;
use DDP;
use Array::2D;

my %onoff_of = (
    'reg'           => '-ON-',
    'reg (am only)' => '-ON-',
    'reg (early)'   => '-early-',
    'off'           => '-off-',
    '%T'            => '-early-',
    '%T (off)'      => '-off-',
    '%T (keep pm)'  => '-ON-',
    '%T redu (off)' => '-off-',
    '%Tredu (off)'  => '-off-',
    'redu (off)'    => '-off-',
    'reg (off)'     => '-off-',
    'reg (pm off)'  => '-pmoff-',
    '%Tredu (off)'  => '-off-',
);

my $path
  = '/Users/apriven/Dropbox (AC_PubInfSys)/Desktop files/School Calendar F17/';

our ( @trips, @tripheaders, %status_of, %matchstatus_of, @days, @dates );

sub START {

    get_trips();
    get_calendars();

    my @lines;

    my $result = Array::2D->new(
        [ ($EMPTY) x scalar @tripheaders, @dates ],
        [ ($EMPTY) x scalar @tripheaders, @days ],
        [@tripheaders],
    );

  TRIP:
    foreach \my %trip (@trips) {

        my $is_pm = $trip{Start} =~ /p/i;

        my @calendar_line = @trip{@tripheaders};
        my @schools;

        ### calendar line

        if ( $trip{School} =~ /\|/ ) {    # multiple schools
            @schools = split( /\|/, $trip{School} );
            foreach (@schools) {
                s/\A\s+//;
                s/\s+\z//;
            }

            if ( Actium::any { not exists $status_of{$_} } @schools ) {
                push @calendar_line, "NO STATUS";
            }
            else {
                foreach my $day_idx ( 0 .. $#dates ) {
                    my @matchstatuses_of_day
                      = map { $matchstatus_of{$_}[$day_idx] } @schools;
                    my @results_of_day
                      = map { onoff( matchstatus => $_, is_pm => $is_pm ) }
                      @matchstatuses_of_day;

                    if ( Actium::all_eq(@results_of_day) ) {
                        push @calendar_line, $results_of_day[0];
                    }
                    elsif (
                        Actium::all { $_ eq '-early-' or $_ eq '-ON-' }
                        @results_of_day
                      )
                    {
                        push @calendar_line, '-ON-';
                    }
                    else {
                        push @calendar_line, '***';
                        warn "Unable to determine in " . $trip{School};
                    }
                }    ## tidy end: foreach my $day_idx ( 0 .. ...)

            }    ## tidy end: else [ if ( Actium::any { not...})]

        }         ## tidy end: if ( $trip{School} =~ ...)
        else {    # one school
            @schools = $trip{School};

            if ( not exists $status_of{ $schools[0] } ) {
                push @calendar_line, 'NO STATUS';
                push @$result,       \@calendar_line;
                next TRIP;
            }
            foreach my $matchstatus ( $matchstatus_of{ $schools[0] }->@* ) {
                push @calendar_line,
                  onoff( matchstatus => $matchstatus, is_pm => $is_pm );
            }
        }

        push @$result, \@calendar_line;

        my %statushash_of
          = ( status => \%status_of, match => \%matchstatus_of );

        foreach my $school (@schools) {
            foreach my $statushash_key ( sort keys %statushash_of ) {
                my @line = lineintro( $statushash_key, $school );
                my $thishash_r = $statushash_of{$statushash_key};
                if ( exists $thishash_r->{$school} ) {
                    push @line, $thishash_r->{$school}->@*;
                }
                else {
                    push @line, 'NO STATUS';
                }
                push @$result, \@line;
            }
        }

    }    ## tidy end: TRIP: foreach \my %trip (@trips)

    $result->xlsx( output_file => "$path/nonmin_calendar.xlsx" );

}    ## tidy end: sub START

func lineintro ( $linetype, $school ) {
    return $EMPTY, $linetype, $school, ($EMPTY) x ( scalar @tripheaders - 3 );
}

my @dates2use = ( 27 .. 116 );
# these are the dates in calendar corresponding to aug 20 thru dec 22

sub get_calendars {

    my $fname
      = $path
      . 'School Dismissal Time Calendar_2017-2018_revised_07 21 17_215pm.xlsx';

    my $sheet = _open_xlsx($fname);

    for ( 1 .. 3 ) {
        # throw away first lines
        _nextline($sheet);
    }
    @dates = ( _nextline($sheet) )[@dates2use];
    @days  = ( _nextline($sheet) )[@dates2use];

    while ( my @vals = _nextline($sheet) ) {
        my $school = $vals[2];
        next unless $school;
        $school =~ s/ \s* \| \s* / \| /x;
        my @statuses = @vals[@dates2use];

        $status_of{$school} = \@statuses;

        my @matchstatuses = map {
            my $matchstatus = lc($_);
            $matchstatus =~ s/[0-9]?[0-9]:[0-9][0-9](?::00)? ?[Pp]?[Mm]?/%T/g;
            $matchstatus =~ s[%T/%T][%T];
            $matchstatus;
        } @statuses;

        $matchstatus_of{$school} = \@matchstatuses;

    }

    return;

}    ## tidy end: sub get_calendars

func onoff (:$matchstatus, :$is_pm) {

    my $onoff = $onoff_of{$matchstatus};
    if ( $onoff eq '-early-' or $onoff eq '-pmoff-' ) {
        $onoff = $is_pm ? '-off-' : '-ON-';
    }
    return $onoff;

}

sub get_trips {

    my $fname = $path . 'non-minimum-trips.xlsx';
    my $sheet = _open_xlsx($fname);

    @tripheaders = _nextline($sheet);

    while ( my @vals = _nextline($sheet) ) {
        my %trip;
        @trip{@tripheaders} = @vals;
        $trip{School} =~ s/ \s* \| \s* / \| /x;
        push @trips, \%trip;
    }

    return;

}

sub _nextline  { goto &Actium::Import::Xhea::SuppCalendar::_nextline }
sub _open_xlsx { goto &Actium::Import::Xhea::SuppCalendar::_open_xlsx }

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

