set CoverPageFileFolder to "Users:Shared:Dropbox (AC_PubInfSys):Actium:tableart:CoverPages:"

tell application "System Events"
	set HomeFolder to (path of home folder) as string
end tell
set ActiumFolder to HomeFolder & "Alameda - Contra Costa Transit:PubInfSys - Documents:Actium:"
set CoverPageFileFolder to ActiumFolder & "tableart:CoverPages:"


tell application "Adobe InDesign 2022"
	
	set lastPageNum to document offset of last page of active document
	
	tell me
		set progress total steps to lastPageNum
		set progress completed steps to 0
		set progress description to "Exporting cover pages..."
		set progress additional description to "Preparing to export."
	end tell
	
	repeat with PageNum from 1 to lastPageNum
		
		set LineGroupFrame to (item 1 of (all page items of (page PageNum of active document)) whose label is "linegroup")
		set linegroup to contents of contents of LineGroupFrame
		-- For the life of me I don't understand why the duplicate contents is necessary, but it is
		
		tell AppleScript to set text item delimiters to "_"
		set linegroup to ((words of linegroup) as string)
		
		tell me
			set progress additional description to "Exporting " & linegroup
			set progress completed steps to PageNum
		end tell
		
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

-- Reset the progress information
set progress total steps to 0
set progress completed steps to 0
set progress description to ""
set progress additional description to ""