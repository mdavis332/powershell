###########################
## Edit these Parameters ##
###########################

$MailTo = @(
    'FirstLast@domain.local',
    'SecondPerson@domain.local',
    'SomeoneElse@domain.local'
)

$SmtpServer = 'smtp.office365.com'
$SmtpUser = 'smtp-user@domain.local'
$MailFrom = 'smtp-user@domain.local'
$SmtpPassword = 'ReallyLongPasswordHere!'

$TeamsWebhookUri = 'https://outlook.office.com/webhook/<longGuid>/IncomingWebhook/<shortGuid>/<mediumGuid>'

############################
## Do not edit below here ##
############################
Import-Module "$PSScriptRoot\PSMicrosoftTeams\PSMicrosoftTeams.psd1"

$tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
[datetime]$OSDStartTime = $tsenv.Value("SMSTS_StartTSTime")
[datetime]$OSDFinishTime = $tsenv.Value("SMSTS_FinishTSTime")
$OSDFundingAgent = $tsenv.Value("OSDFundingAgent")
$OSDAppSet = $tsenv.Value("OSDAppTreeAppsChoice")
$OSDTsName = $tsenv.Value("_SMSTSPackageName")
#$LogPath = $tsenv.Value("_SMSTSLogPath")

$WmiCompSystem = Get-CimInstance Win32_ComputerSystem

$MsgSubject = "OSD - $($WmiCompSystem.Name) - Build Success"


$StartTimeString = "$($OSDStartTime.ToShortDateString()) $($OSDStartTime.ToShortTimeString())"
$OSDFinishTimeString = "$($OSDFinishTime.ToShortDateString()) $($OSDFinishTime.ToShortTimeString())"

# Get OSD imaging time duration
If ($OSDStartTime -ne '') {
    $OSDDuration = New-TimeSpan -Start $OSDStartTime -End $OSDFinishTime
}

$MsgHeader = "Model: $($WmiCompSystem.Manufacturer) $($WmiCompSystem.Model)`r`n"
$MsgHeader += "Funding Agent: $OSDFundingAgent`r`n"
$MsgHeader += "App Set: $OSDAppSet`r`n"
$MsgHeader += "Task Sequence: $OSDTsName`r`n"

$MsgDuration = @"

The process took $($OSDDuration.Hours) hours and $($OSDDuration.Minutes) minutes to complete. Started at $StartTimeString and ended at $OSDFinishTimeString
"@

$MsgApps = @"
`r`n
Installed Applications:
"@

# Create a regex filter to exclude certain Software
$regexEliminate = "^(Visual C\+\+|Microsoft \.Net|Microsoft App Update|NVIDIA|Definition Update|Security Update|Software Update|Google Update|Hotfix for|Update for|Microsoft National|MicrosoftOffice DCF|Microsoft Office OSM|Microsoft Office Proofing|Microsoft Office Shared|Windows Management Framework|Microsoft Internationalized|WIMGAPI|RDC|Microsoft Visual C\+\+)"

$InstalledSoftware = @()

# Get 32-bit installed software
Get-CimInstance -ClassName Win32Reg_AddRemovePrograms |
    Where-Object {$_.DisplayName -NotMatch $regexEliminate -AND $_.DisplayName -ne $null} |
    ForEach-Object {
    $obj = New-Object PSObject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $_.DisplayName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Version -Value $_.Version
    $InstalledSoftware += $obj
}

# Get 64-bit installed software
Get-CimInstance -ClassName Win32Reg_AddRemovePrograms64 |
    Where-Object {$_.DisplayName -NotMatch $regexEliminate -AND $_.DisplayName -ne $null} |
    ForEach-Object {
    $obj = New-Object PSObject
    Add-Member -InputObject $obj -MemberType NoteProperty -Name DisplayName -Value $_.DisplayName
    Add-Member -InputObject $obj -MemberType NoteProperty -Name Version -Value $_.Version
    $InstalledSoftware += $obj
}

# There will be duplicate entries from pulling those separate CIM classes. Eliminate the duplicates & resave var
$InstalledSoftware = $InstalledSoftware | Sort-Object -Property DisplayName -Unique

$MsgDetails = New-Object System.Collections.Generic.List[System.Object]
$MsgDetails.Add(@{ name = 'Model'; value = "$($WmiCompSystem.Manufacturer) $($WmiCompSystem.Model)" })
$MsgDetails.Add(@{ name = 'Funding Agent'; value = "$OSDFundingAgent" })
$MsgDetails.Add(@{ name = 'App Set'; value = "$OSDAppSet"})
$MsgDetails.Add(@{ name = 'Started'; value = "$StartTimeString"})
$MsgDetails.Add(@{ name = 'Finished'; value = "$OSDFinishTimeString"})
$MsgDetails.Add(@{ name = 'Duration'; value = "$($OSDDuration.Hours) hours and $($OSDDuration.Minutes) minutes"})
$MsgDetails.Add(@{ name = 'Installed Apps'; value = ''})
# Iterate all apps and add the name and version to the mailbody
ForEach ($App in $InstalledSoftware) {
    $MsgApps += "

    $($App.DisplayName) $($App.Version)"

    $MsgDetails.Add( @{ name = $($App.DisplayName); value = $($App.Version)} )
}

$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPassword | ConvertTo-SecureString -AsPlainText -Force) 

# Splat Send-MailMessage params
$MailParams = @{
    To         = $MailTo
    From       = $MailFrom
    Subject    = $MsgSubject
    Body       = $MsgHeader + $MsgDuration + $MsgApps
    SmtpServer = $SmtpServer
    Credential = $Credentials
}
Send-MailMessage @MailParams -UseSsl

# Splat Send-MailMessage params
$MsgParams = @{
    messageType      = 'Information'
    messageTitle     = $MsgSubject
    Uri              = $TeamsWebhookUri
    messageSummary   = $MsgHeader
    activityTitle    = 'Task Sequence'
    activitySubtitle = $OSDTsName
    details          = $MsgDetails
    detailTitle      = 'Deployment Details'
}

Send-TeamChannelMessage @MsgParams

Remove-Module PSMicrosoftTeams
