set CoverPageFileFolder to "Bireme:Actium:tableart:CoverPages:"

tell application "Adobe InDesign CC 2017"
	
	set lastPageNum to document offset of last page of active document
	
	repeat with PageNum from 1 to lastPageNum
		
		set LineGroupFrame to (item 1 of (all page items of (page PageNum of active document)) whose label is "linegroup")
		set linegroup to contents of contents of LineGroupFrame
		-- For the life of me I don't understand why the duplicate contents is necessary, but it is
		
		tell AppleScript to set text item delimiters to "_"
		set linegroup to ((words of linegroup) as string)
		
		tell PDF export preferences
			set page range to PageNum as string
			set view PDF to false
		end tell
		
		set pep to PDF export preset "[High Quality Print]"
		
		tell active document
			set filestring to (CoverPageFileFolder & linegroup & ".pdf")
			export format PDF type to filestring using pep
		end tell
	end repeat
	
end tell


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
