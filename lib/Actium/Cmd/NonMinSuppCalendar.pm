package Actium::Cmd::NonMinSuppCalendar 0.012;

use Actium;
use Actium::Time;
use Actium::O::Folder;
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
                } ## tidy end: foreach my $day_idx ( 0 .. ...)

            } ## tidy end: else [ if ( Actium::any { not...})]

        } ## tidy end: if ( $trip{School} =~ ...)
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

    } ## tidy end: TRIP: foreach \my %trip (@trips)

    $result->xlsx( output_file => "$path/nonmin_calendar.xlsx" );

} ## tidy end: sub START

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

} ## tidy end: sub get_calendars

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

#func one_school (%trip is ref_alias) {
#
#    my $school = $trip{School};
#    my $is_pm  = $trip{Start} =~ /p/i;
#
#    return ( @trip{@tripheaders}, "NO STATUS" )
#      if ( not exists $status_of{$school} );
#
#    my @calendar_line = @trip{@tripheaders};
#
#    foreach my $matchstatus ( $matchstatus_of{$school}->@* ) {
#        push @calendar_line,
#          onoff( matchstatus => $matchstatus, is_pm => $is_pm );
#    }
#
#    my @lines = \@calendar_line;
#
#    push @lines,
#      [ lineintro( 'match', $school ), $matchstatus_of{$school}->@* ];
#    push @lines, [ lineintro( 'status', $school ), $status_of{$school}->@* ];
#
#    return @lines;
#
#} ## tidy end: func one_school

#func mixed_schools (%trip is ref_alias) {
#    my $school_concat = $trip{School};
#    my $is_pm         = $trip{Start} =~ /p/i;
#
#    my @schools = split( /\|/, $school_concat );
#
#    ### get calendar line
#
#    my @calendar_line = @tripheaders;
#
#    if ( Actium::any { not exists $status_of{$_} } @schools ) {
#        push @calendar_line, "NO STATUS";
#    }
#    else {
#        foreach my $day_idx ( 0 .. $#dates ) {
#            my @matchstatuses_of_day
#              = map { $matchstatus_of{$_}[$day_idx] } @schools;
#            my @results_of_day = map { on_off($_) } @matchstatuses_of_day;
#
#            if ( Actium::all_eq(@results_of_day) ) {
#                push @calendar_line, $results_of_day[0];
#            }
#            elsif (
#                Actium::all { $_ eq '-early-' or $_ eq '-ON-' }
#                @results_of_day
#              )
#            {
#                push @calendar_line, '-ON-';
#            }
#            else {
#                push @calendar_line, '***';
#            }
#        }
#
#    } ## tidy end: else [ if ( Actium::any { not...})]
#
#    my @lines = \@calendar_line;
#
#    ## get status line and matchstatus line for each school
#
#    foreach my $school (@schools) {
#
#        push @lines,
#          [ lineintro( 'match', $school ), $matchstatus_of{$school}->@* ];
#        push @lines,
#          [ lineintro( 'status', $school ), $status_of{$school}->@* ];
#
#    }
#    return @lines;
#
#} ## tidy end: func mixed_schools

1;

__END__


