# script to fix SCCM W10 Upgrade TS
# more info at http://www.thesccm.com/fix-windows-10-in-place-upgrade-task-sequence-infinity-restart-loop/

# Error pref needed for try/catch blocks to work
$ErrorActionPreference = "stop"

$logPath = "C:\Logs"
$LogFile = $logPath + "\FixBootLoop.log"

$registryPath = 'HKLM:\SYSTEM\Setup'
$Key1Name = 'CmdLine'
$Key1Value = ''
$Key2Name = 'SetupType'

function Log ($message) {
    "$([DateTime]::Now)] $message" | Out-File $LogFile -Append -Force
}
log "Fix-BootLoop script started"
function Test-RegistryValue {

    [string]$Path,
    [string]$Value

    try {
        Get-ItemProperty -Path $Path -Name $Value -ErrorAction Stop | Out-Null
		return $true
    }

    catch {
        return $false
    }    
}

# check to see if CmdLine registry key exists
If (Test-RegistryValue -Path $registryPath -Value $Key1Name) {
    # key exists, so get its value
	
    Try 
	{
		$Key1Value = Get-ItemProperty -Path $registryPath | Select-Object -ExpandProperty "$Key1Name"
	}
	Catch
	{
		log "$registryPath\$Key1Name doesn't exist. Error: $($_.Exception.Message)"
	}
	
    # check if the value of CmdLine key is empty. Being empty is ok as long as SetupType is eq to 2
    If (!($Key1Value -eq "")) {
        # ok, the Key value is not empty. B/c of this SCCM issue, even if C:\Windows\SMSTSPostUpgrade is a valid path right now, it won't be by the end of the TS
		# That folder gets prematurely removed. So always set C:\Windows\Setup\Scripts as the correct CmdLine path.
			log "CmdLine key value is currently $Key1Value"
            $NewValue = 'C:\Windows\Setup\Scripts\setupcomplete.cmd'
            If (Test-Path $NewValue) {
                # NewValue path exists, so let's use it
                log "Setting CmdLine reg key to $NewValue"
				Try
				{
					Set-ItemProperty -Path $registryPath -Name $Key1Name -Value $NewValue
				}
				Catch
				{
					log "Could not Set-Itemproperty on Path $registryPath with Key $Key1Name and Value $NewValue. Error: $($_.Exception.Message)"
				}
				
            }
            Else {
                # NewValue path doesn't exist, so we've got to just clear out the registry entries
                # that are causing the issue
                # Set CmdLine reg_sz key to empty string
				log "CmdLine reg key needs to be updated but $NewValue doesn't exist, so we're just setting CmdLine to an empty string and SetupType to 0"
                Try
				{
					Set-ItemProperty -Path $registryPath -Name $Key1Name -Value ''
				}
				Catch
				{
					log "Could not Set-Itemproperty on Path $registryPath with Key $Key1Name and empty string value. Error: $($_.Exception.Message)"
				}
                # Set SetupType reg_dword key to 0
				Try
				{
					Set-ItemProperty -Path $registryPath -Name $Key2Name -Value 0
				}
				Catch
				{
					log "Could not Set-Itemproperty on Path $registryPath with Key $Key2Name and Value of 0. Error: $($_.Exception.Message)"
				}
            }
    }
    ElseIf ((Get-ItemProperty -Path $registryPath | Select-Object -ExpandProperty $Key2Name) -ne '0') {
        # this means that CmdLine reg_sz is empty (which is fine), but SetupType is !=0 (not fine)
		log "The CmdLine key was empty but the SetupType was not 0. Setting SetupType dword back to 0"
        Try
		{
			Set-ItemProperty -Path $registryPath -Name $Key2Name -Value 0
		}
		Catch
		{
			log "Could not Set-Itemproperty on Path $registryPath with Key $Key2Name and Value of 0. Error: $($_.Exception.Message)"
		}
    }
	Else {
		log "No incorrect registry keys detected. Exiting with no changes"
	}
}
Else {
	log "$registryPath\$Key1Name didn't exist. Exiting with no changes"
}
log "Finished"
