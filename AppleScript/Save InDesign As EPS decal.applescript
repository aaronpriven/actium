on SaveAsEPS(indd)
	
	set Bleed to "24pt"
	set OutlineText to true
	
	set ScoreLine to 12
	set CutLine to 24
	
	set thePrintDirName to "SaveAsEPS"
	
	tell application id "com.adobe.InDesign"
		set inddFolder to file path of indd
		set inddName to name of indd
		--set PDFPreset to PDF export preset named "[High Quality Print]"
		
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
				--export format PDF type to thePDFName using PDFPreset without showing options
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
				set myIncludeFileName to true
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
						else if (PageNameLabel contains "Decalcode" or PageNameLabel contains "Line") then
							set myPageName to myPageNameItemText
							set myIncludeFileName to false
							
						else
							set myPageName to myPageNameItemText
						end if
						
						exit repeat
					end if
				end repeat
				
				if myPageName ­ "" then
					exit repeat
				end if
			end repeat
			if (myPageName is equal to "") then set myPageName to thePageNum
			
			
			tell application "Adobe Illustrator"
				
				set user interaction level to never interact
				set page of PDF file options of settings to thePageNum
				set thePDFPosixPath to POSIX path of (thePDFName as alias)
				open file thePDFPosixPath without dialogs
				--open (thePDFName as alias) without dialogs
				
				
				set Ra to artboard rectangle of artboard 1 of current document -- this is the new artboard with lots of bleed
				set Rscore to {(item 1 of Ra) + ScoreLine, (item 2 of Ra) - ScoreLine, (item 3 of Ra) - ScoreLine, (item 4 of Ra) + ScoreLine}
				-- the score line 
				set Rorig to {(item 1 of Ra) + CutLine, (item 2 of Ra) - CutLine, (item 3 of Ra) - CutLine, (item 4 of Ra) + CutLine}
				-- the real edge of the final
				
				set ArtboardRect to make rectangle at beginning of current document with properties {bounds:Rorig, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				set ScoreRect to make rectangle at beginning of current document with properties {bounds:Rscore, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				if (myIncludeFileName) then
					set theEPSName to (theFileName & "_" & myPageName & "_outl.eps") as string
				else
					set theEPSName to (ExportPath & myPageName & "_outl.eps") as string
				end if
				
				convert to paths text frames of current document
				
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
