package Actium::Constants 0.012;

### TO BE PHASED OUT ###
# but there are too many using it at this point to eliminate it entirely

use Actium;

sub import {
    my $class  = shift;
    my $caller = caller;

    no strict 'refs';
    no warnings 'once';
    *{ $caller . '::EMPTY' }             = \$Actium::EMPTY;
    *{ $caller . '::CRLF' }              = \$Actium::CRLF;
    *{ $caller . '::SPACE' }             = \$Actium::SPACE;
    *{ $caller . '::MINS_IN_12HRS' }     = \$Actium::MINS_IN_12HRS;
    *{ $caller . '::KEY_SEPARATOR' }     = \$Actium::KEY_SEPARATOR;
    *{ $caller . '::TRANSBAY_NOLOCALS' } = \@Actium::TRANSBAY_NOLOCALS;
    *{ $caller . '::DIRCODES' }          = \@Actium::DIRCODES;
}

1;

__END__

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

