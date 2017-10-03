on SaveAsEPS(indd)
	
	set Bleed to "24pt"
	set OutlineText to true
	
	set ScoreLine to 12
	set CutLine to 24
	
	set thePrintDirName to "SaveAsEPS"
	
	tell application id "com.adobe.InDesign"
		set inddFolder to file path of indd
		set inddName to name of indd
	end tell
	
	-- the following sets basename to be the InDesign filename without the .indd extension
	
	set AppleScript's text item delimiters to "."
	set TextItms to text items of inddName
	set LastItem to item -1 of TextItms
	if LastItem = "indd" then
		set TextItms to reverse of rest of reverse of TextItms
	end if
	set basename to (TextItms as string)
	set AppleScript's text item delimiters to ""
	
	
	tell application "System Events"
		
		if (exists folder thePrintDirName of desktop folder) is false then
			tell desktop folder to make folder with properties {name:thePrintDirName}
		end if
		set PrintFolder to folder thePrintDirName of desktop folder
		
		if (exists folder basename of PrintFolder) is false then
			tell PrintFolder to make folder with properties {name:basename}
		end if
		
		set ExportPath to (path of PrintFolder) & basename & ":"
		
	end tell
	
	tell application id "com.adobe.InDesign"
		
		set theFileName to (ExportPath & basename) as string
		set thePDFName to (theFileName & ".pdf") as string
		
		set myBleedOffset to Bleed
		
		tell PDF export preferences
			set page range to all pages
			set bleed bottom to myBleedOffset
			set bleed top to myBleedOffset
			set bleed inside to myBleedOffset
			set bleed outside to myBleedOffset
		end tell
		
		tell indd
			with timeout of 600 seconds
				export format PDF type to thePDFName without showing options
			end timeout
		end tell
		
		set pageCount to count of pages of indd
		
		
		repeat with thePageNum from 1 to pageCount
			
			set myPage to page thePageNum of indd
			
			set myPageName to ""
			repeat with PageNameLabel in {"PageName", "fStopID", "bStopID", "StopID", "Decalcode", "Line"}
				set PageNameLabelText to (PageNameLabel as string)
				set myPageNameItems to (every page item of myPage whose label is PageNameLabelText)
				repeat with myPageNameItemRef in myPageNameItems
					set myPageNameItemText to text of contents of myPageNameItemRef
					if (myPageName is equal to "" and myPageNameItemText is not equal to "") then
						
						log PageNameLabel
						
						if (PageNameLabel contains "fStopID") then
							log "f"
							set myPageName to myPageNameItemText & "Fr"
						else if (PageNameLabel contains "bStopID") then
							log "b"
							set myPageName to myPageNameItemText & "Bk"
						else
							set myPageName to myPageNameItemText
						end if
						
						exit repeat
					end if
				end repeat
				
				if myPageName � "" then
					exit repeat
				end if
			end repeat
			if (myPageName is equal to "") then set myPageName to thePageNum
			
			
			tell application "Adobe Illustrator"
				
				set user interaction level to never interact
				set page of PDF file options of settings to thePageNum
				open (thePDFName as alias) without dialogs
				
				
				
				set Ra to artboard rectangle of artboard 1 of current document -- this is the new artboard with lots of bleed
				set Rscore to {(item 1 of Ra) + ScoreLine, (item 2 of Ra) - ScoreLine, (item 3 of Ra) - ScoreLine, (item 4 of Ra) + ScoreLine}
				-- the score line 
				set Rorig to {(item 1 of Ra) + CutLine, (item 2 of Ra) - CutLine, (item 3 of Ra) - CutLine, (item 4 of Ra) + CutLine}
				-- the real edge of the final
				
				set ArtboardRect to make rectangle at beginning of current document with properties {bounds:Rorig, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				set ScoreRect to make rectangle at beginning of current document with properties {bounds:Rscore, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				
				set theEPSName to (theFileName & "_" & myPageName & "_outl.eps") as string
				
				if OutlineText then
					set theEPSName to (theFileName & "_" & myPageName & "_outl.eps") as string
					convert to paths text frames of current document
				else
					set theEPSName to (theFileName & "_" & myPageName & ".eps") as string
				end if
				
				save current document in (theEPSName) as eps with options {CMYK PostScript:true, embed all fonts:true, preview:color TIFF, compatibility:Illustrator 8}
				close current document saving no
				
			end tell
			
		end repeat
		
		
		
	end tell
	
end SaveAsEPS

on run {}
	
	tell application id "com.adobe.InDesign"
		
		set theInDD to active document
		tell me to SaveAsEPS(theInDD)
		
	end tell
	
	beep
	display alert "Done exporting." giving up after 10
	
end run

on open Lst
	
	tell application id "com.adobe.InDesign"
		repeat with zItm in Lst
			set Itm to zItm as alias
			set theInDD to open Itm
			
			tell me to SaveAsEPS(theInDD)
			
			close theInDD saving no
			
		end repeat
	end tell
	
	beep
	display alert "Done exporting." giving up after 10
	
end open



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
