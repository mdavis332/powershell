$found = "false"
Get-CimInstance Win32_LogicalDisk | Select DriveType | % { if ([int]$_.DriveType -eq 2) { $found = "true" } }
if ($found -eq "true") {
	$job = start-job { (new-object -ComObject SAPI.SpVoice).Speak("Check the computer for a flash drive you may have left.") }
	(new-object -ComObject wscript.shell).Popup("Be sure you didn't leave your flash drive",10,"Did you forget something?",0x30)
}
