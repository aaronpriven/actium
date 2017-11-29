package Actium::Import::GTFS::TripCalendars 0.012;

use Actium;
use Actium::Time;
use Actium::O::DateTime;
use DateTime::Duration;
use Text::CSV('csv');    ### DEP ###

const my $PHYLUM => 'GTFS';

use DDP;

func dates_of_serviceid ( Actium::O::Folders::Signup $signup) {

    my @calendar_ranges = calendar_ranges($signup);

    #( \my %date_column, \my @calendar_dates )
    #  = array_read_gtfs( signup => $signup, file => 'calendar_dates' );

    #p @calendar_dates;

}

const my @EARLIER_DAYS =>
  qw/sunday monday tuesday wednesday thursday friday saturday/;
const my @LATER_DAYS => @EARLIER_DAYS[ 1 .. 6, 0 ];

func calendar_ranges (Actium::O::Folders::Signup $signup) {

    \my %calendar_of = hash_read_gtfs(
        signup => $signup,
        file   => 'calendar',
        key    => 'service_id',
    );

    \my %attributes_of = hash_read_gtfs(
        signup => $signup,
        file   => 'calendar_attributes',
        key    => 'service_id',
    );

    my ( $initial, $final );
    foreach my $service_id ( keys %calendar_of ) {

        my $start = dt_from_gtfs_date( $calendar_of{$service_id}{start_date} );
        my $end
          = dt_from_gtfs_date( $calendar_of{$service_id}{end_date} );

        if (   not exists $attributes_of{$service_id}
            or not exists $attributes_of{$service_id}{service_description} )
        {
            #warn "No description for service ID $service_id";
        }
        else {
            if ( $attributes_of{$service_id}{service_description} =~ /before/ )
              # this should be replaced by an analysis of the times
            {
                \my %calendar = $calendar_of{$service_id};
                add_one_day($start);
                add_one_day($end);
                say "$service_id\t",
                  $attributes_of{$service_id}{service_description};
                say
                  join( " ", "e", $calendar_of{$service_id}->%{@EARLIER_DAYS} );
                @calendar{@LATER_DAYS} = @calendar{@EARLIER_DAYS};
                say
                  join( " ", "l", $calendar_of{$service_id}->%{@EARLIER_DAYS} );

            }

        }

    } ## tidy end: foreach my $service_id ( keys...)

    #        $initial = $start if not defined $initial or $start le $initial;
    #        $final   = $end   if not defined $initial or $end ge $initial;

    #    my $initial_date
    #      = Actium::O::DateTime->new( ymd => [ gtfs_ymd($initial) ] );
    #    my $final_date
    #      = Actium::O::DateTime->new( ymd => [ gtfs_ymd($final) ] );
    #
    #    p $initial_date;
    #    p $final_date;

} ## tidy end: func calendar_ranges

func array_read_gtfs (Actium::O::Folders::Signup :$signup, Str :$file , :$key?) {

    my $filespec = gtfs_filespec( signup => $signup, file => $file );

    \my @gtfs = csv( in => $filespec, encoding => 'UTF-8' );

    my @headers = @{ shift @gtfs };

    my %index_of;

    foreach my $idx ( 0 .. $#headers ) {
        my $header = $headers[$idx];
        $index_of{$header} = $idx;
    }

    return \%index_of, \@gtfs;

}

func hash_read_gtfs (Actium::O::Folders::Signup :$signup, Str :$file , :$key?) {
    my $filespec = gtfs_filespec( signup => $signup, file => $file );
    return csv( in => $filespec, encoding => 'UTF-8', key => $key );
}

func gtfs_filespec (Actium::O::Folders::Signup :$signup, Str :$file ) {
    my $folder = $signup->subfolder($PHYLUM);

    my $filespec = $folder->make_filespec($file);
    $filespec .= ".txt" unless $filespec =~ /\.txt\z/;

    if ( !-e $filespec ) {
        croak "GTFS file $filespec not found";
    }

    return $filespec;
}

func dt_from_gtfs_date (Str $date) {

    my $year  = substr( $date, 0, 4 );
    my $month = substr( $date, 4, 2 );
    my $day   = substr( $date, 6, 2 );

    return Actium::O::DateTime->new( ymd => [ $year, $month, $day ] );
}

{
    my $one_day = DateTime::Duration->new( days => 1 );

    func add_one_day ( Actium::O::DateTime $dt ) {
        $dt->add_duration($one_day);
        return;
    }

}

__END__

const my %num_of_month =>
  qw( Jan 101 Feb 102 Mar 103 Apr 104 May 105 Jun 106 Jul 107
  Aug 8 Sep 9 Oct 10 Nov 11 Dec 12 Sma 0);

# Smarch is an imaginary month used for placeholders when kludges are necessary

const my $TBA_NOTE     => 'Operates only on days to be announced.';
const my $TBA_NOTECODE => 'TBA';

# sorts in school year order

const my %day_sub => qw(
  Mon Monday
  Tue Tuesday
  Tues Tuesday
  Wed Wednesday
  Wednes Wednesday
  Thu Thursday
  Thurs Thursday
  Fri Friday
);

const my %num_of_day => qw(
  Monday 1 Tuesday 2 Wednesday 3 Thursday 4 Friday 5
);

my %key_of_day;
# global cache

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
                #                elsif ( $off_count < ( 1 / 3 * $on_count ) ) {
                elsif ( $off_count < $on_count ) {
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

