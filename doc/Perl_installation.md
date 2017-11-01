# Perl installation for Actium

## New instructions as of 10/9/2017.

Log in as Octavian (administrative user)

1. Update Xcode

2. Install FileMaker ODBC driver

3. Install ODBC Manager

4. Create a "System DSN" for ActiumFM (fm70.triple8.net,
ACTransit_Actium, etc. In "Language Options" uncheck automatic and set
the results to utf-8.

5. Install homebrew from brew.sh.  Homebrew requires a working SSL
connection, so connect to the Internet via WiFi temporarily, bypassing
the District's Zscaler software, until done with installing things via
Homebrew.

6. install unixodbc via homebrew.

7. the Homebrew ODBC home is /usr/local/Cellar/unixodbc/2.3.2. Replace
the .ini fles in /usr/local/Cellar/unixodbc/2.3.2/etc with symlinks to
the system .ini files. 

8. Install openssl with homebrew. Add path to the openssl to the PATH
environment variable

9. Install ghostscript with homebrew

10. Install perlbrew from perlbrew.pl

11. perlbrew install-cpanm

12. perlbrew -- Install latest stable Perl 5 (perl 5.26.1)

13. Go through dependencies of Actium and install them using cpanm 
(use find-deps.pl to get list of dependencies).

## Eclipse and Perl::Tidy::Sweetened

The way I got this to work is to replace the file "perlutils/perltidy/perltidy"
in the archive org.epic.perleditor_0.6.39.jar with a copy of "perltidier" from
the Perl::Tidy::Sweetened distribution, and made sure that a "use lib <location
to Perl::Tidy::Sweetened library>" line was put in the file. (Note that this
should be the *last* "use lib", because "use lib" unshifts onto @INC, and if
the system libraries are added after this, those will be used first. At the
moment the cpan version of Perl::Tidy::Sweetened does not handle closing side
comments correctly.)

## COPYRIGHT & LICENSE

Copyright 2011-2017

The Actium system is free software; you can redistribute it and/or
modify it under the terms of either:

* the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

* the Artistic License version 2.0.

This system is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
