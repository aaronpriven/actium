#!/Actium/Files/CacheOption.pm

# All this does is have a single place to ensure that option('cache') exists
# and isn't duplicated

# Subversion: $Id$

# legacy stage 4

use 5.012;
use warnings;

package Actium::Files::CacheOption 0.001;

use Actium::Options('add_option');

add_option( 'cache=s',
        'Cache directory. Files (like SQLite files) that cannot be stored '
      . 'on network filesystems are stored here.' );

1;

__END__

=head1 NAME

Actium::Files::CacheOption - Specifies the -cache command line option to
Actium::Options

=head1 VERSION

This documentation refers to version 0.001

=head1 SYNOPSIS

 use Actium::Options ('option');
 use Actium::Files::CacheOption;
 
 $cachefolder = option('cache') || '/tmp/myprog';
   
=head1 DESCRIPTION

This module does nothing except tell Actium::Options to accept an option
called -cache, which is defined for the user as "Cache directory. Files (like 
SQLite files) that cannot be stored on network filesystems are stored here."

Since several modules need to use this option, it is necessary to specify it 
in a file that all of them will use.

=head1 DEPENDENCIES

Actium::Options.

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