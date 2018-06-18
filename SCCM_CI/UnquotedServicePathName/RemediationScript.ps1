# Find any unquoted automatic startup services
$Filter = "StartMode = 'Auto' AND NOT PathName LIKE 'C:\\Windows%' AND NOT PathName LIKE '`"%'"
$NeedsQuotes = Get-CimInstance -ClassName Win32_Service -Filter $Filter

# Wrap double quotes around the PathName
foreach ($Item in $NeedsQuotes) {
    # if there is a path with arguments, it may show up here due to the space before the args, so split after a file ext
    # regex pattern below looks for everything up to a period followed 2-6 non-whitespace chars indicating a file ext
    # that full path is treated as the service name and everything else as the arguments 
    $MatchResult = $Item.PathName | Select-String -Pattern '(^.+\.\S{2,6})(.*)'
    $ServicePath = "`"$($MatchResult.Matches.Groups[1].Value)`""
    $ServiceArgs = $MatchResult.Matches.Groups[2].Value
    $NewPath = "${ServicePath}${ServiceArgs}"

    Invoke-CimMethod -InputObject $Item -MethodName change -Arguments @{PathName = $NewPath }
}
