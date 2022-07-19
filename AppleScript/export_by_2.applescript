set savefolder to (choose folder with prompt "Select the folder wherein the PDFs shall be saved." default location alias "Bireme:Detours & Other Temporary Changes:2013 BART Strike:Alternatives From Stations") as string

tell application "Adobe InDesign 2022"
	
	set lastPageNum to document offset of last page of active document
	
	repeat with leftPageNum from 2 to lastPageNum by 2
		
		set myPageRange to (leftPageNum as string) & "-" & (leftPageNum + 1) as string
		
		tell PDF export preferences
			set page range to myPageRange
		end tell
		
		--tell active document
		--You'll have to fill in a valid file path for your system and
		--a valid PDF export preset name.
		--	export format PDF type to ("Bireme:Actium:tableart:pdf:" & myPageRange & ".pdf")
		-- using PDF export preset "SmallestFileSize" without showing options
		--end tell
		
		tell active document to export format PDF type to (savefolder & myPageRange & ".pdf")
		
	end repeat
	
end tell