-- version 0.010

-- set savefolder to (choose folder with prompt "Select the folder wherein the PDFs shall be saved." default location alias "Bireme:Actium:tableart:pdf") as string

set ExportOriginalNameFolder to "Bireme:Actium:tableart:pdf:dates:"
set ExportLineFolder to "Bireme:Actium:tableart:pdf:lines:"

set inddfiles to (choose file with prompt "Select the tabletables to export:" of type {"IDd8", "IDd9"} default location ("Bireme:Actium:tableart:indd:" as alias) with multiple selections allowed)

tell application id "com.adobe.InDesign"
	
	set myPreset to PDF export preset "[Smallest File Size]"
	
	repeat with filealias in inddfiles
		set filename to my GetFileName(filealias)
		
		try
			set myDocument to open filealias without showing window
			set myOriginalNameFile to ExportOriginalNameFolder & filename & ".pdf"
			tell PDF export preferences
				set view PDF to false
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

