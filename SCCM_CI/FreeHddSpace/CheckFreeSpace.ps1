# Get disk space info for C: drive
$OS = Get-CimInstance Win32_OperatingSystem
$CDrive = Get-CimInstance Win32_LogicalDisk -Filter "deviceid='$($OS.SystemDrive)'"

# Calc % free and return not compliant if less than 8% free
If (($CDrive.FreeSpace/$CDrive.Size) -le '0.08') {
    return $False
}  else { 
    return $True 
}
