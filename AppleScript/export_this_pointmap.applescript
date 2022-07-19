set MapFileFolder to "Macintosh HD:Users:apriven:Library:CloudStorage:OneDrive-SharedLibraries-Alameda-ContraCostaTransit:PubInfSys - Documents:Actium:signart2016:maps:export:"

tell application "Adobe InDesign 2022"
	set theDocument to active document
	set thePage to active page of active window
	
	set SignType to name of theDocument
	set DocumentName to name of theDocument
	set SignType to (text 1 thru ((offset of "=" in SignType) - 1) of SignType)
	set SignType to (text 1 thru ((offset of "_" in SignType) - 1) of SignType)
	set SignType to (text 1 thru ((offset of "-" in SignType) - 1) of SignType)
	set SignType to (text 1 thru ((offset of "." in SignType) - 1) of SignType)
	
	
	if (0 ­ (count of page items of thePage)) then
		
		set SignID to name of thePage
		set pagenum to document offset of thePage
		
		tell me
			set progress additional description to "Exporting #" & SignID
			set progress completed steps to pagenum
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
	
end tell
