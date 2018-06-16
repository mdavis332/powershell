# Find any unquoted automatic startup services
$Filter = "StartMode = 'Auto' AND NOT PathName LIKE 'C:\\Windows%' AND NOT PathName LIKE '`"%'"
$NeedsQuotes = Get-CimInstance -ClassName Win32_Service -Filter $Filter

# Wrap double quotes around the PathName
foreach ($Item in $NeedsQuotes) {

    Invoke-CimMethod -InputObject $Item -MethodName change -Arguments @{PathName = "`"$($Item.PathName)`""}
}
