$OS = Get-CimInstance Win32_OperatingSystem
$Root = $OS.SystemDrive
$WinDir = $OS.WindowsDirectory
# Variable array for folders to clean, others can be added as needed
$TempFolders = @("$WinDir\Temp\*", 
				 "$WinDir\SoftwareDistribution\Download\*", 
				 "$WinDir\Prefetch\*", 
				 "$Root\Users\*\AppData\Local\Temp\*", 
				 "$Root\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*", 
				 "$WinDir\CSC\*", 
				 "$Root\Users\*\AppData\Local\Google\Chrome\User Data\Default\Cache\*", 
				 "$Root\Users\*\AppData\Local\Google\Chrome\User Data\Default\Media Cache\*", 
				 "$Root\`$Recycle.Bin\*", 
				 "$Root\temp\*", 
				 "$Root\PanoptoRecorder\*")

ForEach ($Folder in $TempFolders)
	{
		Try {
			# do the actual deleting
			Remove-Item -Path $Folder -Recurse -Force -ErrorAction SilentlyContinue
		}
		Catch { }
	}
