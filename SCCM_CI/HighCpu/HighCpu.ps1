# Script to alert on high CPU usage

# Set threshold in percentage of total processor usage
# Anything above this number will generate an alert
[decimal]$Threshold = 50

$MessageTo = 'ticketing@host.com' # Users to be notified  
$MessageFrom = 'sccm@host.com' # From Email
$MessageSubject = "CPU Utilization Alert - $env:COMPUTERNAME" # Subject: of the results email
$SmtpUsername = 'sccm@host.com' # if you need to auth to smtp server, otherwise leave blank
$SmtpPassword = 'PasswordGoesHere!@' # if you need to auth to smtp server, otherwise leave blank
$SmtpServer = 'smtp.office365.com' #SMTP Server information 
If ($SmtpUsername -ne '') {
    $Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $SmtpUsername, $($SmtpPassword |
            ConvertTo-SecureString -AsPlainText -Force)
}
[int32]$SmtpPort = '25' # Enter your SMTP port number. Example: '25' or '465' (Usually for SSL) or '587' or '1025'
[boolean]$SmtpServerEnableSSL = $True # Do you want to enable SSL communication for your SMTP Server

# Let's work magic
If (((Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval 1 -MaxSamples 5).CounterSamples.CookedValue | Measure-Object -Average).Average -gt [decimal]$Threshold) {
    Write-Host "Threshold limit exceeded. Getting List of top processes and composing email."
    # CPU was too high, let's now get a list of top processes and store them in an object
    $PsObject = New-Object PSObject
    $PsObject = (Get-Counter "\Process(*)\% Processor Time").CounterSamples.Where( {$_.InstanceName -ne '_total'}) | 
        Select-Object InstanceName, @{Name = "CPU %"; Expression = {[Decimal]::Round(($_.CookedValue / ((Get-WMIObject Win32_ComputerSystem).NumberOfLogicalProcessors)), 2)}} | 
        Sort-Object 'CPU %' -Desc | Select-Object -First 10 | 
        Select-Object InstanceName, 'CPU %', @{Name = 'ComputerName'; Expression = {$env:COMPUTERNAME}}

    $TableFragment = $PsObject | ConvertTo-Html -Fragment

    # assemble the HTML for our body of the email report. 
  
    $MessageHtml = @" 
<font color="Red" face="Microsoft Tai le"> 
<body BGCOLOR="White"> 
<h2>High CPU Utilization Alert</h2> </font> 
 
<font face="Microsoft Tai le"> 
 
You are receiving this alert because the computer listed below has CPU utlization higher than the alerting threshold of ${Threshold}%. Your immediate action may be required to clear this alert. 
</font> 
<br> <br> 
<!--mce:0--> 
 
<body BGCOLOR=""white""> 
 
$TableFragment 
<br> <br> <font face="Microsoft Tai le"> <h6><i> ** This Alert was triggered by a monitoring script at $(Get-Date) from $($MyInvocation.MyCommand.Definition)</i></h6> </font> 
</body> 
 
"@

    $MailParams = @{
        From       = $MessageFrom
        To         = $MessageTo
        Subject    = $MessageSubject
        Body       = $MessageHtml
        SmtpServer = $SmtpServer
        Credential = $Credentials
        Priority   = 'High'
    }
    Send-Mailmessage @MailParams -BodyAsHTML -UseSSL
    Write-Host "Non-Compliant"

}

Else {
    Write-Host "Compliant"
}
