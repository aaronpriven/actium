#!/usr/bin/env perl

use 5.022;
use warnings;
use autodie;

use FindBin qw($Bin);    ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

our $VERSION = 0.012;

use Actium::Preamble;

const my $RIGHTMOST_COL => 90;

my ( @wkdays, @dates );
my ( $currentrow, $minrow, $maxrow, $mincol, $maxcol, $sheet );

my %num_of_month
  = qw( Jan 1 Feb 2 Mar 3 Apr 4 May 5 Jun 6 Jul 7 Aug 8 Sep 9 Oct 10 Nov 11 Dec 12);

my @months
  = qw(January February March April May June July August September October November December);

my %day_sub = qw(
  Mon Monday
  Tue Tuesday
  Tues Tuesday
  Wed Wednesday
  Wednes Wednesday
  Thu Thursday
  Thurs Thursday
  Fri Friday
);

my %num_of_day = qw(
  Monday 1 Tuesday 2 Wednesday 3 Thursday 4 Friday 5
);

my %key_of_day;

my %blocks_of_note;
my %day_of_block;

foreach my $file (@ARGV) {

    say "\n$file";

    $sheet = open_xlsx($file);

    my @dates = nextline();

    @dates = @dates[ 6 .. $RIGHTMOST_COL ];

    foreach (@dates) {
        my ( $day, $month ) = split(/-/);

        my $monthnum = $num_of_month{$month};

        $_ = "$month. $day";

        s/May\./May/;
        s/Jul\./July/;
        s/Jun\./June/;
        s/Mar\./March/;
        s/Apr\./April/;
        s/Sep\./Sept./;

        $key_of_day{$_} = $monthnum * 100 + $day;
    }

    @wkdays = nextline();
    @wkdays = @wkdays[ 6 .. $RIGHTMOST_COL ];

    @wkdays = map { $day_sub{$_} } @wkdays;

    my @uniq_wkdays = u::uniq @wkdays;

    nextline();    #  ignore counts of how many are on

    while ( my @values = nextline() ) {

        @values = @values[ 0 .. $RIGHTMOST_COL ];    # Procrustes

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

        print "Block $block: ";

        my ( @on, @also );
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
                push @on, $wkdy;
            }
            elsif ( $off_count < ( 1 / 4 * $on_count ) ) {
                $pure_days = 0;
                push @on,
                    $wkdy
                  . ' except '
                  . displaydates( $dates_off_of_wkdy{$wkdy}->@* );
            }
            else {
                $pure_days = 0;
                push @also, $dates_on_of_wkdy{$wkdy}->@*;
            }

        } ## tidy end: foreach my $wkdy (@uniq_wkdays)

        if ( not @on and not @also ) {
            say 'No schedules.';
            next;
        }

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
            $note .= displaydates(@also) . ".";
        }
        else {
            $note .= ".";
        }

        say $note ;

        if ($pure_days) {
            $day_of_block{$block} = join( '', map { $num_of_day{$_} } @on );
        }
        else {
            push @{ $blocks_of_note{$note} }, $block;
        }

    } ## tidy end: while ( my @values = nextline...)

} ## tidy end: foreach my $file (@ARGV)

use Data::Printer;

p %day_of_block;
p %blocks_of_note;

##### END OF MAIN ####

sub displaydates {
    my @dates = sort { $key_of_day{$a} <=> $key_of_day{$b} } @_;

    #foreach my $date (@dates) {
    #    substr( $date, -2, 0, '/' );
    #}

    return u::joinseries(@dates);

}

sub open_xlsx {

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

    ( $minrow, $maxrow ) = $sheet->row_range();
    ( $mincol, $maxcol ) = $sheet->col_range();

    $currentrow = $minrow;

    return $sheet;
} ## tidy end: sub open_xlsx

sub nextline {

    if ( not defined wantarray ) {
        $currentrow++ unless $currentrow == $maxrow;
        return;
    }

    return if $currentrow >= $maxrow;

    my @cells
      = map { $sheet->get_cell( $currentrow, $_ ) } ( $mincol .. $maxcol );

    my @values = map {
        defined ? $_->value : $EMPTY } @cells;
        
    @values = cleanvalues(@values);
    return if ( u::none {$_} @values );

    $currentrow++;

    return @values;
}


