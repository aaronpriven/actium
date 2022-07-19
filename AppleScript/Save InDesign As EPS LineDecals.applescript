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
	
	
	--tell application "System Events"
	--	
	--	if (exists folder thePrintDirName of desktop folder) is false then
	--		tell desktop folder to make folder with properties {name:thePrintDirName}
	--	end if
	--	set PrintFolder to folder thePrintDirName of desktop folder
	
	--	if (exists folder basename of PrintFolder) is false then
	--		tell PrintFolder to make folder with properties {name:basename}
	--	end if
	
	--	set ExportPath to (path of PrintFolder) & basename & ":"
	
	--end tell
	
	set ExportBasePath to ((path to home folder) as string) & "Alameda - Contra Costa Transit:PubInfSys - Documents:Actium:flagart:Decals:"
	set ExportPath to ExportBasePath & "export:"
	set ExportBleedPath to ExportBasePath & "export_bleed:"
	
	tell application id "com.adobe.InDesign"
		
		set thePDFName to (ExportPath & basename & "_all.pdf") as string
		set thePDFBleedName to (ExportBleedPath & basename & "_allbleed.pdf") as string
		
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
				export format PDF type to thePDFBleedName without showing options
			end timeout
		end tell
		
		tell PDF export preferences
			set page range to all pages
			set bleed bottom to 0
			set bleed top to 0
			set bleed inside to 0
			set bleed outside to 0
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
			
			set myPageName to name of myPage
			set myPageNumber to (characters -4 thru -1 of myPageName) as string
			if (myPageNumber = "-001") then
				set myPageName to marker of applied section of myPage
			end if
			
			tell application "Adobe Illustrator"
				
				set user interaction level to never interact
				set page of PDF file options of settings to thePageNum
				
				-- outline version for decal printing
				set thePDFBleedPosixPath to POSIX path of (thePDFBleedName as alias)
				open file thePDFBleedPosixPath without dialogs
				
				set Ra to artboard rectangle of artboard 1 of current document -- this is the new artboard with lots of bleed
				set Rscore to {(item 1 of Ra) + ScoreLine, (item 2 of Ra) - ScoreLine, (item 3 of Ra) - ScoreLine, (item 4 of Ra) + ScoreLine}
				-- the score line 
				set Rorig to {(item 1 of Ra) + CutLine, (item 2 of Ra) - CutLine, (item 3 of Ra) - CutLine, (item 4 of Ra) + CutLine}
				-- the real edge of the final
				
				set ArtboardRect to make rectangle at beginning of current document with properties {bounds:Rorig, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				set ScoreRect to make rectangle at beginning of current document with properties {bounds:Rscore, filled:false, stroke width:1, stroke color:{class:CMYK color info, cyan:0.0, magenta:0.0, yellow:0.0, black:100.0}}
				
				set theEPSName to (ExportBleedPath & myPageName & "_outl.eps") as string
				
				convert to paths text frames of current document
				save current document in (theEPSName) as eps with options {CMYK PostScript:true, embed all fonts:true, preview:color TIFF, compatibility:Illustrator 12}
				close current document saving no
				
				-- non-outline version for incorporating in flags
				
				set thePDFPosixPath to POSIX path of (thePDFName as alias)
				open file thePDFPosixPath without dialogs
				
				set PDFSaveName to (ExportPath & myPageName & ".pdf") as string
				save current document in (PDFSaveName) as pdf with options {PDF preset:"[High Quality Print]"}
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
