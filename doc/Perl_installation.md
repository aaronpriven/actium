# Perl installation for Actium

## New instructions as of 10/9/2017 - modified mildly July 2022

Log in as Octavian (administrative user)

1. Update Xcode

2. Install FileMaker ODBC driver

3. Install ODBC Manager

4. Create a "System DSN" for ActiumFM (localhost, 
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

9. NO LONGER NEEDED (we no longer produce web maps) -- Install ghostscript with homebrew 

10. Install perlbrew from perlbrew.pl

11. perlbrew install-cpanm

12. perlbrew -- Install latest stable Perl 5 

13. Go through dependencies of Actium and install them using cpanm 
(use find-deps.pl to get list of dependencies).

(There's a bunch of stuff in the way vi is set up  to do syntax checking that I
won't include here.)

## COPYRIGHT & LICENSE

Copyright 2011-2022

The Actium system is free software; you can redistribute it and/or
modify it under the terms of either:

* the GNU General Public License as published by the Free
Software Foundation; either version 1, or (at your option) any
later version, or

* the Artistic License version 2.0.

This system is distributed in the hope that it will be useful, but WITHOUT 
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or 
FITNESS FOR A PARTICULAR PURPOSE.
