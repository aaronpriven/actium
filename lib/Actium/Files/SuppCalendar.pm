package Actium::Files::SuppCalendar 0.012;

use Actium::Preamble;

const my %num_of_month =>
  qw( Jan 101 Feb 102 Mar 103 Apr 104 May 105 Jun 106 Jul 107
  Aug 8 Sep 9 Oct 10 Nov 11 Dec 12);

# sorts in school year order

const my @months => qw(January February March April May June July
  August September October November December);

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

    @files = grep { not( u::filename($_) =~ m/\A~/ ) } @files;
    # skip temporary files beginning with ~

    my (%next_code_of_days, %blocks_of_note, %day_of_block,
        %blocks_of_day,     %code_of_note
    );

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

        my @uniq_wkdays = u::uniq @wkdays;

        _nextline($sheet);    #  ignore counts of how many are on

        while ( my @values = _nextline($sheet) ) {

            my ( $block, $run, $school, $pullout, $pullin, $dist, @on_or_off )
              = @values;

            my ( %dates_off_of_wkdy, %dates_on_of_wkdy );

            for my $i ( 0 .. $#on_or_off ) {

                my $date = $dates[$i];
                my $wkdy = $wkdays[$i];

                if ( $on_or_off[$i] =~ /on/i ) {
                    push $dates_on_of_wkdy{$wkdy}->@*, $date;
                }
                else {    # off
                    push $dates_off_of_wkdy{$wkdy}->@*, $date;
                }
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
                elsif ( $off_count < ( 1 / 4 * $on_count ) ) {
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
                $note .= 'Operates ' . u::joinseries(@every_on);
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
                $day_of_block{$block} = $day;
                push $blocks_of_day{$day}->@*, $block;
            }
            else {
                push @{ $blocks_of_note{$note} }, $block;

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
                    }
                    else {
                        $ondays = "A";
                    }

                    $next_code_of_days{$ondays} //= 1;

                    $code_of_note{$note} = "$ondays-";
                    $code_of_note{$note} .= $next_code_of_days{$ondays};

                    $next_code_of_days{$ondays}++;

                } ## tidy end: if ( not exists $code_of_note...)

            } ## tidy end: else [ if ($pure_days) ]

        } ## tidy end: while ( my @values = _nextline...)

    } ## tidy end: foreach my $file (@files)

    my $fh = $calendar_folder->open_write('sch_cal.txt');

    foreach my $note ( sort keys %code_of_note ) {
        say $fh u::jointab( $code_of_note{$note}, $note,
            $blocks_of_note{$note}->@* );
    }

    foreach my $day ( sort keys %blocks_of_day ) {
        say $fh u::jointab( $day, $blocks_of_day{$day}->@* );
    }

    $fh->close;

    return ( \%code_of_note, \%blocks_of_note, \%day_of_block );

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

        my $sheet_key = u::refaddr($sheet);

        ( $minrow{$sheet_key}, $maxrow{$sheet_key} ) = $sheet->row_range();
        ( $mincol{$sheet_key}, $maxcol{$sheet_key} ) = $sheet->col_range();

        $currentrow{$sheet_key} = $minrow{$sheet_key};

        return $sheet;
    } ## tidy end: sub _open_xlsx

    sub _nextline {
        my $sheet     = shift;
        my $sheet_key = u::refaddr($sheet);

        if ( not defined wantarray ) {
            $currentrow{$sheet_key}++
              unless $currentrow{$sheet_key} == $maxrow{$sheet_key};
            return;
        }

        return if $currentrow{$sheet_key} >= $maxrow{$sheet_key};

        my @cells
          = map { $sheet->get_cell( $currentrow{$sheet_key}, $_ ) }
          ( $mincol{$sheet_key} .. $maxcol{$sheet_key} );

        my @values = map {
            defined ? $_->value : $EMPTY_STR } @cells;

        @values = _cleanvalues(@values);
        return if ( u::none {$_} @values );
        
        pop @values while $values[-1] eq $EMPTY_STR;
        
        $currentrow{$sheet_key}++;

        return @values;
    } ## tidy end: sub _nextline

}

sub _displaydates {

    my @dates = sort { $key_of_day{$a} <=> $key_of_day{$b} } @_;
    return u::joinseries(@dates);

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
