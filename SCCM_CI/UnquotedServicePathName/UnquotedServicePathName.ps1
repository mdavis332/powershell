# Find any unquoted automatic startup services
$Filter = "StartMode = 'Auto' AND NOT PathName LIKE 'C:\\Windows%' AND NOT PathName LIKE '`"%'"
$NeedsQuotes = Get-CimInstance -ClassName Win32_Service -Filter $Filter

# If there's nothing returned, it means we're compliant
if ($NeedsQuotes -eq $null) {
    Write-Output $true
} else {
    # if we make it here, there were one or more PathNames that were unquoted, so report non-compliant to run remediation
    Write-Output $false
}
