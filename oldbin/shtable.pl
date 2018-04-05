#!/ActivePerl/bin/perl

use 5.022;
use warnings;
use autodie;

use FindBin qw($Bin);    ### DEP ###
use lib ("$Bin/../lib"); ### DEP ###

our $VERSION = 0.010;

# this program is used every year to convert the supplementary schools
# calendar from Excel to HTML.

use Actium;

my $file = shift @ARGV;

my $sheet = open_xlsx($file);

my ( $currentrow, $minrow, $maxrow, $mincol, $maxcol );

nextline();    # Overload Protection Trip
nextline();    # first day
nextline();    # last day

my @dates = nextline();

@dates = @dates[ 6 .. 230 ];

foreach (@dates) {
    my ( $day, $month ) = split(/-/);
    $_ = "$month. $day";
    s/May\./May/;
    s/Jul\./July/;
    s/Jun\./June/;
    s/Mar\./March/;
    s/Apr\./April/;
    s/Sep\./Sept./;
}

my @wkdays = nextline();
@wkdays = @wkdays[ 6 .. 230 ];

my %earlies_of;
my %offs_of;

my %schooltext_of;

open my $outfh, '>', 'schooltable.html';

while ( my @values = nextline() ) {

    @values = @values[ 0 .. 230 ];

    my ( $division, $district, $school, $first, $amroutes, $pmroutes,
        @skedvals ) = @values;
    $school =~ s/\(Rockridge BART\)/School/;
    $school =~ s/\s\*.*//;
    $school =~ s/Jr\.?/Junior/;
    $school =~ s/Mt\.?/Mount/;

    say "[[$currentrow]]" unless $school;

    my @amroutes = cleanvalues( split( /,/, $amroutes ) );
    my @pmroutes = cleanvalues( split( /,/, $pmroutes ) );

    local $LIST_SEPARATOR = '/';

    #say "|@amroutes|@pmroutes|";
    my @oldroutes = @amroutes;

    foreach my $pmroute (@pmroutes) {
        @amroutes = grep { $pmroute !~ /$_\s*\(opt\)/i } @amroutes;
       #delete anything from @amroutes that is the same as a $pmroute with (OPT)

    }

    #say "[@oldroutes][@amroutes][@pmroutes]" if @oldroutes != @amroutes;

    my @routes = u::uniq sort ( @amroutes, @pmroutes );
    @routes = grep { !/opt/i } @routes;

    next unless @routes;

    foreach (@routes) {
        #s/([0-9]+) tripper/$1 (supplementary trips)/ foreach @routes;
        s/\s*tripper//;
        $_ = "$_ (supplementary trips)" unless /^6\d\d/;
    }

    my ( $first_idx, $last_idx ) = get_first_and_last(@skedvals);
    my ( $opening, $closing )
      = map { datetoprint($_) } ( $first_idx, $last_idx );

    my @offs;
    my %early_of;
    for my $idx ( $first_idx .. $last_idx ) {
        my $skedval = $skedvals[$idx];
        next unless $skedval;
        next if fc($skedval) eq fc('reg');
        next if fc($skedval) eq fc('chin');
        if ( $skedval eq 'off' ) {
            push @offs, $idx;
            next;
        }
        if ( lc($skedval) eq lc('exams') ) {
            $skedval = 'verify';
        }

        my $dismissal = clean_dismissal($skedval);

        push @{ $early_of{$dismissal} }, $idx;
    }

    open my $textfh, '>', \my $schooltext;

    say $textfh "<h2 id='$school' style='font-size:120%;'>$school</h2>";

    my $plural = $#routes ? 's' : '';

    my $all_routes = join( ", ", @routes );
    say $textfh "<p>Bus line$plural affected: $all_routes</p>" if @routes;

    say $textfh "<p>First day of service: $opening.<br>";
    say $textfh "Last day of service: $closing.</p>";

    if (@offs) {
        print_table( $textfh, 'Holiday/vacation (no service):',
            daterange(@offs) );
    }

    my $early_count = scalar keys %early_of;
    if ($early_count) {
        my @dismissal_times = sort keys %early_of;
        if ( $dismissal_times[-1] =~ /noon/i ) {
            unshift @dismissal_times, pop @dismissal_times;
        }    # the last shall be first

        foreach my $dismissal_time (@dismissal_times) {
            print_table(
                $textfh,
                "Early dismissal $dismissal_time",
                daterange( $early_of{$dismissal_time} )
            );
        }
    }

    $earlies_of{$school} = \%early_of;
    $offs_of{$school}    = \@offs;

    close($textfh);
    $schooltext_of{$school} = $schooltext;
}    ## tidy end: while ( my @values = nextline...)

foreach my $school ( sort keys %schooltext_of ) {
    say $outfh $schooltext_of{$school};
}

##### END OF MAIN ####

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
    return wantarray ? @datestrs : $datestrs[0];
}

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

}    ## tidy end: sub daterange

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
}    ## tidy end: sub open_xlsx

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

#sub nextline_old {
#    my $line = readline($schoolfh);
#    return unless defined $line;
#    my @values = split( "\t", $line );
#
#    @values = cleanvalues(@values);
#    return if ( u::none {$_} @values );
#
#    return @values;
#
#}

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
        s/(\d)([A-Za-z])/$1 $2/;
        s/a\z/a.m./;
        s/p\z/p.m./;
        s/AM/a.m./i;
        s/PM/p.m./i;
        s/(\d)$/$1 p.m./;
        s/verify/(to be determined)/i;
        s/-\s*no service/ (Service will not operate)/i;
        s/(Line )? \d * tripper //;

        #s[(\d? \d ) ( \d \d ) ][ $1 : $2 ];

      }    ## tidy end: map

      $dismissal = join( " or ", @dismissals );

    $dismissal = "at $dismissal" unless $dismissal =~ /^\(/;

    return $dismissal;

}    ## tidy end: sub nextline

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

}    ## tidy end: sub print_table

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to <name> version 0.003

=head1 USAGE

 # brief working invocation example(s) using the most comman usage(s)

=head1 REQUIRED ARGUMENTS

A list of every argument that must appear on the command line when the
application is invoked, explaining what each one does, any restrictions
on where each one may appear (i.e., flags that must appear before or
after filenames), and how the various arguments and options may
interact (e.g., mutual exclusions, required combinations, etc.)

If all of the application's arguments are optional, this section may be
omitted entirely.

=over

=item B<argument()>

Description of argument.

=back

=head1 OPTIONS

A complete list of every available option with which the application
can be invoked, explaining wha each does and listing any restrictions
or interactions.

If the application has no options, this section may be omitted.

=head1 DESCRIPTION

A full description of the program and its features.

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

