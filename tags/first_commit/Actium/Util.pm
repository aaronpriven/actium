# Actium/Util.pm
# Utility routines

# Subversion: $Id$

use warnings;
use 5.012;

package Actium::Util 0.001;

use Actium::Constants;
use Perl6::Export::Attrs;
use Readonly;
use List::Util;

#### MISC UTILITY ROUTINES

sub j : Export {
    return join( $EMPTY_STR, map { $_ // $EMPTY_STR } @_ );
}

sub jt : Export {
    return join( "\t", map { $_ // $EMPTY_STR } @_ );
}

sub jk : Export {
    return join( $KEY_SEPARATOR, map { $_ // $EMPTY_STR } @_ );
}

sub jn : Export {
    return join( "\n", map { $_ // $EMPTY_STR } @_ );
}

sub sk : Export {
    return split( /$KEY_SEPARATOR/, $_[0] );
}

sub st : Export {
    return split( /\t/, $_[0] );
}

sub keyreadable : Export {
    if (wantarray) {
        my @list = @_;
        s/$KEY_SEPARATOR/_/g foreach @list;
        return @list;
    }
    my $_ = shift;
    s/$KEY_SEPARATOR/_/g;
    return $_;
}

sub keyunreadable : Export {
    if (wantarray) {
        my @list = @_;
        s/_/$KEY_SEPARATOR/g foreach @list;
        return @list;
    }
    my $_ = shift;
    s/_/$KEY_SEPARATOR/g;
    return $_;
}

sub even_tab_columns :Export {
    my $list_r = shift;
    
    my @lengths;
    foreach my $line ( @{$list_r} ) {
        chomp $line;
        my @fields = split( /\t/, $line );
        for my $idx ( 0 .. $#fields ) {
            my $len = length( $fields[$idx] );
            if ( not $lengths[$idx] ) {
                $lengths[$idx] = $len;
            }
            else {
                $lengths[$idx] = List::Util::max( $lengths[$idx], $len );
            }
        }
    }
    
    my @returns;

    foreach my $line ( @{$list_r} ) {
        my @fields = split("\t", $line);
        for my $idx ( 0 .. $#fields-1 ) {
            $fields[$idx] = sprintf( '%-*s', $lengths[$idx], $fields[$idx] );
        }
        push @returns, join( " ", @fields );
    }
    
    return \@returns;

} ## tidy end: sub even_tab_columns

sub doe : Export {
    my @list = @_;
    $_ = $_ // $EMPTY_STR foreach @list;
    return wantarray ? @list : $list[0];
}

Readonly my %LEGACY_DAY => {
    qw(
      1234567 DA
      12345   WD
      6       SA
      7       SU
      67      WE
      24      TT
      25      TF
      35      WF
      135     MZ
      )
};

Readonly my %LEGACY_DIR => {
    qw(
      0 NB    1 SB
      2 EB    3 WB
      4 IN    5 OU
      6 GO    7 RT
      8 CW    9 CC
      10 1    11 2
      12 UP   13 DN
      )
};

sub legacy_day : Export {
    my $days = shift;
    $days =~ s/[^\d]//g;
    return $LEGACY_DAY{$days};
}

sub legacy_dir : Export {
    return $LEGACY_DIR{ $_[0] };
}

1;

__END__


=head1 NAME

Actium::Util - Utility functions for the Actium system

=head1 VERSION

This documentation refers to Actium::Util version 0.001

=head1 SYNOPSIS

 @list = ('Thing One' , 'Thing Two' , 'Red Fish');
 use Actium::Util ':all';
 
 $smashed = j(@list); # 'Thing OneThing TwoRed Fish'
 say jt(@list);       # "Thing One\tThing Two\tRed Fish"
 $key = jk(@list);    # "Thing One\c]Thing Two\c]Red Fish"
 $readable_key = keyreadable($key); 
                      # 'Thing One_Thing Two_Red Fish'
                      
 $string = undef;
 $string = doe($string); # now contains empty string
 
 print legacy_day('12345'); # 'WD'
 print legacy_dir('8'); # 'CW'
 
=head1 DESCRIPTION

This module contains some simple syntactic sugar. 

=head1 SUBROUTINES

=over

=item B<doe()>

This stands for "defined-or-empty." For each value passed to it, returns either 
that value, if defined, or the empty string, if not.

=back

=over

=item B<j()>

Takes the list passed to it and joins it together as a simple string. A quicker way to type "join ('' , @list)".

=back

=over

=item B<jk()>

Takes the list passed to it and joins it together, with each element separated the $KEY_SEPARATOR value from L<Actium::Constants>.
A quicker way to type "join ($KEY_SEPARATOR , @list)".

=back

=over

=item B<jt()>

Takes the list passed to it and joins it together, with each element separated by tabs. A quicker way to type 'join ("\t" , @list)'.

=back

=over

=item B<keyreadable()>

For each string passed to it, returns a string where the $KEY_SEPARATOR value from Actium::Constants is replaced by an underline (_), 
making it readable. (A quicker way to type "s/$KEY_SEPARATOR/_/g foreach @list;".)

=back

The B<legacy_day> and B<legacy_dir> routines contain definitions from 
the Hastus Standard AVL Interface, as defined by the document 
"Hastus 2006 AVL Standard Interface, Last Update: July 26, 2005". 

=item B<legacy_day)>

Takes one argument, the Hastus "Operating Days" code (which is usually one or 
more digits from 1 to 7), and returns a two-letter code for the days:

 WD Weekdays
 SA Saturday
 SU Sunday
 WE Weekend
 DA Daily
 WF Wednesday and Friday
 TT Tuesday and Thursday
 TF Tuesday and Friday
 
Ultimately, these codes (which originated at the old www.transitinfo.org 
web site) are obsolete and should be replaced since they do not allow for 
the full range of date possibilities.

=item B<legacy_dir()>

Takes one argument, the Hastus 2006 "Directions" code (see table 9.2 in the 
Hastus 2006 AVL Standard Interface document), and returns a two-letter code
representing the direction.

 Code  Meaning
 NB    Northbound
 SB    Southbound
 EB    Eastbound
 WB    Westbound
 CC    Counterclockwise
 CW    Clockwise
 IN    Inbound
 OU    Outbound
 UP    Up
 DN    Down
 GO    Go
 RT    Return
 1     One
 2     Two

Only the first six are actually used at AC Transit.

These codes also come from www.transitinfo.org. There's nothing wrong with the 
codes themselves, but because a route marked "Eastbound" may not actually 
go in an eastward direction, avoid actually displaying their meanings
to customers.

=back

=head1 DEPENDENCIES

=over

=item *

Perl 5.12

=back

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2011 

This program is free software; you can redistribute it and/or
modify it under the terms of either:

=over 4

=item * the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

=item * the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
