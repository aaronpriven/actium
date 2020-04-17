package Actium::Types 0.012;
# vimcolor: #222222

use Actium;

# Type::Tiny ### DEP ###
# Type::Tiny types for Actium

use Type::Library
  -base,
  -declare => qw( Folder File CrierStatus CrierImportance Time Dir );
use Type::Utils -all;
use Types::Standard -types;

### Folders and files

class_type Folder, { class => 'Actium::Storage::Folder' };
class_type File,   { class => 'Actium::Storage::File' };

coerce Folder, from Str, via { Actium::Storage::Folder->new($_) };
coerce File,   from Str, via { Actium::Storage::File->new($_) };

coerce Folder, from( class_type 'Octium::Folder' ),
  via { Actium::Storage::Folder->new( $_->path ) };
coerce Folder, from( class_type 'Octium::Folders::Signup' ),
  via { Actium::Storage::Folder->new( $_->path ) };

### Time

class_type Time, { class => 'Actium::Time' };
coerce Time, from Str, via { Actium::Time->from_str($_) };
# can't coerce from a number because '515' could be a time number
# or a string representing 5:15 am

### Direction

class_type Dir, { class => 'Actium::Dir' };
coerce Dir, from Str, via { Actium::Dir->instance($_) };

### Crier fields

declare CrierStatus,     as Int, where { -7 <= $_ and $_ <= 7 };
declare CrierImportance, as Int, where { 0 <= $_  and $_ <= 7 };

__END__

=encoding utf8

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.015

=head1 SYNOPSIS

 use <name>;
 # do something with <name>

=head1 DESCRIPTION

A full description of the module and its features.

=head1 SUBROUTINES or METHODS or ATTRIBUTES

=head2 subroutine

Description of subroutine.

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

The Actium system, and...

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

None known. Issues are tracked on Github at
L<https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues|https:E<sol>E<sol>github.comE<sol>aaronprivenE<sol>actiumE<sol>issues>.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2020

This program is free software; you can redistribute it and/or modify it
under the terms of either:

=over 4

=item *

the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version, or

=item *

the Artistic License version 2.0.

=back

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