sub read_supp_calendars {
    my $calendar_folder = shift;

    my @files = $calendar_folder->glob_files('*.xlsx');

    @files = grep { not( Actium::filename($_) =~ m/\A~/ ) } @files;
    # skip temporary files beginning with ~

    my ( %next_code_of_days, %code_of_note, %calendar_of_block );

    $code_of_note{$TBA_NOTE} = $TBA_NOTECODE;

    foreach my $file (@files) {

        my $sheet = _open_xlsx($file);

        my @dates = _nextline($sheet);
        @dates = @dates[ 6 .. $#dates ];

        foreach (@dates) {
            next unless /-/;
            my ( $day, $month ) = split(/-/);

            $_ = "$month. $day";

            s/May\./May/;
            s/Jul\./July/;
            s/Jun\./June/;
            s/Mar\./March/;
            s/Apr\./April/;
            s/Sep\./Sept./;

            if ( not defined $key_of_day{$_} ) {
                my $monthnum = $num_of_month{$month};
                $key_of_day{$_} = $monthnum * 100 + $day;
            }

        }

        my @wkdays = _nextline($sheet);
        @wkdays = @wkdays[ 6 .. $#wkdays ];

        @wkdays = map { $day_sub{$_} } @wkdays;

        my @uniq_wkdays = Actium::uniq @wkdays;

        _nextline($sheet);    #  ignore counts of how many are on

      LINE:
        while ( my @refs = _nextline( $sheet, 1 ) ) {

            my @values = $refs[0]->@*;
            my @cells  = $refs[1]->@*;

            my ( $block, $run, $school, $pullout, $pullin, $dist, @on_or_off )
              = @values;

            next unless $block;

            my $pullout_cell    = $cells[3];
            my $pullout_time    = Actium::Time->from_excel($pullout_cell);
            my $pullout_timenum = $pullout_time->timenum;

            my $tripkey = "$block/$pullout_timenum";

            my ( %dates_off_of_wkdy, %dates_on_of_wkdy );

            my $has_an_on;

            for my $i ( 0 .. $#on_or_off ) {

                my $date = $dates[$i];
                my $wkdy = $wkdays[$i];

                if ( $on_or_off[$i] =~ /on/i ) {
                    push $dates_on_of_wkdy{$wkdy}->@*, $date;
                    $has_an_on = 1;
                }
                else {    # off
                    push $dates_off_of_wkdy{$wkdy}->@*, $date;
                }
            }

            if ( not $has_an_on ) {

                $calendar_of_block{$tripkey} = [ $TBA_NOTECODE, $TBA_NOTE ];
                next LINE;

            }

            my ( @on, @also, @ondays );
            my $pure_days = 1;

            foreach my $wkdy (@uniq_wkdays) {
                next unless defined $dates_on_of_wkdy{$wkdy};
                my $on_count = scalar( $dates_on_of_wkdy{$wkdy}->@* );

                next if not $on_count;

                my $off_count
                  = defined $dates_off_of_wkdy{$wkdy}
                  ? ( scalar $dates_off_of_wkdy{$wkdy}->@* )
                  : 0;

                if ( not $off_count ) {
                    push @on,     $wkdy;
                    push @ondays, $num_of_day{$wkdy};
                }
                elsif ( $off_count < ( 1 / 3 * $on_count ) ) {
                    $pure_days = 0;
                    push @on,
                        $wkdy
                      . ' except '
                      . _displaydates( $dates_off_of_wkdy{$wkdy}->@* );
                    push @ondays, $num_of_day{$wkdy};
                }
                else {
                    $pure_days = 0;
                    push @also, $dates_on_of_wkdy{$wkdy}->@*;
                }

            } ## tidy end: foreach my $wkdy (@uniq_wkdays)

            my $note = '';

            if (@on) {
                my @every_on = map {"every $_"} @on;
                $note .= 'Operates ' . Actium::joinseries(@every_on);
            }
            if (@also) {
                if (@on) {
                    $note .= ', and also on ';
                }
                else {
                    $note .= 'Operates only ';
                }
                $note .= _displaydates(@also) . ".";
            }
            else {
                $note .= ".";
            }
            if ($pure_days) {

                my $day = join( '', map { $num_of_day{$_} } sort @on );
                $calendar_of_block{$tripkey} = $day;
            }
            else {

                if ( $note eq 'Operates only Sma. 1.' ) {
                    $calendar_of_block{$tripkey} = [
                        'SR',
                        'Operates only when schools are on regular schedules.'
                    ];
                }
                elsif ( $note eq 'Operates only Sma. 2.' ) {
                    $calendar_of_block{$tripkey} = [
                        'SM',
                        'Operates only when schools '
                          . 'are on minimum day schedules.'
                    ];
                }
                else {
                    if ( not exists $code_of_note{$note} ) {

                        my $ondays;

                        if (@ondays) {
                            @ondays = sort { $a <=> $b } @ondays;
                            $ondays = join( '', @ondays );
                            $ondays =~ s/1/M/;
                            $ondays =~ s/2/T/;
                            $ondays =~ s/3/W/;
                            $ondays =~ s/4/Th/;
                            $ondays =~ s/5/F/;

                            $ondays = 'A' if length($ondays) > 2;
                        }
                        else {
                            $ondays = 'A';
                        }

                        $next_code_of_days{$ondays} //= 1;

                        $code_of_note{$note} = "$ondays-";
                        $code_of_note{$note} .= $next_code_of_days{$ondays};

                        $next_code_of_days{$ondays}++;

                    } ## tidy end: if ( not exists $code_of_note...)

                    $calendar_of_block{$tripkey}
                      = [ $code_of_note{$note}, $note ];

                } ## tidy end: else [ if ( $note eq 'Operates only Sma. 1.')]

            } ## tidy end: else [ if ($pure_days) ]

        } ## tidy end: LINE: while ( my @refs = _nextline...)

    } ## tidy end: foreach my $file (@files)

    my $fh = $calendar_folder->open_write('sch_cal.txt');

    foreach my $tripkey ( sort keys %calendar_of_block ) {
        my $cal = $calendar_of_block{$tripkey};
        say $fh Actium::jointab( $tripkey,
            Actium::is_arrayref($cal) ? @$cal : $cal );
    }

    $fh->close;
    return ( \%calendar_of_block );

} ## tidy end: sub read_supp_calendars

##### END OF MAIN ####

{

    my ( %currentrow, %minrow, %maxrow, %mincol, %maxcol );

    sub _open_xlsx {
        my $xlsx_filespec = shift;

        require Spreadsheet::ParseXLSX;    ### DEP ###

        my $parser   = Spreadsheet::ParseXLSX->new;
        my $workbook = $parser->parse($xlsx_filespec);

        if ( !defined $workbook ) {
            croak $parser->error();
        }

        my $sheet_requested = 0;
        my $sheet           = $workbook->worksheet($sheet_requested);

        if ( !defined $sheet ) {
            croak "Sheet $sheet_requested not found in $xlsx_filespec in "
              . __PACKAGE__
              . '->new_from_xlsx';
        }

        my $sheet_key = Actium::refaddr($sheet);

        ( $minrow{$sheet_key}, $maxrow{$sheet_key} ) = $sheet->row_range();
        ( $mincol{$sheet_key}, $maxcol{$sheet_key} ) = $sheet->col_range();

        $currentrow{$sheet_key} = $minrow{$sheet_key};

        return $sheet;
    } ## tidy end: sub _open_xlsx

    sub _nextline {
        my $sheet       = shift;
        my $wants_cells = shift;
        my $sheet_key   = Actium::refaddr($sheet);

        if ( not defined wantarray ) {
            $currentrow{$sheet_key}++
              unless $currentrow{$sheet_key} == $maxrow{$sheet_key};
            return;
        }

        return if $currentrow{$sheet_key} >= $maxrow{$sheet_key};

        my @cells
          = map { $sheet->get_cell( $currentrow{$sheet_key}, $_ ) }
          ( $mincol{$sheet_key} .. $maxcol{$sheet_key} );

        my @values = map { defined($_) ? $_->value : $EMPTY } @cells;

        @values = _cleanvalues(@values);
        return if ( Actium::none {$_} @values );

        pop @values while $values[-1] eq $EMPTY;

        $currentrow{$sheet_key}++;

        return @values unless $wants_cells;
        return \@values, \@cells;

    } ## tidy end: sub _nextline

}

sub _displaydates {

    my @dates = sort { $key_of_day{$a} <=> $key_of_day{$b} } @_;
    return Actium::joinseries(@dates);

}

sub _cleanvalues {
    my @values = @_;
    foreach (@values) {
        s/\A"//;
        s/"\z//;
        s/\A\s+//;
        s/\s+\z//;
        s/\.//;       # remove final periods
        s/\s+/ /g;    # convert all internal whitespace chars to a single space
    }
    return @values;
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

