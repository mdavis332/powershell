[CmdletBinding()]
param (
[String[]]$TargetComputers
)
# dot source an ancillary function
    . "$PSScriptRoot\Invoke-Ping.ps1"

# Variable array for folders to clean, others can be added as needed
$tempfolders = @("C:\Windows\Temp\*", 
				 "C:\Windows\SoftwareDistribution\Download\*", 
				 "C:\Windows\Prefetch\*", 
				 "C:\Users\*\AppData\Local\Temp\*", 
				 "C:\Users\*\AppData\Local\Microsoft\Windows\Temporary Internet Files\*", 
				 "C:\Windows\CSC\*", 
				 "C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Cache\*", 
				 "C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Media Cache\*", 
				 "C:\`$Recycle.Bin\*", 
				 "C:\temp\*", 
				 "C:\PanoptoRecorder\*")

if ($TargetComputers -eq $null -OR $TargetComputers.Count -le 0) {
	Write-Output "No target hostnames were provided"
	Exit
}

# This may or may not be needed? If you don't need it, remove this, and also remove the "-credential $credentials" from the Invoke-Command 
#$credentials = Get-Credential -Message "Gimme domain admin permissions plx" -UserName domain\administrator
# A mix of foreach and invoke-command, since remove-item doesn't have a -computername switch.
# The script also pings the computer first, and skips it if it's not answering. You won't wait forever for timeouts this way.
$Responding = $TargetComputers | Invoke-Ping -Quiet -Timeout 5

if ($Responding -ne $null) {

$Session = New-PSSession $Responding
   
$Script = {
	# Measure free C: drive space prior to delete item operation
	try {
		$os = Get-WMIObject Win32_OperatingSystem
		$Drive = Get-WMIObject Win32_LogicalDisk -filter "deviceid='$($os.systemdrive)'" | Select DeviceID, 
																								  @{Name = "FreeMB"; Expression = {[math]::Round( $_.Freespace / 1MB, 2 )}}, 
																								  @{Name = "PercentFree"; Expression = {[math]::Round( $_.FreeSpace / $_.Size, 3 ) }} 
	}
	catch { }
	$realFreeSpaceBefore = $Drive.FreeMB
	$realPercentFreeBefore = $Drive.PercentFree

    foreach ($folder in $using:tempfolders)
	{
		try {
			# sum up how much space we'll free with the delete operation and convert to megabytes (MB)
			$estimatedSize += (Get-ChildItem -Path $folder -Recurse -ErrorAction SilentlyContinue | Measure-Object -property length -sum).sum / 1MB
			# do the actual deleting while measuring so we don't recurse all the directories twice
			Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
		}
		catch { }
	}
	# Round to 2 decimal places and return
	$estimatedSize = [math]::Round($estimatedSize,2)
	
	
	#Do the actual deleting
	<# foreach ($folder in $using:tempfolders)
	{
		try {
			Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
		}
		catch { }
	} #>
	
	# Measure free C: drive space after delete item operation
	try {
		# should be the same $os var from earlier: 
		#$os = Get-WMIObject Win32_OperatingSystem
		$Drive = Get-WMIObject Win32_LogicalDisk -filter "deviceid='$($os.systemdrive)'" | Select DeviceID, 
																								  @{Name = "FreeMB"; Expression = {[math]::Round( $_.Freespace / 1MB, 2 )}},
																								  @{Name = "PercentFree"; Expression = {[math]::Round( $_.FreeSpace / $_.Size, 3 ) }}
	}
	catch { }
	$realFreeSpaceAfter = $Drive.FreeMB
	$realPercentFreeAfter = $Drive.PercentFree
	
	$realFreeSpaceReclaimed = [math]::Round($realFreeSpaceAfter - $realFreeSpaceBefore, 2)
	$realPercentFreeReclaimed = "{0:P1}" -f ($realPercentFreeAfter - $realPercentFreeBefore)
	#define Object property parameters and splat them
	$objParms = @{Host=$env:computername; 
			   'Est. Freed Space (MB)'=$estimatedSize; 
			   'Act. Freed Space (MB)'=$realFreeSpaceReclaimed; 
			   'PercentFreed'=$realPercentFreeReclaimed; 
			   'NewPercentFree'="{0:P1}" -f $realPercentFreeAfter
	}
	# Return the output using a hashtable
	$Output = New-Object PSObject
	$Output | Add-Member NoteProperty SystemName $env:computername
	$Output | Add-Member NoteProperty SpaceCleanupEstimateMB $estimatedSize
	$Output | Add-Member NoteProperty SpaceCleanupActualMB $realFreeSpaceReclaimed 
	$Output | Add-Member NoteProperty RealPercentFreed $realPercentFreeReclaimed
	$Output | Add-Member NoteProperty NewPercentFree $realPercentFreeAfter
	$Output | Add-Member NoteProperty Success $true
	return $Output
	#return New-Object -TypeName PSCustomObject -Property @objParms
	
}

try { 
	$Results = Invoke-Command -Session $Session -ScriptBlock $Script
} catch { }

# Save all the hostnames from the $Results object into an array of strings of successful hosts
$Successes = @($Results | Select -Expand SystemName)

# Compare the original array of TargetComputers to the array of successful computers and see if we had any that weren't in both (those are failures)
$FailureObjects = @(Compare-Object $TargetComputers $Successes)
if ($FailureObjects -ne $null -OR $FailureObjects.count -ge 1) {
	# there were failed computer objects if we got here. List them out for a report
	$Failures = @()
	$FailureObjects | ForEach { $Failures += $_.InputObject }
	return $Failures
}

Remove-PSSession -Session $Session
}
else {Write-Output "No PCs alive"}
