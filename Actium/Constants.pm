# Actium/Constants.pm
# Various constants

# Subversion: $Id$

use strict;
use warnings;

package Actium::Constants;

use 5.010;

our $VERSION = "0.001";
$VERSION = eval $VERSION;

# Constants.pm
# ACTium shared constants
# The scalars are read-only and will create an error
# if they are modified. Sadly, not so with hashes or arrays

my %constants;
my ( $name, $value );

# In /OldActium/Constants are: DAY_OF and DIR_OF
# (which I moved to HastusASI/Util, although this may change)
# and MINS_IN_12HRS which got moved to Actium::Time

## no critic (ProhibitMagicNumbers)

BEGIN {

    %constants = (
        FALSE       => \0,
        TRUE        => \( not 0 ),
        EMPTY_STR   => \q{},
        CRLF        => \qq{\cM\cJ},
        SPACE       => \q{ },
        DQUOTE      => \q{"},
        VERTICALTAB => \qq{\cK},

        # FileMaker uses this separator for repeating fields, so I do too
        KEY_SEPARATOR => \"\c]",

        LINES_TO_COMBINE => {
            #            '21'  => '20', # coming March 2010
            '72M' => '72',
            'DB1' => 'DB',
            'DB3' => 'DB',
            '83'  => '86',
            '386' => '86',
            'NC'  => 'NX4',
            'NXC' => 'NX4',
            'LC'  => 'LA',
        },

        SCHEDULE_DAYS => [qw/WD SA SU WA WU WE DA/],
        # Weekdays, Saturdays, Sundays, Weekdays-and-Saturdays,
        # Weekdays-and-Sundays, Weekends, Daily

        DIRCODES => [qw( NB SB WB EB IN OU GO RT CW CC D1 D2 UP DN )],
        
#        DAYS_FROM_TRANSITINFO => { reverse
#                 qw(
#              1234567H DA
#              12345    WD
#              6        SA
#              7H       SU
#              67H      WE
#              24       TT
#              25       TF
#              35       WF
#              135      MZ
#              )    
#        },

        TRANSITINFO_DAYS_OF => {
            qw(
              1234567H DA
              123457H  WU
              123456   WA
              12345    WD
              6        SA
              7H       SU
              67H      WE
              24       TT
              25       TF
              35       WF
              135      MZ
              )
        },

        TRANSBAY_NOLOCALS => [qw/FS L NX NX1 NX2 NX3 U W/],

        SIDE_OF => {
            ( map { $_ => 'E' } ( 0 .. 13, qw/15 16 17 20 21 23 98 99/ ) ),
            ( map { $_ => 'W' } (qw/14 18 19 22 24 25 26 97/) ),
        },

    );
    
    $constants{DAYS_FROM_TRANSITINFO} = { reverse %{$constants{TRANSITINFO_DAYS_OF}} };
    
    no warnings 'once';
    no strict 'refs';

    while ( ( $name, $value ) = each(%constants) ) {
        *{$name} = $value;    # supports <sigil>__PACKAGE__::<variable>
    }

} ## tidy end: BEGIN

sub import {
    my $caller = caller;

    no strict 'refs';

    # constants
    while ( ( $name, $value ) = each(%constants) ) {
        *{ $caller . q{::} . $name } = $value;
    }

    return;

}

1;

__END__

=head1 NAME

Actium::Constants - constants used across Actium modules

=head1 VERSION

This documentation refers to Actium::Constants version 0.001

=head1 SYNOPSIS

 use Actium::Constants;
 $new_string = join($SPACE , @whatever) . $CRLF;
   
=head1 DESCRIPTION

This module exports a series of constant values used by various Actium modules.
They will be exported by default and are also available using the 
fully-qualified form, e.g., $Actium::Constants::CRLF .

=head1 CONSTANTS

See the code for the values of the constants. Most are obvious. Some exceptions:

=over

=item $KEY_SEPARATOR

This contains the C<^]> character (ASCII 29, "Group Separator"), which is 
used by FileMaker to separate entries in repeating fields. It is also used by
various Actium routines to separate values, e.g., the Hastus Standard AVL 
routines use it in hash keys when two or more values are needed to uniquely 
identify a record. (This is the same basic idea as that intended by perl's 
C<$;> variable [see L<perlvar/$;>].)

=item %LINES_TO_COMBINE

This contains a hard-wired hash of lines. Each key is a line that should be 
consolidated with another line on its schedule: for example, 59A should 
appear with 59, and 72M should appear with 72. It is not possible to simply
assume that a line should appear with all its subsidiary lines since some lines
do not fit this pattern (386 and 83 go on 86 while 72R does not go on 72).

This is not the right place to store this information; 
it should be moved to a user-accessible database.

=item @SCHEDULE_DAYS

This is a list of valid schedule day codes. Each set of schedules is either the set 
of schedules for weekdays (WD), Saturdays (SA), or Sundays (SU). Sometimes these can
be combined, so we have combinations: weekends (WE), and every day (DA). For completeness we also
have weekdays and Saturdays (WA) and weekdays and Sundays (WU), although usage is expected to be
extremely rare.

=back

=head1 BUGS AND LIMITATIONS

See L</%LINES_TO_COMBINE>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 LICENSE AND COPYRIGHT

This module is free software; you can redistribute it and/or modify it under 
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
