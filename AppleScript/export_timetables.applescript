-- set RootVolume to "Oculus HD"
tell application "System Events"
	set RootVolume to name of startup disk
end tell
set BiremeFolder to RootVolume & ":Users:apriven:Alameda - Contra Costa Transit:PubInfSys - Documents:"
set ActiumFolder to RootVolume & ":Users:apriven:Alameda - Contra Costa Transit:PubInfSys - Documents:Actium:"

set ExportOriginalNameFolder to ActiumFolder & "tableart:pdf:dates:"
set ExportOneDateFolder to ActiumFolder & "tableart:pdf:oneline-dates:"
set ExportLineFolder to ActiumFolder & "tableart:pdf:lines:"

set inddfiles to (choose file with prompt "Select the tabletables to export:" of type {"IDd2", "IDd3", "IDd4", "IDd6", "IDd8", "IDdB", "IDdC", "IDdX", "InDd", "IDdD", "IDdE", "IDdF", "IDdG", "IDdH", "IDdI"} default location (ActiumFolder & "tableart:indd:" as alias) with multiple selections allowed)

tell application id "com.adobe.InDesign"
	
	set myPreset to PDF export preset "[High Quality Print]"
	
	repeat with filealias in inddfiles
		set filename to my GetFileName(filealias)
		
		tell AppleScript to set text item delimiters to "-"
		set theDate to text item 2 of filename
		
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
			
			set NewFile to quoted form of POSIX path of (ExportOneDateFolder & thisLine & "-" & theDate & ".pdf")
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


