# Acknowledgements to https://sid-500.com/2017/11/28/powershell-notify-me-when-someone-is-added-to-the-administrator-group/
$SmtpUser = 'email@host.local'
$SmtpPassword = 'PasswordGoesHere5!'
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPassword |
        ConvertTo-SecureString -AsPlainText -Force)
$Group = 'Domain Admins'

$MailParams = @{
    To         = 'support@host.local'
    From       = 'email@host.local'
    Body       = "Scheduled Task run at $(Get-Date) from $($MyInvocation.MyCommand.Definition) on computer $($env:computername)"
    SmtpServer = 'smtp.office365.com'
    Credential = $Credentials
}

$diff = (Get-ADGroupMember -Identity $Group).Name

If (!(Test-Path "$PSScriptRoot\$Group.txt")) {
    Add-Content -Path "$PSScriptRoot\$Group.txt" -Value $diff
}

# If file-new exists from previous run, remove old file.txt and rename file-new to file. 
If (Test-Path "$PSScriptRoot\$Group-New.txt") {
    Rename-Item -Path "$PSScriptRoot\$Group.txt" -NewName "$PSScriptRoot\$Group-Old-$((Get-Date).ToString("yyyyMMdd-hhmm")).txt" -Force
	Rename-Item -Path "$PSScriptRoot\$Group-New.txt" -NewName "$PSScriptRoot\$Group.txt"
}

$base = Get-Content "$PSScriptRoot\$Group.txt"


$result = (Compare-Object -ReferenceObject $base -DifferenceObject $diff |
        Where-Object {$_.SideIndicator -eq "=>"} |
        Select-Object -ExpandProperty InputObject) -join ", "
		
If ($result) {
    Send-MailMessage @MailParams -UseSsl -Priority High -Subject "$Group Membership Changes | $result was added to the Group"
    Add-Content -Path "$PSScriptRoot\$Group-New.txt" -Value $diff
}