sub cleanvalues {
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

###### may not be used ####

__END__

sub daterange_indices {
    my @indices;
    my $rtype = u::reftype( $_[0] );
    if ( defined $rtype and $rtype eq 'ARRAY' ) {
        @indices = @{ $_[0] };
    }
    else {
        @indices = @_;
    }
    @indices = sort { $a <=> $b } @indices;
    return @indices;
}

sub daterange_nocompress {
    my @indices       = daterange_indices(@_);
    my @thesedaydates = datetoprint(@indices);
    my $final_daydate = pop @thesedaydates;
    my $date_str      = join( "; ", @thesedaydates ) . " and $final_daydate";
    return $date_str;
}

sub datetoprint {
    my @datestrs = map {"$wkdays[$_]., $dates[$_]"} @_;
    return @datestrs if wantarray;
    return $datestrs[0];
} ## tidy end: map

      sub currentpair_str {
        my @pair  = @_;
        my $rtype = u::reftype( $pair[0] );
        if ( defined $rtype and $rtype eq 'ARRAY' ) {
            @pair = @{ $pair[0] };
        }
        $pair[1] //= "-";
        return "[$pair[0]/$pair[1]]";
    }

    sub daterange {
        my @indices = daterange_indices(@_);

        my @index_pairs;
        my @current_pair = ( $indices[0] );
        foreach my $thisindex ( @indices[ 1 .. $#indices ] ) {

            my $current_final = $current_pair[-1];
            # that's the last entry of the current pair --
            # could be the first entry, too, if there's only one

            if ( $current_final == $thisindex - 1 ) {
                # if the current final day is this day -1,
                $current_pair[1] = $thisindex;
                # set the last item to be this day.
            }
            else {
                push @index_pairs, [@current_pair];
                @current_pair = ($thisindex);
                # otherwise make a new current pair
            }

        }

        push @index_pairs, [@current_pair];

        my @all_datestrs;
        foreach my $pair (@index_pairs) {
            my $datestr;
            if ( @{$pair} == 2 ) {
                $datestr
                  = datetoprint( $pair->[0] )
                  . '&ndash;'
                  . datetoprint( $pair->[1] );
            }
            else {
                $datestr = datetoprint( $pair->[0] );
            }
            push @all_datestrs, $datestr;

        }

        return @all_datestrs;

    } ## tidy end: sub daterange

    sub get_first_and_last {
        my @skedvals = @_;

        my $first = 0;
        $first++ while $skedvals[$first] eq 'off';

        my $last = $#skedvals;
        $last-- while $skedvals[$last] eq 'off';

        return $first, $last;

    }

    sub clean_dismissal {
        my $dismissal = shift;

        $dismissal =~ s#not served/(.*)#$1-no service#;
        $dismissal =~ s#(.*)/\s*not served#$1-no service#;
        $dismissal =~ s#\s*\(No service\)#-no service#i;

        my @dismissals = split( m#/#, $dismissal );

        for (@dismissals) {    # aliases $_

            s/\ANO PM\z/(No afternoon service)/i;
            s/Finals\s*-\s*verify/verify/i;
            s/leave at\s*//;
            s/\s*leave\z//;
            s/Noon/12:00 noon/;
            s/\s*pick up//;
            s{(\d)([A-Za-z]}{$1 $2};
            s/a\z/a.m./;
            s/p\z/p.m./;
            s/AM/a.m./i;
            s/PM/p.m./i;
            s/(\d)$/$1 p.m./;
            s/verify/(to be determined)/i;
            s/-\s*no service/ (Service will not operate)/i;
            s/(Line )? \d * tripper //;
        ## s/(\d? \d ) ( \d \d ) / $1 : $2 /x;

      } ## tidy end: map

      $dismissal = join( " or ", @dismissals );

    $dismissal = "at $dismissal" unless $dismissal =~ /^\(/;

    return $dismissal;

} ## tidy end: sub nextline

sub print_table {

    my $tablefh    = shift;
    my $header     = shift;
    my @tabledates = @_;

    my $columns = 3;

    while ( @tabledates % $columns != 0 ) {
        push @tabledates, '&nbsp;';
    }
    my $rows = ( @tabledates / $columns );

    say $tablefh
'<p><table border="1" width="90%" cellspacing="0" cellpadding="6" style="float:none;border-collapse:collapse;border-width:1px;margin-bottom:1em;">';
    say $tablefh
qq[<thead><tr><th style="border-width:1px;border-collapse:collapse;text-align: left;" colspan=$columns>$header</th></tr></thead>];
    say $tablefh '<tbody>';

    for my $row ( 0 .. $rows - 1 ) {
        print $tablefh '<tr>';
        for my $col ( 0 .. $columns - 1 ) {
            my $thisdateidx = ( ( $rows * $col ) + $row );
            my $thisdate = $tabledates[$thisdateidx] // "ERROR";
            print $tablefh
qq[<td width="30%" style="border-width:1px;border-collapse:collapse;">$thisdate</td>];
        }
        say $tablefh '</tr>';
    }

    say $tablefh '</tbody></table></p>';

} ## tidy end: sub print_table
