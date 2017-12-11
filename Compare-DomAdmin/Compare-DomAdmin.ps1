# Acknowledgements to https://sid-500.com/2017/11/28/powershell-notify-me-when-someone-is-added-to-the-administrator-group/
$SmtpUser = 'email@host.local'
$SmtpPassword = 'PasswordGoesHere5!'
$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUser, $($SmtpPassword |
        ConvertTo-SecureString -AsPlainText -Force)

$MailParams = @{
    To         = 'support@host.local'
    From       = 'email@host.local'
    Subject    = "Domain Admin Membership Changes | $result was added to the Group"
    Body       = "Scheduled Task run at $(Get-Date) from $($MyInvocation.MyCommand.Definition) on computer $($env:computername)"
    SmtpServer = 'smtp.office365.com'
    Credential = $Credentials
}

$diff = (Get-ADGroupMember -Identity "Domain Admins").Name

If (!(Test-Path "$PSScriptRoot\Admins.txt")) {
    Add-Content -Path "$PSScriptRoot\Admins.txt" -Value $diff
}

$base = Get-Content "$PSScriptRoot\Admins.txt"

$result = (Compare-Object -ReferenceObject $base -DifferenceObject $diff |
        Where-Object {$_.SideIndicator -eq "=>"} |
        Select-Object -ExpandProperty InputObject) -join ", "

If ($result) {
    Send-MailMessage @MailParams -UseSsl -Priority High
    Add-Content -Path "$PSScriptRoot\Admins-New.txt" -Value $diff
}
