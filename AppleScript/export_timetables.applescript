
-- set savefolder to (choose folder with prompt "Select the folder wherein the PDFs shall be saved." default location alias "Bireme:Actium:tableart:pdf") as string

set ExportOriginalNameFolder to "Bireme:Actium:tableart:pdf:dates:"
set ExportLineFolder to "Bireme:Actium:tableart:pdf:lines:"

set inddfiles to (choose file with prompt "Select the tabletables to export:" of type {"IDd2", "IDd3", "IDd4", "IDd6", "IDd8", "IDdB", "IDdC", "IDdX", "InDd", "IDdD", "IDdE", "IDdF", "IDdG", "IDdH", "IDdI"} default location ("Bireme:Actium:tableart:indd:" as alias) with multiple selections allowed)

tell application id "com.adobe.InDesign"
	
	set myPreset to PDF export preset "[High Quality Print]"
	
	repeat with filealias in inddfiles
		set filename to my GetFileName(filealias)
		
		try
			set myDocument to open filealias without showing window
			set myOriginalNameFile to ExportOriginalNameFolder & filename & ".pdf"
			tell PDF export preferences
				set view PDF to false
				set page range to all pages
			end tell
			tell myDocument
				export format PDF type to myOriginalNameFile using myPreset without showing options
			end tell
			
			set myPage to page 1 of myDocument
			set myLineText to contents of ((item 1 of (all page items of myPage) whose label is "LineFrame"))
			set myLineList to words of myLineText
			
			close myDocument saving no
			
		on error s number i partial result p from f to t
			tell myDocument to make window
			error s number i partial result p from f to t
		end try
		
		set OldFile to quoted form of POSIX path of myOriginalNameFile
		
		repeat with thisLine in myLineList
			set NewFile to quoted form of POSIX path of (ExportLineFolder & thisLine & "_timetable.pdf")
			set cmd to "/bin/cp -f " & OldFile & " " & NewFile
			
			do shell script cmd
			
		end repeat
		
	end repeat
end tell

on GetFileName(filealias)
	set filespec to filealias as string
	tell AppleScript to set text item delimiters to ":"
	set filename_ext to last text item of filespec
	tell AppleScript to set text item delimiters to "."
	set L to text items of filename_ext
	set L to reverse of L
	set L to rest of L
	set L to reverse of L
	set filename to L as string
end GetFileName





(*

=head1 NAME

<name> - <brief description>

=head1 VERSION

This documentation refers to version 0.003

=head1 DESCRIPTION

A full description of the module and its features.

=head1 DIAGNOSTICS

A list of every error and warning message that the application can
generate (even the ones that will "never happen"), with a full
explanation of each problem, one or more likely causes, and any
suggested remedies. If the application generates exit status codes,
then list the exit status associated with each error.

=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the
application, including the names and locations of any configuration
files, and the meaning of any environment variables or properties
that can be se. These descriptions must also include details of any
configuration language used.

=head1 DEPENDENCIES

List its dependencies.

=head1 AUTHOR

Aaron Priven <apriven@actransit.org>

=head1 COPYRIGHT & LICENSE

Copyright 2017

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

*)
