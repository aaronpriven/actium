set MapFileFolder to "Macintosh HD:Users:apriven:Library:CloudStorage:OneDrive-SharedLibraries-Alameda-ContraCostaTransit:PubInfSys - Documents:Actium:signart2016:maps:export:"

set totalPages to 0
set pagesCount to 0

tell application "Adobe InDesign 2022"
	
	set theDocs to documents
	--set theDocs to {active document}
	
	repeat with theDocument in theDocs
		set totalPages to totalPages + (count of pages of theDocument)
	end repeat
	
	tell me
		set progress total steps to totalPages
		set progress completed steps to 0
	end tell
	
	repeat with theDocument in theDocs
		
		set SignType to name of theDocument
		set DocumentName to name of theDocument
		set SignType to (text 1 thru ((offset of "=" in SignType) - 1) of SignType)
		set SignType to (text 1 thru ((offset of "_" in SignType) - 1) of SignType)
		set SignType to (text 1 thru ((offset of "-" in SignType) - 1) of SignType)
		set SignType to (text 1 thru ((offset of "." in SignType) - 1) of SignType)
		
		
		set thePages to pages of theDocument
		--set thePages to {page named "113", page named "114", page named "2699"} of active document
		
		--set thePages to (pages 390 through 407) of active document
		--set thePages to {page named "50577", page named "767"} of active document
		--set thePages to {page named "50244"} of active document
		
		tell me
			--set progress total steps to totalPages -- count of thePages
			--set progress completed steps to 0
			set progress description to "Exporting point schedule maps from " & DocumentName & "É"
			set progress additional description to "Preparing to export."
		end tell
		
		repeat with thePage in thePages
			set pagesCount to pagesCount + 1
			if (0 ­ (count of page items of thePage)) then
				
				set SignID to name of thePage
				set pagenum to document offset of thePage
				
				tell me
					set progress additional description to "Exporting #" & SignID
					set progress completed steps to pagesCount
				end tell
				
				tell PDF export preferences
					set page range to SignID
					set view PDF to false
				end tell
				
				set pep to PDF export preset "[High Quality Print]"
				
				tell theDocument
					set filestring to (MapFileFolder & SignType & ":" & SignID & ".pdf")
					export format PDF type to filestring using pep
				end tell
				
			end if
		end repeat
		
	end repeat
	
end tell

-- Reset the progress information
set progress total steps to 0
set progress completed steps to 0
set progress description to ""
set progress additional description to ""